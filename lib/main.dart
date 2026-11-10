// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:window_manager/legacy.dart';

import 'app.dart';
import 'core/platform.dart';
import 'data/models/settings.dart';
import 'data/storage/paths.dart';
import 'modules/logs/log_service.dart';
import 'modules/system/single_instance.dart';
import 'state/app_controller.dart';

Future<void> main(List<String> argv) async {
  WidgetsFlutterBinding.ensureInitialized();
  final args = LaunchArgs.parse(argv);

  if (Plat.isDesktop) {
    // An elevated relaunch has to wait for the old instance to release the lock.
    final primary = await SingleInstance.acquire(argv, wait: args.tun ? const Duration(seconds: 8) : Duration.zero);
    if (!primary) exit(0);
  }

  await AppPaths.init();

  FlutterError.onError = (d) {
    log.e('Flutter', d.exceptionAsString());
    FlutterError.presentError(d);
  };

  final controller = AppController(args);
  controller.settings.load();
  final s = controller.settings;
  final startHidden = Plat.isDesktop &&
      s.get(K.showTray) &&
      (args.minimized || s.get(K.startMinimized) || (args.autostart && s.get(K.autostartMinimized)));

  if (Plat.isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1180, 760),
        minimumSize: Size(380, 600),
        center: true,
        title: 'Sharrow',
        titleBarStyle: TitleBarStyle.hidden,
        backgroundColor: Color(0xFF0B0C0E),
        skipTaskbar: false,
      ),
    );
    await windowManager.setPreventClose(true);
    if (startHidden) {
      controller.visible.value = false;
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  PlatformDispatcher.instance.onError = (e, st) {
    log.e('Unhandled', e);
    return true;
  };

  runApp(SharrowApp(controller: controller));

  await controller.init();
}
