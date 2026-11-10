import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

@immutable
class TrafficSample {
  const TrafficSample({this.up = 0, this.down = 0, this.totalUp = 0, this.totalDown = 0});

  final int up;
  final int down;
  final int totalUp;
  final int totalDown;
}

/// Polls Xray's expvar metrics endpoint for proxy outbound counters.
class StatsService extends ValueNotifier<TrafficSample?> {
  StatsService() : super(null);

  Timer? _timer;
  HttpClient? _client;
  int _lastUp = 0;
  int _lastDown = 0;
  DateTime? _lastAt;
  int _failures = 0;

  void start(int port) {
    stop();
    _client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
    _failures = 0;
    _lastAt = null;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll(port));
  }

  void pause() => _timer?.cancel();

  void resume(int port) {
    if (_client == null) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _poll(port));
  }

  Future<void> _poll(int port) async {
    final client = _client;
    if (client == null) return;
    try {
      final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port/debug/vars'));
      final res = await req.close();
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
      final outbound = ((body['stats'] as Map?)?['outbound'] as Map?) ?? const {};
      var up = 0, down = 0;
      final proxy = outbound['proxy'] as Map?;
      if (proxy != null) {
        up = (proxy['uplink'] as num?)?.toInt() ?? 0;
        down = (proxy['downlink'] as num?)?.toInt() ?? 0;
      } else {
        for (final e in outbound.entries) {
          if (e.key == 'direct' || e.key == 'block' || e.key == 'dns-out') continue;
          final m = e.value as Map;
          up += (m['uplink'] as num?)?.toInt() ?? 0;
          down += (m['downlink'] as num?)?.toInt() ?? 0;
        }
      }
      final now = DateTime.now();
      if (_lastAt != null) {
        final dt = now.difference(_lastAt!).inMilliseconds / 1000.0;
        if (dt > 0) {
          value = TrafficSample(
            up: ((up - _lastUp).clamp(0, 1 << 40) / dt).round(),
            down: ((down - _lastDown).clamp(0, 1 << 40) / dt).round(),
            totalUp: up,
            totalDown: down,
          );
        }
      }
      _lastUp = up;
      _lastDown = down;
      _lastAt = now;
      _failures = 0;
    } catch (_) {
      if (++_failures > 5) stop();
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _client?.close(force: true);
    _client = null;
    value = null;
  }
}
