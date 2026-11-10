import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../data/models/server.dart';

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

  /// Pings servers with bounded concurrency; [onResult] fires per server.
  Future<void> pingAll(
    List<ServerProfile> servers, {
    required Duration timeout,
    int concurrency = 16,
    void Function(ServerProfile server)? onResult,
  }) async {
    var index = 0;
    Future<void> worker() async {
      while (index < servers.length) {
        final s = servers[index++];
        if (s.isUdp) continue;
        s.ping = await tcp(s.address, s.port, timeout);
        s.pingAt = DateTime.now();
        onResult?.call(s);
      }
    }

    await Future.wait(List.generate(min(concurrency, max(1, servers.length)), (_) => worker()));
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
