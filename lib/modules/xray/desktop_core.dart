import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/l10n.dart';
import '../../data/storage/paths.dart';
import '../logs/log_service.dart';
import '../system/privileges.dart';
import '../system/sys.dart';
import 'config_builder.dart';
import 'core_locator.dart';
import 'vpn_core.dart';

/// Runs Xray as a child process. The config is piped through stdin so
/// credentials never touch the disk.
class DesktopXrayCore extends VpnCore {
  Process? _process;
  Future<int?>? _exited;
  bool _stopping = false;
  final _tail = <String>[];

  File get _pidFile => AppPaths.file('core.pid');

  @override
  bool get isRunning => _process != null;

  @override
  Future<bool> isInstalled() async => await CoreLocator.resolve() != null;

  @override
  Future<String?> version() async {
    final bin = await CoreLocator.resolve();
    return bin == null ? null : CoreLocator.version(bin);
  }

  Future<void> _ensurePortFree(int port) async {
    try {
      final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      await s.close();
    } catch (_) {
      throw CoreException(CoreErrorKind.portBusy, tr('Порт $port уже занят другим приложением', 'Port $port is already in use'));
    }
  }

  @override
  Future<void> start(
    Map<String, dynamic> config, {
    required TunnelMode mode,
    required Duration timeout,
    required int readyPort,
  }) async {
    if (_process != null) await stop();
    final bin = await CoreLocator.resolve();
    if (bin == null) {
      throw CoreException(CoreErrorKind.missing, tr('Ядро Xray не установлено', 'Xray core is not installed'));
    }
    for (final ib in (config['inbounds'] as List).cast<Map>()) {
      final port = ib['port'];
      if (port is int && port > 0) await _ensurePortFree(port);
    }
    if (mode == TunnelMode.tun) await Privileges.ensureTun(bin);

    _stopping = false;
    _tail.clear();
    final dir = CoreLocator.assetDir(bin);
    log.i('Starting Xray (${mode.name}) — $bin');
    final p = await Process.start(
      bin,
      ['run', '-c', 'stdin:'],
      workingDirectory: dir,
      environment: {'XRAY_LOCATION_ASSET': dir},
      mode: Sys.backgroundMode,
    );
    _process = p;
    final exited = Completer<int?>();
    _exited = exited.future;
    _pidFile.writeAsStringSync('${p.pid}');

    final ready = Completer<void>();
    void onLine(String line) {
      if (line.trim().isEmpty) return;
      log.core(line);
      _tail.add(line);
      if (_tail.length > 12) _tail.removeAt(0);
      if (!ready.isCompleted) {
        if (line.contains('started') && line.contains('Xray')) ready.complete();
        if (line.contains('Failed to start') || line.contains('failed to load config')) {
          ready.completeError(CoreException(CoreErrorKind.startFailed, _cleanError(line)));
        }
      }
    }

    // Detached processes (Windows) expose no exit code: closing of both pipes means exit.
    var openPipes = 2;
    void pipeDone() {
      if (--openPipes == 0 && Platform.isWindows && !exited.isCompleted) exited.complete(null);
    }

    const decoder = Utf8Decoder(allowMalformed: true);
    p.stdout.transform(decoder).transform(const LineSplitter()).listen(onLine, onDone: pipeDone, onError: (_) {});
    p.stderr.transform(decoder).transform(const LineSplitter()).listen(onLine, onDone: pipeDone, onError: (_) {});
    if (!Platform.isWindows) {
      unawaited(p.exitCode.then((c) {
        if (!exited.isCompleted) exited.complete(c);
      }));
    }

    unawaited(exited.future.then((code) {
      final wasCurrent = identical(_process, p);
      if (wasCurrent) _process = null;
      if (_pidFile.existsSync()) _pidFile.deleteSync();
      if (!ready.isCompleted) {
        final reason = _tail.where((l) => l.toLowerCase().contains('fail') || l.contains('error')).lastOrNull ??
            _tail.lastOrNull ??
            'exit code ${code ?? '?'}';
        ready.completeError(CoreException(CoreErrorKind.startFailed, _cleanError(reason)));
      } else if (!_stopping && wasCurrent) {
        log.e('Xray exited unexpectedly (code ${code ?? '?'})');
        onCrash?.call(tr('Ядро неожиданно завершило работу', 'Core exited unexpectedly'));
      }
    }));

    p.stdin.write(XrayConfigBuilder.encode(config));
    await p.stdin.flush();
    await p.stdin.close();

    // Readiness: either the "started" log line or the inbound port accepting connections.
    final poll = Timer.periodic(const Duration(milliseconds: 150), (_) async {
      if (ready.isCompleted) return;
      try {
        final s = await Socket.connect(InternetAddress.loopbackIPv4, readyPort, timeout: const Duration(milliseconds: 120));
        s.destroy();
        if (!ready.isCompleted) ready.complete();
      } catch (_) {}
    });
    try {
      await ready.future.timeout(timeout);
      log.i('Xray is running (pid ${p.pid})');
    } on TimeoutException {
      await stop();
      throw CoreException(CoreErrorKind.timeout, tr('Ядро не запустилось за ${timeout.inSeconds} с', 'Core did not start within ${timeout.inSeconds}s'));
    } catch (_) {
      await stop();
      rethrow;
    } finally {
      poll.cancel();
    }
  }

  String _cleanError(String line) {
    final i = line.indexOf('>');
    final msg = (i >= 0 ? line.substring(i + 1) : line).trim();
    return msg.length > 220 ? '${msg.substring(0, 220)}…' : msg;
  }

  @override
  Future<void> stop() async {
    final p = _process;
    if (p == null) return;
    _stopping = true;
    _process = null;
    if (Platform.isWindows) {
      Process.killPid(p.pid);
    } else {
      p.kill(ProcessSignal.sigterm);
    }
    try {
      await (_exited ?? Future<void>.value()).timeout(const Duration(seconds: 3));
    } on TimeoutException {
      Process.killPid(p.pid, ProcessSignal.sigkill);
    }
    if (_pidFile.existsSync()) _pidFile.deleteSync();
    log.i('Xray stopped');
  }

  @override
  Future<void> cleanupOrphans() async {
    if (!_pidFile.existsSync()) return;
    final pid = int.tryParse(_pidFile.readAsStringSync().trim());
    _pidFile.deleteSync();
    if (pid == null) return;
    try {
      if (Platform.isWindows) {
        final out = await Sys.output('tasklist', ['/FI', 'PID eq $pid', '/NH']);
        if (out.toLowerCase().contains('xray') && Process.killPid(pid)) {
          log.w('Killed orphan Xray process $pid');
        }
      } else {
        final comm = File('/proc/$pid/comm');
        final isXray = comm.existsSync()
            ? comm.readAsStringSync().contains('xray')
            : '${(await Process.run('ps', ['-p', '$pid', '-o', 'comm='])).stdout}'.contains('xray');
        if (isXray && Process.killPid(pid)) log.w('Killed orphan Xray process $pid');
      }
    } catch (_) {}
  }
}
