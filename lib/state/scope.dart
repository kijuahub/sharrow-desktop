import 'package:flutter/widgets.dart';

import 'app_controller.dart';

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.app, required super.child});

  final AppController app;

  static AppController of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.app;

  @override
  bool updateShouldNotify(AppScope oldWidget) => !identical(app, oldWidget.app);
}

extension AppScopeX on BuildContext {
  AppController get app => AppScope.of(this);
}
