import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Process helpers. On Windows child processes are started detached so a GUI
/// app never flashes a console window.
abstract final class Sys {
  static ProcessStartMode get backgroundMode =>
      Platform.isWindows ? ProcessStartMode.detachedWithStdio : ProcessStartMode.normal;

  /// Runs a command and returns its stdout (exit code is not available on Windows).
  static Future<String> output(String exe, List<String> args, {Duration timeout = const Duration(seconds: 8)}) async {
    try {
      if (!Platform.isWindows) {
        final r = await Process.run(exe, args).timeout(timeout);
        return '${r.stdout}';
      }
      final p = await Process.start(exe, args, mode: ProcessStartMode.detachedWithStdio);
      unawaited(p.stderr.drain<void>());
      await p.stdin.close();
      return await p.stdout.transform(const Utf8Decoder(allowMalformed: true)).join().timeout(timeout);
    } catch (_) {
      return '';
    }
  }
}
