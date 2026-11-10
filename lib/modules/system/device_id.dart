import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../../core/platform.dart';
import 'sys.dart';

/// Stable per-device identifier sent to subscription servers (x-hwid), plus the
/// device description headers used by Remnawave/Marzban-style panels.
abstract final class DeviceId {
  static String? _model;

  /// Derives the id from the OS machine id so it survives reinstalls; the raw
  /// machine id never leaves the device, only a salted hash of it.
  static Future<String> compute() async {
    final raw = await _machineId() ?? _random();
    final hash = await Sha256().hash(utf8.encode('sharrow-hwid:$raw'));
    return hash.bytes.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _random() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<String?> _machineId() async {
    try {
      if (Platform.isWindows) {
        final out = await Sys.output('reg', ['query', r'HKLM\SOFTWARE\Microsoft\Cryptography', '/v', 'MachineGuid']);
        return RegExp(r'MachineGuid\s+REG_SZ\s+(\S+)').firstMatch(out)?.group(1);
      }
      if (Platform.isLinux) {
        for (final p in ['/etc/machine-id', '/var/lib/dbus/machine-id']) {
          final f = File(p);
          if (f.existsSync()) return f.readAsStringSync().trim();
        }
      }
      if (Platform.isMacOS) {
        final out = await Sys.output('ioreg', ['-rd1', '-c', 'IOPlatformExpertDevice']);
        return RegExp(r'"IOPlatformUUID" = "([^"]+)"').firstMatch(out)?.group(1);
      }
    } catch (_) {}
    return null;
  }

  static String get os => switch (Platform.operatingSystem) {
        'windows' => 'Windows',
        'linux' => 'Linux',
        'macos' => 'macOS',
        'android' => 'Android',
        'ios' => 'iOS',
        final o => o,
      };

  static String get osVersion {
    final v = Platform.operatingSystemVersion;
    final m = RegExp(r'(\d+(\.\d+){1,3})').firstMatch(v);
    return m?.group(1) ?? v;
  }

  static Future<String> model() async {
    if (_model != null) return _model!;
    String? m;
    try {
      if (Platform.isWindows) {
        final out = await Sys.output('reg', ['query', r'HKLM\HARDWARE\DESCRIPTION\System\BIOS', '/v', 'SystemProductName']);
        m = RegExp(r'SystemProductName\s+REG_SZ\s+(.+)').firstMatch(out)?.group(1)?.trim();
      } else if (Platform.isLinux) {
        final f = File('/sys/class/dmi/id/product_name');
        if (f.existsSync()) m = f.readAsStringSync().trim();
      } else if (Platform.isMacOS) {
        m = (await Sys.output('sysctl', ['-n', 'hw.model'])).trim();
      }
    } catch (_) {}
    return _model = (m == null || m.isEmpty) ? (Plat.isDesktop ? '$os PC' : os) : m;
  }

  static Future<Map<String, String>> headers(String hwid) async => {
        'x-hwid': hwid,
        'x-device-os': os,
        'x-ver-os': osVersion,
        'x-device-model': await model(),
      };
}
