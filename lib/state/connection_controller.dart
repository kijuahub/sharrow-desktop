import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/l10n.dart';
import '../core/platform.dart';
import '../data/models/server.dart';
import '../data/models/settings.dart';
import '../data/storage/paths.dart';
import '../modules/logs/log_service.dart';
import '../modules/system/system_proxy.dart';
import '../modules/xray/config_builder.dart';
import '../modules/xray/stats_service.dart';
import '../modules/xray/vpn_core.dart';
import 'settings_controller.dart';
import 'subscriptions_controller.dart';

enum ConnStatus { disconnected, connecting, connected, disconnecting }

class ConnectionController extends ChangeNotifier {
  ConnectionController({
    required this.settings,
    required this.subs,
    required this.ensureCore,
    required this.notify,
  }) {
    core.onCrash = _onCrash;
  }

  final SettingsController settings;
  final SubscriptionsController subs;

  /// Installs the core if missing (desktop); throws on failure.
  final Future<void> Function(TunnelMode mode) ensureCore;
  final void Function(String title, String body, SettingKey<bool> kind) notify;

  final VpnCore core = VpnCore.create();
  final stats = StatsService();

  ConnStatus status = ConnStatus.disconnected;
  TunnelMode? activeMode;
  ServerProfile? activeServer;
  DateTime? connectedAt;
  String? error;
  CoreErrorKind? errorKind;
  int? realDelay;
  int _attempts = 0;
  int _session = 0;

  bool get isConnected => status == ConnStatus.connected;
  bool get isBusy => status == ConnStatus.connecting || status == ConnStatus.disconnecting;

  TunnelMode get preferredMode => settings.get(K.lastMode) == 'tun' ? TunnelMode.tun : TunnelMode.proxy;

  /// 'off' | 'proxy' | 'tun' as shown by the mode switch.
  String get modeLabel {
    if (status == ConnStatus.disconnected || status == ConnStatus.disconnecting) return 'off';
    return (activeMode ?? preferredMode).name;
  }

  void _set(ConnStatus s) {
    status = s;
    notifyListeners();
  }

  Future<void> setMode(String mode) async {
    if (mode == 'off') return disconnect();
    final m = mode == 'tun' ? TunnelMode.tun : TunnelMode.proxy;
    settings.set(K.lastMode, m.name);
    await connect(mode: m);
  }

  Future<void> toggle() => isConnected || status == ConnStatus.connecting ? disconnect() : connect();

  Future<void> connect({TunnelMode? mode, bool fromRetry = false}) async {
    if (status == ConnStatus.disconnecting) return;
    if (status == ConnStatus.connecting && !fromRetry) return;
    final m = mode ?? preferredMode;
    if (!fromRetry) _attempts = 0;
    final session = ++_session;

    if (core.isRunning) await _teardown();
    error = null;
    errorKind = null;
    realDelay = null;
    _set(ConnStatus.connecting);

    try {
      ServerProfile? server = subs.selectedServer;
      if (settings.get(K.autoSelectFastest) && !fromRetry) {
        server = await subs.pickFastest() ?? server;
      }
      if (server == null) {
        throw CoreException(CoreErrorKind.startFailed, tr('Добавьте подписку или ключ, чтобы подключиться', 'Add a subscription or key to connect'));
      }
      if (Plat.isDesktop) {
        await ensureCore(m);
      } else if (!await core.isInstalled()) {
        throw CoreException(CoreErrorKind.missing, tr('Ядро Xray не встроено в сборку', 'Xray core is not bundled in this build'));
      }
      if (session != _session) return;

      final s = settings.snapshot;
      final profile = subs.routingFor(server);
      if (profile != null && Plat.isDesktop) await profile.ensureGeo(AppPaths.core.path);
      if (session != _session) return;
      final config = XrayConfigBuilder.build(server, s, mode: m, mobile: Plat.isMobile, profile: profile);
      await core.start(
        config,
        mode: m,
        timeout: Duration(seconds: s.get(K.connectTimeout)),
        readyPort: s.get(K.socksPort),
      );
      if (session != _session) return;

      if (m == TunnelMode.proxy && Plat.isDesktop && s.get(K.setSystemProxy)) {
        final ok = await SystemProxy.enable(httpPort: s.get(K.httpPort), socksPort: s.get(K.socksPort), bypass: s.get(K.proxyBypass));
        settings.set(K.proxyApplied, ok);
      }

      activeServer = server;
      activeMode = m;
      connectedAt = DateTime.now();
      _attempts = 0;
      settings.set(K.wasConnected, true);
      settings.set(K.lastMode, m.name);
      _set(ConnStatus.connected);
      log.i('Connected: ${server.name} [${m.name}]');
      stats.start(s.get(K.metricsPort));
      notify(tr('Подключено', 'Connected'), '${server.name} · ${m == TunnelMode.tun ? 'TUN' : 'Proxy'}', K.notifyConnect);
      if (s.get(K.realDelay) && s.get(K.httpInbound)) unawaited(measureDelay());
    } on CoreException catch (e) {
      if (session != _session) return;
      await _fail(e.message, e.kind);
    } on ConfigException catch (e) {
      if (session != _session) return;
      await _fail(tr('Ошибка конфигурации: ${e.message}', 'Configuration error: ${e.message}'), CoreErrorKind.startFailed);
    } catch (e) {
      if (session != _session) return;
      await _fail('$e', CoreErrorKind.startFailed);
    }
  }

