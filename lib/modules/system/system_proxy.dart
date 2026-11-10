import 'dart:io';

import '../logs/log_service.dart';
import 'win32.dart';

/// Applies / clears the OS-wide HTTP(S)+SOCKS proxy.
abstract final class SystemProxy {
  static Future<bool> enable({required int httpPort, required int socksPort, required String bypass}) async {
    try {
      if (Platform.isWindows) return await _windows(true, httpPort, socksPort, bypass);
      if (Platform.isLinux) return await _linux(true, httpPort, socksPort, bypass);
      if (Platform.isMacOS) return await _macos(true, httpPort, socksPort, bypass);
    } catch (e) {
      log.e('System proxy enable failed', e);
    }
    return false;
  }

  static Future<void> disable() async {
    try {
      if (Platform.isWindows) await _windows(false, 0, 0, '');
      if (Platform.isLinux) await _linux(false, 0, 0, '');
      if (Platform.isMacOS) await _macos(false, 0, 0, '');
    } catch (e) {
      log.e('System proxy disable failed', e);
    }
  }

  // ---- Windows: WinINet registry keys + settings-changed broadcast ----

  static const _regKey = r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  static Future<bool> _windows(bool on, int httpPort, int socksPort, String bypass) async {
    var ok = Win32.regSetDword(_regKey, 'ProxyEnable', on ? 1 : 0);
    if (on) {
      ok &= Win32.regSetString(_regKey, 'ProxyServer', '127.0.0.1:$httpPort');
      ok &= Win32.regSetString(_regKey, 'ProxyOverride', bypass);
    }
    try {
      Win32.refreshInternetSettings();
    } catch (e) {
      log.w('WinINet refresh failed: $e');
    }
    log.i(on ? 'System proxy set to 127.0.0.1:$httpPort' : 'System proxy cleared');
    return ok;
  }

  // ---- Linux: GNOME (gsettings) and KDE (kwriteconfig) ----

  static Future<bool> _linux(bool on, int httpPort, int socksPort, String bypass) async {
    var applied = false;
    Future<bool> gs(List<String> args) async {
      try {
        return (await Process.run('gsettings', ['set', ...args])).exitCode == 0;
      } catch (_) {
        return false;
      }
    }

    if (on) {
      final ignore = '[${bypass.split(';').where((e) => e.isNotEmpty && e != '<local>').map((e) => "'$e'").join(', ')}]';
      applied = await gs(['org.gnome.system.proxy', 'mode', 'manual']);
      if (applied) {
        for (final proto in ['http', 'https']) {
          await gs(['org.gnome.system.proxy.$proto', 'host', '127.0.0.1']);
          await gs(['org.gnome.system.proxy.$proto', 'port', '$httpPort']);
        }
        await gs(['org.gnome.system.proxy.socks', 'host', '127.0.0.1']);
        await gs(['org.gnome.system.proxy.socks', 'port', '$socksPort']);
        await gs(['org.gnome.system.proxy', 'ignore-hosts', ignore]);
      }
    } else {
      applied = await gs(['org.gnome.system.proxy', 'mode', 'none']);
    }

    for (final tool in ['kwriteconfig6', 'kwriteconfig5']) {
      try {
        Future<void> kw(String key, String value) =>
            Process.run(tool, ['--file', 'kioslaverc', '--group', 'Proxy Settings', '--key', key, value]);
        await kw('ProxyType', on ? '1' : '0');
        if (on) {
          await kw('httpProxy', 'http://127.0.0.1 $httpPort');
          await kw('httpsProxy', 'http://127.0.0.1 $httpPort');
          await kw('socksProxy', 'socks://127.0.0.1 $socksPort');
          await kw('NoProxyFor', bypass.replaceAll(';', ','));
        }
        applied = true;
        break;
      } catch (_) {}
    }
    log.i(on ? 'System proxy set (Linux desktop)' : 'System proxy cleared (Linux desktop)');
    return applied;
  }

  // ---- macOS: networksetup for every network service ----

  static Future<bool> _macos(bool on, int httpPort, int socksPort, String bypass) async {
    final list = await Process.run('networksetup', ['-listallnetworkservices']);
    final services = '${list.stdout}'.split('\n').skip(1).map((e) => e.trim()).where((e) => e.isNotEmpty && !e.startsWith('*'));
    for (final s in services) {
      if (on) {
        await Process.run('networksetup', ['-setwebproxy', s, '127.0.0.1', '$httpPort']);
        await Process.run('networksetup', ['-setsecurewebproxy', s, '127.0.0.1', '$httpPort']);
        await Process.run('networksetup', ['-setsocksfirewallproxy', s, '127.0.0.1', '$socksPort']);
        await Process.run('networksetup', ['-setproxybypassdomains', s, ...bypass.split(';').where((e) => e.isNotEmpty && e != '<local>')]);
      } else {
        await Process.run('networksetup', ['-setwebproxystate', s, 'off']);
        await Process.run('networksetup', ['-setsecurewebproxystate', s, 'off']);
        await Process.run('networksetup', ['-setsocksfirewallproxystate', s, 'off']);
      }
    }
    return true;
  }
}
