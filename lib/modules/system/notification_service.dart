import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/storage/paths.dart';
import '../logs/log_service.dart';

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _id = 0;

  Future<void> init() async {
    try {
      final iconPath = '${AppPaths.exeDir}${Platform.pathSeparator}data${Platform.pathSeparator}flutter_assets'
          '${Platform.pathSeparator}assets${Platform.pathSeparator}icons${Platform.pathSeparator}app_icon_512.png';
      _ready = await _plugin.initialize(
            settings: InitializationSettings(
              android: const AndroidInitializationSettings('ic_stat_sharrow'),
              iOS: const DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
              macOS: const DarwinInitializationSettings(),
              linux: LinuxInitializationSettings(defaultActionName: 'Open', defaultIcon: FilePathLinuxIcon(iconPath)),
              windows: WindowsInitializationSettings(
                appName: 'Sharrow',
                appUserModelId: 'App.Sharrow.Desktop',
                guid: '6f1d6b0e-3c1a-4e57-9a63-2b8f6a1c9d42',
                iconPath: File(iconPath).existsSync() ? iconPath : null,
              ),
            ),
          ) ??
          false;
      if (Platform.isAndroid) {
        await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      }
    } catch (e) {
      log.w('Notifications unavailable: $e');
    }
  }

  Future<void> show(String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _id++ % 1000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('sharrow_events', 'Sharrow', importance: Importance.low, priority: Priority.low),
          iOS: DarwinNotificationDetails(presentSound: false),
          macOS: DarwinNotificationDetails(presentSound: false),
          linux: LinuxNotificationDetails(),
          windows: WindowsNotificationDetails(),
        ),
      );
    } catch (e) {
      log.w('Notification failed: $e');
    }
  }
}