  Future<void> _fail(String message, CoreErrorKind kind) async {
    await _teardown();
    error = message;
    errorKind = kind;
    activeMode = null;
    connectedAt = null;
    _set(ConnStatus.disconnected);
    log.e('Connection failed: $message');
    if (kind != CoreErrorKind.permission) notify(tr('Ошибка подключения', 'Connection error'), message, K.notifyError);
  }

  Future<void> measureDelay() async {
    if (!isConnected) return;
    final s = settings.snapshot;
    final d = await subs.ping.realDelay(s.get(K.pingTestUrl), s.get(K.httpPort), Duration(milliseconds: s.get(K.pingTimeout) * 2));
    if (!isConnected) return;
    realDelay = d;
    if (activeServer != null && d > 0) {
      activeServer!.ping = d;
      activeServer!.pingAt = DateTime.now();
    }
    notifyListeners();
  }

  Future<void> _teardown() async {
    stats.stop();
    if (settings.get(K.proxyApplied)) {
      await SystemProxy.disable();
      settings.set(K.proxyApplied, false);
    }
    await core.stop();
  }

  Future<void> disconnect({bool user = true}) async {
    _session++;
    if (status == ConnStatus.disconnected && !core.isRunning) return;
    final wasConnected = isConnected;
    _set(ConnStatus.disconnecting);
    await _teardown();
    activeMode = null;
    connectedAt = null;
    realDelay = null;
    error = null;
    if (user) settings.set(K.wasConnected, false);
    _set(ConnStatus.disconnected);
    if (wasConnected && user) notify(tr('Отключено', 'Disconnected'), activeServer?.name ?? 'Sharrow', K.notifyDisconnect);
  }

  /// Restarts the tunnel (server change, network change, settings change).
  Future<void> restart() async {
    if (!isConnected) return;
    await connect(mode: activeMode);
  }

  void _onCrash(String reason) {
    if (status != ConnStatus.connected) return;
    final mode = activeMode;
    stats.stop();
    if (settings.get(K.reconnect) && _attempts < settings.get(K.reconnectAttempts)) {
      _attempts++;
      final delay = Duration(seconds: _attempts * 2);
      log.w('Reconnecting in ${delay.inSeconds}s (attempt $_attempts)');
      _set(ConnStatus.connecting);
      Future<void>.delayed(delay, () {
        if (status == ConnStatus.connecting) connect(mode: mode, fromRetry: true);
      });
    } else {
      unawaited(_fail(reason, CoreErrorKind.startFailed));
    }
  }

  void clearError() {
    error = null;
    errorKind = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stats.dispose();
    super.dispose();
  }
}
