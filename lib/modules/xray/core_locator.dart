import 'dart:io';

import '../../data/storage/paths.dart';
import '../system/sys.dart';

/// Resolves the Xray binary and asset directory on desktop platforms.
abstract final class CoreLocator {
  static String customPath = '';

  static String get binaryName => Platform.isWindows ? 'xray.exe' : 'xray';

  static String get defaultBinary => AppPaths.join(AppPaths.core, binaryName);

  static String get bundledDir => '${AppPaths.exeDir}${Platform.pathSeparator}core';

  /// Returns the binary path, seeding the writable core dir from the bundled
  /// copy on first launch so updates and setcap work on read-only installs.
  static Future<String?> resolve() async {
    if (customPath.isNotEmpty && File(customPath).existsSync()) return customPath;
    final target = File(defaultBinary);
    if (target.existsSync()) return target.path;
    final bundled = Directory(bundledDir);
    if (File('${bundled.path}${Platform.pathSeparator}$binaryName').existsSync()) {
      for (final f in bundled.listSync().whereType<File>()) {
        await f.copy(AppPaths.join(AppPaths.core, f.uri.pathSegments.last));
      }
      if (!Platform.isWindows) await Process.run('chmod', ['+x', target.path]);
      return target.path;
    }
    return null;
  }

  static String assetDir(String binary) => File(binary).parent.path;

  static Future<String?> version(String binary) async {
    final out = await Sys.output(binary, ['version'], timeout: const Duration(seconds: 5));
    return RegExp(r'Xray\s+([\d.]+\S*)').firstMatch(out)?.group(1);
  }
}
