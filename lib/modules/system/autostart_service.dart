import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

import '../../core/platform.dart';
import '../logs/log_service.dart';

abstract final class AutostartService {
  static const flag = '--autostart';
  static bool _setup = false;

  static void _ensure() {
    if (_setup) return;
    launchAtStartup.setup(
      appName: 'Sharrow',
      appPath: Platform.resolvedExecutable,
      packageName: 'app.sharrow.sharrow',
      args: const [flag],
    );
    _setup = true;
  }

  static Future<bool> isEnabled() async {
    if (!Plat.isDesktop) return false;
    _ensure();
    try {
      return await launchAtStartup.isEnabled();
    } catch (_) {
      return false;
    }
  }

  static Future<void> apply(bool enabled) async {
    if (!Plat.isDesktop) return;
    _ensure();
    try {
      final current = await launchAtStartup.isEnabled();
      if (current == enabled) return;
      enabled ? await launchAtStartup.enable() : await launchAtStartup.disable();
      log.i('Autostart ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      log.e('Autostart change failed', e);
    }
  }
}
