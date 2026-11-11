import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/l10n.dart';
import '../logs/log_service.dart';
import 'config_builder.dart';
import 'vpn_core.dart';

/// Android VpnService / iOS NetworkExtension bridge. The native side owns the
/// TUN device and hands its fd to Xray via XRAY_TUN_FD.
class MobileVpnCore extends VpnCore {
  MobileVpnCore() {
    _events.receiveBroadcastStream().listen(_onEvent, onError: (_) {});
  }

  static const _channel = MethodChannel('app.sharrow/vpn');
  static const _events = EventChannel('app.sharrow/vpn/events');

  bool _running = false;
  bool _stopping = false;
  Completer<void>? _ready;

  @override
  bool get isRunning => _running;

  void _onEvent(dynamic e) {
    if (e is! Map) return;
    switch (e['type']) {
      case 'log':
        log.core('${e['line']}');
      case 'state':
        final v = e['value'];
        if (v == 'started') {
          _running = true;
          if (_ready?.isCompleted == false) _ready!.complete();
        } else if (v == 'stopped' || v == 'error') {
          final wasRunning = _running;
          _running = false;
          final msg = '${e['message'] ?? v}';
          if (_ready?.isCompleted == false) {
            _ready!.completeError(CoreException(CoreErrorKind.startFailed, msg));
          } else if (wasRunning && !_stopping) {
            onCrash?.call(msg);
          }
        }
    }
  }

  @override
  Future<bool> isInstalled() async {
    try {
      return await _channel.invokeMethod<bool>('isCoreAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> version() async {
    try {
      return await _channel.invokeMethod<String>('version');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> start(
    Map<String, dynamic> config, {
    required TunnelMode mode,
    required Duration timeout,
    required int readyPort,
  }) async {
    final granted = await _channel.invokeMethod<bool>('prepare') ?? false;
    if (!granted) {
      throw CoreException(CoreErrorKind.permission, tr('Разрешение на VPN не выдано', 'VPN permission was denied'));
    }
    _stopping = false;
    _ready = Completer<void>();
    try {
      await _channel.invokeMethod('start', {
        'config': XrayConfigBuilder.encode(config),
        'mode': mode.name,
        'name': 'Sharrow',
      });
    } on PlatformException catch (e) {
      throw CoreException(CoreErrorKind.startFailed, e.message ?? e.code);
    } on MissingPluginException {
      throw CoreException(CoreErrorKind.unsupported, tr('VPN-сервис недоступен на этой платформе', 'VPN service is unavailable on this platform'));
    }
    try {
      await _ready!.future.timeout(timeout);
    } on TimeoutException {
      await stop();
      throw CoreException(CoreErrorKind.timeout, tr('VPN-сервис не ответил вовремя', 'VPN service timed out'));
    }
  }

  @override
  Future<void> openVpnSettings() async {
    try {
      await _channel.invokeMethod('openSettings');
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    _stopping = true;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
    _running = false;
  }
}
