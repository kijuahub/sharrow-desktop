import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import '../../data/models/server.dart';
import '../../data/models/settings.dart';
import '../system/sys.dart';
import '../xray/config_builder.dart';
import '../xray/core_locator.dart';

/// Latency from `ping` output. -1 when the host did not answer.
int parseIcmpOutput(String text) {
  final m = RegExp(r'(?:time|время)\s*[=<]\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(text) ??
      RegExp(r'[=<]\s*(\d+(?:\.\d+)?)\s*\S*\s*ttl', caseSensitive: false).firstMatch(text);
  if (m == null) return -1;
  return max(1, double.parse(m.group(1)!).round());
}

class PingService {
  /// TCP handshake latency. DNS resolution is done first and excluded.
  Future<int> tcp(String host, int port, Duration timeout) async {
    if (host.isEmpty || port <= 0) return -1;
    try {
      final addrs = await InternetAddress.lookup(host).timeout(timeout);
      if (addrs.isEmpty) return -1;
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(addrs.first, port, timeout: timeout);
      sw.stop();
      socket.destroy();
      return max(1, sw.elapsedMilliseconds);
    } catch (_) {
      return -1;
    }
  }

  /// ICMP echo. Hysteria2 and WireGuard do not accept a TCP handshake.
  Future<int> icmp(String host, Duration timeout) async {
    if (host.isEmpty) return -1;
    final ms = timeout.inMilliseconds.clamp(500, 15000);
    if (Platform.isIOS || Platform.isAndroid) {
      final native = await _mobileIcmp(host, ms);
      if (native > 0 || Platform.isIOS) return native < 0 ? -1 : native;
      if (native == -2) {
        return await _execPing('/system/bin/ping', ['-c', '1', '-W', '${(ms / 1000).ceil()}', host], timeout) ?? -1;
      }
      return -1;
    }
    final args = Platform.isWindows
        ? ['-n', '1', '-w', '$ms', host]
        : Platform.isMacOS
            ? ['-c', '1', '-W', '$ms', host]
            : ['-c', '1', '-W', '${(ms / 1000).ceil()}', host];
    return await _execPing('ping', args, timeout) ?? -1;
  }

  /// null when the ping program cannot be started.
  Future<int?> _execPing(String exe, List<String> args, Duration timeout) async {
    try {
      final p = await Process.start(exe, args);
      final chunks = <int>[];
      final out = p.stdout.listen(chunks.addAll);
      final err = p.stderr.listen(chunks.addAll);
      final timer = Timer(timeout + const Duration(milliseconds: 800), () => p.kill());
      await p.exitCode;
      timer.cancel();
      await out.cancel();
      await err.cancel();
      return parseIcmpOutput(latin1.decode(chunks, allowInvalid: true));
    } catch (_) {
      return null;
    }
  }

  Future<int> _mobileIcmp(String host, int timeoutMs) async {
    try {
      final v = await const MethodChannel('app.sharrow/vpn').invokeMethod<int>('icmp', {'host': host, 'timeout': timeoutMs});
      return v ?? -1;
    } catch (_) {
      return -1;
    }
  }

  /// HTTP request to the server itself. TLS is used for 443 and for TLS outbounds.
  Future<int> http(ServerProfile server, Duration timeout, {required bool head}) async {
    if (server.address.isEmpty || server.port <= 0) return -1;
    final tls = server.port == 443 || server.security == 'tls' || server.security == 'reality';
    final uri = Uri.parse('${tls ? 'https' : 'http'}://${server.address}:${server.port}/');
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..badCertificateCallback = (_, _, _) => true;
    try {
      final sw = Stopwatch()..start();
      final req = await (head ? client.headUrl(uri) : client.getUrl(uri)).timeout(timeout);
      req.followRedirects = false;
      final res = await req.close().timeout(timeout);
      await res.drain<void>().timeout(timeout);
      return max(1, sw.elapsedMilliseconds);
    } catch (_) {
      return -1;
    } finally {
      client.close(force: true);
    }
  }

  /// [method] is `tcp`, `icmp`, `http-get`, `http-head` or `sharrow`.
  Future<int> measure(ServerProfile server, String method, Duration timeout, {Settings? settings}) {
    return switch (method) {
      'icmp' => icmp(server.address, timeout),
      'http-get' => http(server, timeout, head: false),
      'http-head' => http(server, timeout, head: true),
      'sharrow' => settings == null ? Future<int>.value(-1) : sharrow(server, settings, timeout),
      _ => server.isUdp ? icmp(server.address, timeout) : tcp(server.address, server.port, timeout),
    };
  }

  /// HTTP GET of the test URL through a short-lived proxy for this server.
  /// The first request warms the tunnel; the second is the number shown.
  Future<int> sharrow(ServerProfile server, Settings settings, Duration timeout) async {
    final bin = await CoreLocator.resolve();
    if (bin == null) return _get(settings.get(K.pingTestUrl), settings.get(K.httpPort), timeout);
    ServerSocket? hold;
    Process? proc;
    try {
      hold = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = hold.port;
      await hold.close();
      hold = null;
      final cfg = XrayConfigBuilder.build(server, settings, mode: TunnelMode.proxy);
      cfg['inbounds'] = [
        {'tag': 'http-in', 'listen': '127.0.0.1', 'port': port, 'protocol': 'http', 'settings': <String, dynamic>{}},
      ];
      final dir = CoreLocator.assetDir(bin);
      proc = await Process.start(
        bin,
        ['run', '-c', 'stdin:'],
        workingDirectory: dir,
        environment: {'XRAY_LOCATION_ASSET': dir},
        mode: Sys.backgroundMode,
      );
      proc.stdout.listen((_) {});
      proc.stderr.listen((_) {});
      proc.stdin.add(utf8.encode(jsonEncode(cfg)));
      await proc.stdin.close();
      final url = settings.get(K.pingTestUrl);
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        final left = deadline.difference(DateTime.now());
        final warm = await _get(url, port, left < const Duration(seconds: 2) ? left : const Duration(seconds: 2));
        if (warm > 0) {
          final measured = await _get(url, port, deadline.difference(DateTime.now()));
          return measured > 0 ? measured : warm;
        }
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      return -1;
    } catch (_) {
      return -1;
    } finally {
      proc?.kill();
      await hold?.close();
    }
  }

  Future<int> _get(String testUrl, int httpPort, Duration timeout) async {
    if (timeout.inMilliseconds < 150) return -1;
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..findProxy = ((_) => 'PROXY 127.0.0.1:$httpPort')
      ..badCertificateCallback = (_, _, _) => true;
    try {
      final sw = Stopwatch()..start();
      final req = await client.getUrl(Uri.parse(testUrl)).timeout(timeout);
      req.followRedirects = false;
      final res = await req.close().timeout(timeout);
      await res.drain<void>().timeout(timeout);
      if (res.statusCode >= 500) return -1;
      return max(1, sw.elapsedMilliseconds);
    } catch (_) {
      return -1;
    } finally {
      client.close(force: true);
    }
  }

  /// One request, through the local HTTP inbound when [httpPort] is set.
  /// -1 when nothing answers.
  Future<int> probe(String testUrl, int? httpPort, Duration timeout) async {
    final client = HttpClient()..connectionTimeout = timeout;
    if (httpPort != null) client.findProxy = ((_) => 'PROXY 127.0.0.1:$httpPort');
    try {
      final sw = Stopwatch()..start();
      final req = await client.headUrl(Uri.parse(testUrl)).timeout(timeout);
      final res = await req.close().timeout(timeout);
      await res.drain<void>();
      if (res.statusCode >= 500) return -1;
      return max(1, sw.elapsedMilliseconds);
    } catch (_) {
      return -1;
    } finally {
      client.close(force: true);
    }
  }

  /// Pings servers with bounded concurrency; [onResult] fires per server.
  Future<void> pingAll(
    List<ServerProfile> servers, {
    required Duration timeout,
    int concurrency = 16,
    String method = 'tcp',
    Settings? settings,
    void Function(ServerProfile server)? onResult,
  }) async {
    final lanes = method == 'sharrow' ? min(3, concurrency) : concurrency;
    var index = 0;
    Future<void> worker() async {
      while (index < servers.length) {
        final s = servers[index++];
        s.ping = await measure(s, method, timeout, settings: settings);
        s.pingAt = DateTime.now();
        onResult?.call(s);
      }
    }

    await Future.wait(List.generate(min(lanes, max(1, servers.length)), (_) => worker()));
  }

  /// End-to-end latency of an HTTP request through the local proxy inbound.
  Future<int> realDelay(String testUrl, int httpPort, Duration timeout) async {
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..findProxy = ((_) => 'PROXY 127.0.0.1:$httpPort');
    try {
      Future<int> once() async {
        final sw = Stopwatch()..start();
        final req = await client.headUrl(Uri.parse(testUrl)).timeout(timeout);
        final res = await req.close().timeout(timeout);
        await res.drain<void>();
        return sw.elapsedMilliseconds;
      }

      // First request warms up the tunnel (TLS + mux), the second is the measurement.
      await once();
      return max(1, await once());
    } catch (_) {
      return -1;
    } finally {
      client.close(force: true);
    }
  }
}
