import 'dart:async';
import 'dart:io';

/// Detects changes of physical network interfaces (Wi-Fi switch, cable, VPN
/// adapter churn) by fingerprinting addresses every few seconds.
class NetworkWatcher {
  NetworkWatcher(this.onChange);

  final void Function() onChange;
  Timer? _timer;
  String? _last;

  static bool _ignored(String name) {
    final n = name.toLowerCase();
    return n.contains('sharrow') || n.contains('wintun') || n.contains('utun') || n.startsWith('tun') || n.contains('xray') || n.startsWith('lo');
  }

  Future<String> _fingerprint() async {
    final list = await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4);
    final parts = [
      for (final i in list)
        if (!_ignored(i.name)) '${i.name}=${i.addresses.map((a) => a.address).join(',')}',
    ]..sort();
    return parts.join('|');
  }

  void start() {
    stop();
    _fingerprint().then((f) => _last = f);
    _timer = Timer.periodic(const Duration(seconds: 6), (_) async {
      try {
        final f = await _fingerprint();
        if (_last != null && f != _last && f.isNotEmpty) onChange();
        _last = f;
      } catch (_) {}
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _last = null;
  }
}
