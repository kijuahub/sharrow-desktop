// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:io';

import 'package:tray_manager/legacy.dart';

import '../../core/l10n.dart';
import '../logs/log_service.dart';

class TrayServer {
  const TrayServer(this.id, this.name, this.selected);

  final String id;
  final String name;
  final bool selected;
}

class TrayState {
  const TrayState({
    required this.connected,
    required this.busy,
    required this.mode,
    required this.serverName,
    required this.servers,
  });

  final bool connected;
  final bool busy;
  final String mode;
  final String? serverName;
  final List<TrayServer> servers;
}

/// System tray icon with a compact control menu.
class TrayService with TrayListener {
  TrayService({
    required this.onShow,
    required this.onToggle,
    required this.onMode,
    required this.onServer,
    required this.onQuit,
    required this.clickAction,
  });

  final void Function() onShow;
  final void Function() onToggle;
  final void Function(String mode) onMode;
  final void Function(String id) onServer;
  final void Function() onQuit;
  final String Function() clickAction;

  bool _active = false;
  String? _brandAsset;
  String? _shownAsset;
  Timer? _debounce;
  TrayState? _pending;

  Future<void> init() async {
    if (_active) return;
    try {
      trayManager.addListener(this);
      await _setIcon(false);
      await trayManager.setToolTip('Sharrow');
      _active = true;
    } catch (e) {
      log.w('Tray unavailable: $e');
    }
  }

  /// Null keeps the default tray glyph, which still changes while connected.
  Future<void> useBrand(String? asset) async {
    if (_brandAsset == asset) return;
    _brandAsset = asset;
    _shownAsset = null;
    if (_active) await _setIcon(_pending?.connected ?? false);
  }

  Future<void> _setIcon(bool connected) async {
    final asset = _brandAsset ??
        (Platform.isMacOS
            ? (connected ? 'assets/icons/tray_light_connected.png' : 'assets/icons/tray_light.png')
            : (connected ? 'assets/icons/tray_app_connected.png' : 'assets/icons/tray_app.png'));
    if (_shownAsset == asset) return;
    _shownAsset = asset;
    await trayManager.setIcon(asset, isTemplate: Platform.isMacOS && _brandAsset == null && !connected);
  }

  void update(TrayState state) {
    if (!_active) return;
    _pending = state;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () => _apply(_pending!));
  }

  Future<void> _apply(TrayState s) async {
    try {
      await _setIcon(s.connected);
      final status = s.busy
          ? tr('Подключение…', 'Connecting…')
          : s.connected
              ? tr('Подключено', 'Connected')
              : tr('Отключено', 'Disconnected');
      await trayManager.setToolTip('Sharrow — $status${s.serverName != null ? '\n${s.serverName}' : ''}');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'status', label: '$status${s.serverName != null ? ' · ${s.serverName}' : ''}', disabled: true),
        MenuItem.separator(),
        MenuItem(key: 'toggle', label: s.connected ? tr('Отключить', 'Disconnect') : tr('Подключить', 'Connect'), disabled: s.busy),
        MenuItem.submenu(
          key: 'mode',
          label: tr('Режим', 'Mode'),
          submenu: Menu(items: [
            MenuItem.checkbox(key: 'mode:proxy', label: 'Proxy', checked: s.mode == 'proxy'),
            MenuItem.checkbox(key: 'mode:tun', label: 'TUN', checked: s.mode == 'tun'),
          ]),
        ),
        if (s.servers.isNotEmpty)
          MenuItem.submenu(
            key: 'servers',
            label: tr('Серверы', 'Servers'),
            submenu: Menu(items: [
              for (final srv in s.servers.take(25)) MenuItem.checkbox(key: 'server:${srv.id}', label: srv.name, checked: srv.selected),
            ]),
          ),
        MenuItem.separator(),
        MenuItem(key: 'show', label: tr('Открыть Sharrow', 'Open Sharrow')),
        MenuItem(key: 'quit', label: tr('Выход', 'Quit')),
      ]));
    } catch (e) {
      log.w('Tray update failed: $e');
    }
  }

  @override
  void onTrayIconMouseDown() {
    if (clickAction() == 'toggle') {
      onToggle();
    } else {
      onShow();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key ?? '';
    if (key == 'toggle') onToggle();
    if (key == 'show') onShow();
    if (key == 'quit') onQuit();
    if (key.startsWith('mode:')) onMode(key.substring(5));
    if (key.startsWith('server:')) onServer(key.substring(7));
  }

  Future<void> dispose() async {
    if (!_active) return;
    _active = false;
    trayManager.removeListener(this);
    try {
      await trayManager.destroy();
    } catch (_) {}
  }
}
