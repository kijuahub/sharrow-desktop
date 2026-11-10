import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Loopback-socket lock: the first instance listens, later ones forward
/// their arguments to it and exit.
abstract final class SingleInstance {
  static const _port = 47917;
  static ServerSocket? _server;

  /// Returns true if this process is the primary instance.
  static Future<bool> acquire(List<String> args, {Duration wait = Duration.zero}) async {
    final deadline = DateTime.now().add(wait);
    while (true) {
      try {
        _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, _port);
        return true;
      } on SocketException {
        if (DateTime.now().isAfter(deadline)) break;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
    try {
      final s = await Socket.connect(InternetAddress.loopbackIPv4, _port, timeout: const Duration(seconds: 1));
      s.write('${jsonEncode(['show', ...args])}\n');
      await s.flush();
      await s.close();
    } catch (_) {
      // Port held by something else: run anyway rather than refusing to start.
      return true;
    }
    return false;
  }

  static void listen(void Function(List<String> args) onMessage) {
    _server?.listen((client) {
      client.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        try {
          onMessage((jsonDecode(line) as List).map((e) => '$e').toList());
        } catch (_) {}
      }, onError: (_) {});
    });
  }

  static Future<void> release() async {
    await _server?.close();
    _server = null;
  }
}
