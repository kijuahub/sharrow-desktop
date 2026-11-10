import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract final class AppPaths {
  static late Directory root;
  static late Directory core;
  static late Directory logs;

  static Future<void> init() async {
    root = await getApplicationSupportDirectory();
    core = Directory('${root.path}${Platform.pathSeparator}core');
    logs = Directory('${root.path}${Platform.pathSeparator}logs');
    for (final d in [root, core, logs]) {
      if (!d.existsSync()) d.createSync(recursive: true);
    }
  }

  static File file(String name) => File('${root.path}${Platform.pathSeparator}$name');

  static String join(Directory dir, String name) => '${dir.path}${Platform.pathSeparator}$name';

  /// Directory of the running executable (bundled resources live next to it).
  static String get exeDir => File(Platform.resolvedExecutable).parent.path;
}
