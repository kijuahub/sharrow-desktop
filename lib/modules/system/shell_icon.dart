import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';

import '../../data/storage/paths.dart';
import '../logs/log_service.dart';

int _iconBig = 0;
int _iconSmall = 0;

/// Window, taskbar and shortcut icon. The running executable keeps the icon
/// baked into the file: Windows locks that file for the life of the process.
abstract final class ShellIcon {
  static Future<void> apply(String? asset) async {
    if (!Platform.isWindows) return;
    final exe = Platform.resolvedExecutable;
    final String location;
    if (asset == null) {
      location = '$exe,0';
      final icon = _extract(exe);
      if (icon != 0) _paint(icon, icon);
    } else {
      final png = await _png(asset);
      final file = AppPaths.file('shell_icon.ico');
      await file.writeAsBytes(_pngIco(png), flush: true);
      location = '${file.path},0';
      final pair = _load(file.path);
      if (pair != null) _paint(pair.$1, pair.$2);
    }
    await _shortcuts(exe, location);
  }

  static Future<Uint8List> _png(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: 256, targetHeight: 256);
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    return bytes!.buffer.asUint8List();
  }

  /// Vista-style icon: one 256px PNG stored inside an .ico.
  static Uint8List _pngIco(Uint8List png) {
    final bd = ByteData(22 + png.length);
    bd.setUint16(2, 1, Endian.little);
    bd.setUint16(4, 1, Endian.little);
    bd.setUint16(10, 1, Endian.little);
    bd.setUint16(12, 32, Endian.little);
    bd.setUint32(14, png.length, Endian.little);
    bd.setUint32(18, 22, Endian.little);
    final bytes = bd.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes);
    bytes.setRange(22, 22 + png.length, png);
    return bytes;
  }

  static (int, int)? _load(String path) {
    final user = DynamicLibrary.open('user32.dll');
    final load = user.lookupFunction<IntPtr Function(IntPtr, Pointer<Utf16>, Uint32, Int32, Int32, Uint32), int Function(int, Pointer<Utf16>, int, int, int, int)>('LoadImageW');
    final metrics = user.lookupFunction<Int32 Function(Int32), int Function(int)>('GetSystemMetrics');
    final p = path.toNativeUtf16();
    try {
      final big = load(0, p, 1, metrics(11), metrics(12), 0x10);
      final small = load(0, p, 1, metrics(49), metrics(50), 0x10);
      if (big == 0 || small == 0) return null;
      return (big, small);
    } finally {
      calloc.free(p);
    }
  }

  static int _extract(String exe) {
    final fn = DynamicLibrary.open('shell32.dll').lookupFunction<IntPtr Function(IntPtr, Pointer<Utf16>, Uint32), int Function(int, Pointer<Utf16>, int)>('ExtractIconW');
    final p = exe.toNativeUtf16();
    try {
      final icon = fn(0, p, 0);
      return icon <= 1 ? 0 : icon;
    } finally {
      calloc.free(p);
    }
  }

  static void _paint(int big, int small) {
    _iconBig = big;
    _iconSmall = small;
    final user = DynamicLibrary.open('user32.dll');
    final enumWindows = user.lookupFunction<Int32 Function(Pointer<NativeFunction<Int32 Function(IntPtr, IntPtr)>>, IntPtr), int Function(Pointer<NativeFunction<Int32 Function(IntPtr, IntPtr)>>, int)>('EnumWindows');
    enumWindows(Pointer.fromFunction<Int32 Function(IntPtr, IntPtr)>(_enumWindows, 1), 0);
  }

  static Future<void> _shortcuts(String exe, String icon) async {
    final script = r'''
$exe = $env:SHARROW_EXE
$icon = $env:SHARROW_ICON
$shell = New-Object -ComObject WScript.Shell
$dirs = @(
  [Environment]::GetFolderPath('Desktop'),
  [Environment]::GetFolderPath('Programs'),
  "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar",
  "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
)
foreach ($d in $dirs) {
  if (-not (Test-Path -LiteralPath $d)) { continue }
  Get-ChildItem -LiteralPath $d -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
    $s = $shell.CreateShortcut($_.FullName)
    if ($s.TargetPath -eq $exe) { $s.IconLocation = $icon; $s.Save() }
  }
}
''';
    try {
      final result = await Process.run(
        'powershell.exe',
        ['-NoProfile', '-NonInteractive', '-WindowStyle', 'Hidden', '-Command', script],
        environment: {...Platform.environment, 'SHARROW_EXE': exe, 'SHARROW_ICON': icon},
      );
      if (result.exitCode != 0) log.w('Shortcut icons were not updated: ${result.stderr}');
    } catch (e) {
      log.w('Shortcut icons were not updated: $e');
    }
    final notify = DynamicLibrary.open('shell32.dll').lookupFunction<Void Function(Int32, Uint32, Pointer<Void>, Pointer<Void>), void Function(int, int, Pointer<Void>, Pointer<Void>)>('SHChangeNotify');
    notify(0x08000000, 0, nullptr, nullptr);
  }
}

int _enumWindows(int hwnd, int lParam) {
  final user = DynamicLibrary.open('user32.dll');
  final pidOf = user.lookupFunction<Uint32 Function(IntPtr, Pointer<Uint32>), int Function(int, Pointer<Uint32>)>('GetWindowThreadProcessId');
  final owner = user.lookupFunction<IntPtr Function(IntPtr, Uint32), int Function(int, int)>('GetWindow');
  final send = user.lookupFunction<IntPtr Function(IntPtr, Uint32, IntPtr, IntPtr), int Function(int, int, int, int)>('SendMessageW');
  final mine = DynamicLibrary.open('kernel32.dll').lookupFunction<Uint32 Function(), int Function()>('GetCurrentProcessId');
  final pid = calloc<Uint32>();
  try {
    pidOf(hwnd, pid);
    if (pid.value != mine() || owner(hwnd, 4) != 0) return 1;
    send(hwnd, 0x0080, 1, _iconBig);
    send(hwnd, 0x0080, 0, _iconSmall);
    return 1;
  } finally {
    calloc.free(pid);
  }
}
