import 'dart:io';

import '../../core/l10n.dart';
import '../logs/log_service.dart';
import '../xray/vpn_core.dart';
import 'win32.dart';

/// TUN requires elevated rights: admin on Windows, CAP_NET_ADMIN on Linux, root on macOS.
abstract final class Privileges {
  static bool? _isAdmin;

  static Future<bool> isElevated() async {
    if (_isAdmin != null) return _isAdmin!;
    try {
      if (Platform.isWindows) {
        _isAdmin = Win32.isUserAnAdmin();
      } else {
        final r = await Process.run('id', ['-u']);
        _isAdmin = '${r.stdout}'.trim() == '0';
      }
    } catch (_) {
      _isAdmin = false;
    }
    return _isAdmin!;
  }

  static Future<void> ensureTun(String binary) async {
    if (await isElevated()) return;
    if (Platform.isWindows) {
      throw CoreException(
        CoreErrorKind.permission,
        tr('Для режима TUN нужны права администратора', 'TUN mode requires administrator rights'),
      );
    }
    if (Platform.isLinux) {
      if (await _hasCaps(binary)) return;
      log.i('Requesting CAP_NET_ADMIN for Xray via pkexec');
      final r = await Process.run('pkexec', ['setcap', 'cap_net_admin,cap_net_raw,cap_net_bind_service=+eip', binary]);
      if (r.exitCode == 0 && await _hasCaps(binary)) return;
      throw CoreException(
        CoreErrorKind.permission,
        tr('Не удалось выдать ядру права на TUN (pkexec setcap)', 'Failed to grant TUN capability to the core (pkexec setcap)'),
      );
    }
    throw CoreException(
      CoreErrorKind.permission,
      tr('Режим TUN на macOS требует запуска с правами root', 'TUN mode on macOS requires root privileges'),
    );
  }

  static Future<bool> _hasCaps(String binary) async {
    try {
      final r = await Process.run('getcap', [binary]);
      return '${r.stdout}'.contains('cap_net_admin');
    } catch (_) {
      return false;
    }
  }

  /// Restarts the app elevated (Windows UAC prompt). Returns false if the user declined.
  static Future<bool> relaunchElevated(List<String> args) async {
    if (!Platform.isWindows) return false;
    return Win32.runAsAdmin(Platform.resolvedExecutable, args.join(' '));
  }
}
