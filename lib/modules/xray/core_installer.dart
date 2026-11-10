import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../../core/l10n.dart';
import '../../data/storage/paths.dart';
import '../logs/log_service.dart';
import 'core_locator.dart';

/// Downloads and updates the Xray binary, geo databases and (on Windows) Wintun.
class CoreInstaller extends ChangeNotifier {
  bool busy = false;
  String? stage;
  double? progress;
  String? error;

  String mirror = '';
  String? httpProxy;

  static const geoSources = <String, (String, String)>{
    'xray': (
      'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat',
      'https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat',
    ),
    'runetfreedom': (
      'https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geoip.dat',
      'https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/latest/download/geosite.dat',
    ),
    'v2fly': (
      'https://github.com/v2fly/geoip/releases/latest/download/geoip.dat',
      'https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat',
    ),
  };

  static String? get assetName => switch (Abi.current()) {
        Abi.windowsX64 => 'Xray-windows-64.zip',
        Abi.windowsArm64 => 'Xray-windows-arm64-v8a.zip',
        Abi.linuxX64 => 'Xray-linux-64.zip',
        Abi.linuxArm64 => 'Xray-linux-arm64-v8a.zip',
        Abi.macosX64 => 'Xray-macos-64.zip',
        Abi.macosArm64 => 'Xray-macos-arm64-v8a.zip',
        _ => null,
      };

  String _url(String url) => mirror.isEmpty ? url : '${mirror.endsWith('/') ? mirror : '$mirror/'}$url';

  HttpClient _client() {
    final c = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..userAgent = 'Sharrow-Desktop';
    if (httpProxy != null) c.findProxy = (_) => 'PROXY $httpProxy';
    return c;
  }

  void _set({String? stage, double? progress, bool clearProgress = false}) {
    if (stage != null) this.stage = stage;
    if (clearProgress) {
      this.progress = null;
    } else if (progress != null) {
      this.progress = progress;
    }
    notifyListeners();
  }

  static const _stallTimeout = Duration(seconds: 20);

  Future<Uint8List> _download(String url, String label, {bool viaMirror = true}) async {
    final client = _client();
    try {
      final req = await client.getUrl(Uri.parse(viaMirror ? _url(url) : url));
      final res = await req.close().timeout(_stallTimeout);
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
      final total = res.contentLength;
      final builder = BytesBuilder(copy: false);
      var received = 0;
      var lastNotify = 0;
      final stream = res.timeout(_stallTimeout, onTimeout: (sink) {
        sink.addError(TimeoutException(tr('Загрузка зависла: сервер перестал отвечать', 'Download stalled: the server stopped responding')));
        sink.close();
      });
      await for (final chunk in stream) {
        builder.add(chunk);
        received += chunk.length;
        if (total > 0 && received - lastNotify > 256 * 1024) {
          lastNotify = received;
          _set(stage: label, progress: received / total);
        }
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> latestXrayVersion() async {
    final client = _client();
    try {
      final req = await client.getUrl(Uri.parse('https://api.github.com/repos/XTLS/Xray-core/releases/latest'));
      req.headers.set('Accept', 'application/vnd.github+json');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
      return (body['tag_name'] as String?)?.replaceFirst('v', '');
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<T> _run<T>(Future<T> Function() task) async {
    if (busy) throw StateError('busy');
    busy = true;
    error = null;
    notifyListeners();
    try {
      return await task();
    } catch (e) {
      error = '$e';
      log.e('Installer failed', e);
      rethrow;
    } finally {
      busy = false;
      stage = null;
      progress = null;
      notifyListeners();
    }
  }

  /// Installs or updates Xray; returns the installed version.
  Future<String?> installXray() => _run(() async {
        final asset = assetName;
        if (asset == null) throw UnsupportedError(tr('Платформа не поддерживается', 'Unsupported platform'));
        final label = tr('Загрузка ядра Xray', 'Downloading Xray core');
        _set(stage: label, progress: 0);
        log.i('Downloading $asset');
        final bytes = await _download('https://github.com/XTLS/Xray-core/releases/latest/download/$asset', label);
        _set(stage: tr('Установка', 'Installing'), clearProgress: true);
        final archive = ZipDecoder().decodeBytes(bytes);
        const wanted = {'xray', 'xray.exe', 'geoip.dat', 'geosite.dat'};
        for (final f in archive.files) {
          if (!f.isFile) continue;
          final name = f.name.split('/').last.toLowerCase();
          if (!wanted.contains(name)) continue;
          final out = File(AppPaths.join(AppPaths.core, name));
          final tmp = File('${out.path}.new');
          await tmp.writeAsBytes(f.content, flush: true);
          if (out.existsSync()) await out.delete();
          await tmp.rename(out.path);
        }
        if (!Platform.isWindows) await Process.run('chmod', ['+x', CoreLocator.defaultBinary]);
        if (Platform.isWindows) {
          try {
            await _installWintun();
          } catch (e) {
            log.w('Wintun was not installed, TUN will retry later: $e');
          }
        }
        final v = await CoreLocator.version(CoreLocator.defaultBinary);
        log.i('Xray installed: $v');
        return v;
      });

  static File get _wintunTarget => File(AppPaths.join(AppPaths.core, 'wintun.dll'));

  static bool get hasWintun => _wintunTarget.existsSync();

  /// Makes sure wintun.dll sits next to xray.exe (needed for TUN on Windows).
  Future<void> ensureWintun() async {
    if (!Platform.isWindows || hasWintun) return;
    if (busy) return;
    await _run(_installWintun);
  }

  Future<void> _installWintun() async {
    final target = _wintunTarget;
    if (target.existsSync()) return;
    for (final dir in [AppPaths.exeDir, CoreLocator.bundledDir]) {
      final bundled = File('$dir${Platform.pathSeparator}wintun.dll');
      if (bundled.existsSync()) {
        await bundled.copy(target.path);
        return;
      }
    }
    final label = tr('Загрузка драйвера Wintun', 'Downloading Wintun driver');
    _set(stage: label, progress: 0);
    final bytes = await _download('https://www.wintun.net/builds/wintun-0.14.1.zip', label, viaMirror: false);
    final arch = Abi.current() == Abi.windowsArm64 ? 'arm64' : 'amd64';
    final archive = ZipDecoder().decodeBytes(bytes);
    final dll = archive.files.firstWhere((f) => f.name == 'wintun/bin/$arch/wintun.dll');
    await target.writeAsBytes(dll.content, flush: true);
  }

  Future<void> updateGeo(String source) => _run(() async {
        final (ipUrl, siteUrl) = geoSources[source] ?? geoSources['xray']!;
        for (final (url, name) in [(ipUrl, 'geoip.dat'), (siteUrl, 'geosite.dat')]) {
          final label = tr('Загрузка $name', 'Downloading $name');
          _set(stage: label, progress: 0);
          final bytes = await _download(url, label);
          if (bytes.length < 1024) throw const FormatException('Downloaded file is too small');
          final out = File(AppPaths.join(AppPaths.core, name));
          final tmp = File('${out.path}.new');
          await tmp.writeAsBytes(bytes, flush: true);
          if (out.existsSync()) await out.delete();
          await tmp.rename(out.path);
        }
        log.i('Geo files updated from $source');
      });
}
