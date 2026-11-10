import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Minimal WinAPI bindings so Windows integration never spawns console processes.
abstract final class Win32 {
  static const _hkeyCurrentUser = -2147483647; // (HKEY)(LONG)0x80000001
  static const _regSz = 1;
  static const _regDword = 4;

  static bool isUserAnAdmin() {
    try {
      final fn = DynamicLibrary.open('shell32.dll').lookupFunction<Int32 Function(), int Function()>('IsUserAnAdmin');
      return fn() != 0;
    } catch (_) {
      return false;
    }
  }

  static int _setValue(String subKey, String name, int type, Pointer<Void> data, int size) {
    final fn = DynamicLibrary.open('advapi32.dll').lookupFunction<
        Int32 Function(IntPtr, Pointer<Utf16>, Pointer<Utf16>, Uint32, Pointer<Void>, Uint32),
        int Function(int, Pointer<Utf16>, Pointer<Utf16>, int, Pointer<Void>, int)>('RegSetKeyValueW');
    final k = subKey.toNativeUtf16();
    final n = name.toNativeUtf16();
    try {
      return fn(_hkeyCurrentUser, k, n, type, data, size);
    } finally {
      calloc.free(k);
      calloc.free(n);
    }
  }

  static bool regSetString(String subKey, String name, String value) {
    final v = value.toNativeUtf16();
    try {
      return _setValue(subKey, name, _regSz, v.cast(), (value.length + 1) * 2) == 0;
    } finally {
      calloc.free(v);
    }
  }

  static bool regSetDword(String subKey, String name, int value) {
    final p = calloc<Uint32>()..value = value;
    try {
      return _setValue(subKey, name, _regDword, p.cast(), 4) == 0;
    } finally {
      calloc.free(p);
    }
  }

  /// Notifies WinINet consumers (browsers, apps) that proxy settings changed.
  static void refreshInternetSettings() {
    final fn = DynamicLibrary.open('wininet.dll').lookupFunction<Int32 Function(IntPtr, Uint32, Pointer<Void>, Uint32),
        int Function(int, int, Pointer<Void>, int)>('InternetSetOptionW');
    const settingsChanged = 39, refresh = 37;
    fn(0, settingsChanged, nullptr, 0);
    fn(0, refresh, nullptr, 0);
  }

  /// ShellExecute with the "runas" verb (UAC prompt). Returns false if declined.
  static bool runAsAdmin(String file, String params) {
    final fn = DynamicLibrary.open('shell32.dll').lookupFunction<
        IntPtr Function(IntPtr, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Int32),
        int Function(int, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>, int)>('ShellExecuteW');
    final verb = 'runas'.toNativeUtf16();
    final f = file.toNativeUtf16();
    final p = params.toNativeUtf16();
    try {
      return fn(0, verb, f, p, nullptr, 1) > 32;
    } finally {
      calloc.free(verb);
      calloc.free(f);
      calloc.free(p);
    }
  }
}
