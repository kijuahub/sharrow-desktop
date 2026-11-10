// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/legacy.dart';

import '../core/brand.dart';
import '../core/l10n.dart';
import '../core/platform.dart';
import '../data/models/settings.dart';
import '../data/models/subscription.dart';
import '../data/storage/paths.dart';
import '../modules/logs/log_service.dart';
import '../modules/system/autostart_service.dart';
import '../modules/system/network_watcher.dart';
import '../modules/system/notification_service.dart';
import '../modules/system/privileges.dart';
import '../modules/system/single_instance.dart';
import '../modules/system/system_proxy.dart';
import '../modules/system/tray_service.dart';
import '../modules/xray/config_builder.dart';
import '../modules/xray/core_installer.dart';
import '../modules/xray/core_locator.dart';
import '../modules/xray/vpn_core.dart';
import 'connection_controller.dart';
import 'settings_controller.dart';
import 'subscriptions_controller.dart';

class AppUpdate {
  const AppUpdate(this.version, this.url, this.notes);

  final String version;
  final String url;
  final String notes;
}

class LaunchArgs {
  const LaunchArgs({this.autostart = false, this.tun = false, this.minimized = false});

  factory LaunchArgs.parse(List<String> args) => LaunchArgs(
        autostart: args.contains(AutostartService.flag),
        tun: args.contains('--tun'),
        minimized: args.contains('--minimized'),
      );

  final bool autostart;
  final bool tun;
  final bool minimized;
}

class AppController extends ChangeNotifier with WindowListener {
  AppController(this.args);

  final LaunchArgs args;
  final settings = SettingsController();
  late final SubscriptionsController subs;
  late final ConnectionController conn;
  final installer = CoreInstaller();
  final notifications = NotificationService();
  late final TrayService tray;
  late final NetworkWatcher _network;

  final page = ValueNotifier<String>('servers');
  final visible = ValueNotifier<bool>(true);

  bool ready = false;
  String appVersion = '1.0.0';
  String? coreVersion;
  AppUpdate? update;
  final Set<String> _limitWarned = {};
  final List<Timer> _timers = [];
  bool _quitting = false;

  bool get needsOnboarding => !settings.get(K.onboardingDone) && subs.subs.isEmpty;

  Future<void> init() async {
    settings.load();
    L10n.apply(settings.get(K.language));
    _applyLogSettings();

    subs = SubscriptionsController(settings, proxyProvider: () => conn.isConnected ? '127.0.0.1:${settings.get(K.httpPort)}' : null);
    conn = ConnectionController(
      settings: settings,
      subs: subs,
      ensureCore: _ensureCore,
      notify: _notify,
    );
    tray = TrayService(
      onShow: showWindow,
      onToggle: () => conn.toggle(),
      onMode: (m) => conn.setMode(m),
      onServer: selectServer,
      onQuit: quit,
      clickAction: () => settings.get(K.trayClick),
    );
    _network = NetworkWatcher(_onNetworkChange);

    settings.onChanged = _onSetting;
    subs.onUpdated = _onSubUpdated;
    conn.addListener(_syncTray);
    subs.addListener(_syncTray);

    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    log.i('Sharrow $appVersion on ${Plat.name}');

    await subs.load();
    CoreLocator.customPath = settings.get(K.customCorePath);
    installer.mirror = settings.get(K.githubMirror);

    if (Plat.isDesktop) {
      await conn.core.cleanupOrphans();
      if (settings.get(K.proxyApplied)) {
        log.w('Restoring system proxy left after an unclean exit');
        await SystemProxy.disable();
        settings.set(K.proxyApplied, false);
      }
      windowManager.addListener(this);
      if (settings.get(K.showTray)) await tray.init();
      SingleInstance.listen((a) {
        showWindow();
        if (a.contains('--tun')) conn.setMode('tun');
      });
      await AutostartService.apply(settings.get(K.autostart));
    }
    await notifications.init();

    final last = settings.get(K.lastPage);
    page.value = settings.get(K.startPage) == 'last' && last.isNotEmpty ? last : 'servers';
    page.addListener(() => settings.set(K.lastPage, page.value));

    ready = true;
    notifyListeners();
    _syncTray();
    unawaited(_afterStart());
  }

  Future<void> _afterStart() async {
    coreVersion = await conn.core.version();
    notifyListeners();

    if (args.autostart && settings.get(K.autostartDelay) > 0) {
      await Future<void>.delayed(Duration(seconds: settings.get(K.autostartDelay)));
    }

    final shouldConnect = args.tun ||
        (args.autostart && settings.get(K.autostartConnect)) ||
        settings.get(K.autoConnect) ||
        (settings.get(K.restoreConnection) && settings.get(K.wasConnected));
    if (shouldConnect && subs.selectedServer != null) {
      final mode = args.tun
          ? 'tun'
          : (settings.get(K.wasConnected) ? settings.get(K.lastMode) : settings.get(K.defaultMode));
      unawaited(conn.setMode(mode));
    }

    if (settings.get(K.subUpdateOnStart)) {
      unawaited(subs.updateAll(onlyDue: false));
    } else if (settings.get(K.pingOnStart) && subs.selectedSub != null) {
      unawaited(subs.pingSub(subs.selectedSub!.id));
    }

    _timers.add(Timer.periodic(const Duration(minutes: 10), (_) {
      if (settings.get(K.subAutoUpdate)) subs.updateAll(onlyDue: true);
    }));
    _schedulePing();
    _timers.add(Timer.periodic(const Duration(hours: 6), (_) => _maintenance()));
    unawaited(_maintenance());
    if (settings.get(K.watchNetwork)) _network.start();
  }

  Timer? _pingTimer;

  void _schedulePing() {
    _pingTimer?.cancel();
    final minutes = settings.get(K.pingInterval);
    if (minutes <= 0) return;
    _pingTimer = Timer.periodic(Duration(minutes: minutes), (_) {
      final sub = subs.selectedSub;
      if (sub != null && visible.value) subs.pingSub(sub.id);
    });
  }

  Future<void> _maintenance() async {
    if (!Plat.isDesktop) return;
    final installed = await conn.core.isInstalled();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (installed && settings.get(K.autoUpdateGeo) && now - settings.get(K.geoUpdatedAt) > const Duration(days: 7).inMilliseconds) {
      if (settings.get(K.geoUpdatedAt) == 0) {
        settings.set(K.geoUpdatedAt, now);
      } else {
        await updateGeo(silent: true);
      }
    }
    if (installed && settings.get(K.autoUpdateCore) && !conn.isConnected) {
      final latest = await installer.latestXrayVersion();
      if (latest != null && coreVersion != null && latest != coreVersion) await installCore(silent: true);
    }
    if (settings.get(K.checkAppUpdates) && now - settings.get(K.lastUpdateCheck) > const Duration(hours: 12).inMilliseconds) {
      await checkAppUpdate();
    }
  }

  // ---------------- core / updates ----------------

  Future<void> _ensureCore(TunnelMode mode) async {
    while (installer.busy) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (!await conn.core.isInstalled()) {
      installer.httpProxy = null;
      coreVersion = await installer.installXray();
      settings.set(K.geoUpdatedAt, DateTime.now().millisecondsSinceEpoch);
      notifyListeners();
    }
    if (mode == TunnelMode.tun) {
      try {
        await installer.ensureWintun();
      } catch (e) {
        throw CoreException(CoreErrorKind.missing, tr('Не удалось загрузить драйвер Wintun: $e', 'Failed to download the Wintun driver: $e'));
      }
    }
  }

  Future<String?> installCore({bool silent = false}) async {
    final wasConnected = conn.isConnected;
    final mode = conn.activeMode;
    try {
      installer.httpProxy = wasConnected ? '127.0.0.1:${settings.get(K.httpPort)}' : null;
      if (wasConnected) await conn.disconnect(user: false);
      installer.httpProxy = null;
      coreVersion = await installer.installXray();
      notifyListeners();
      return null;
    } catch (e) {
      return silent ? null : '$e';
    } finally {
      if (wasConnected) unawaited(conn.connect(mode: mode));
    }
  }

  Future<String?> updateGeo({bool silent = false}) async {
    try {
      installer.httpProxy = conn.isConnected && conn.activeMode == TunnelMode.proxy ? '127.0.0.1:${settings.get(K.httpPort)}' : null;
      await installer.updateGeo(settings.get(K.geoSource));
      settings.set(K.geoUpdatedAt, DateTime.now().millisecondsSinceEpoch);
      notifyListeners();
      if (conn.isConnected) unawaited(conn.restart());
      return null;
    } catch (e) {
      return silent ? null : '$e';
    }
  }

  static int _cmpVersion(String a, String b) {
    List<int> p(String v) => v.split(RegExp(r'[.+-]')).map((e) => int.tryParse(e) ?? 0).toList();
    final x = p(a), y = p(b);
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }

  /// Returns null when up to date, otherwise an [AppUpdate]. Throws on network errors when [throwErrors].
  Future<AppUpdate?> checkAppUpdate({bool throwErrors = false}) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse(Brand.updateFeedUrl));
      final res = await req.close().timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
      final data = jsonDecode(await res.transform(utf8.decoder).join()) as Map;
      settings.set(K.lastUpdateCheck, DateTime.now().millisecondsSinceEpoch);
      final channel = '${data['channel'] ?? 'stable'}';
      if (settings.get(K.updateChannel) == 'stable' && channel != 'stable') return null;
      final v = '${data['version'] ?? ''}';
      if (v.isNotEmpty && _cmpVersion(v, appVersion) > 0) {
        update = AppUpdate(v, '${data['url'] ?? Brand.website}', '${data['notes'] ?? ''}');
        notifyListeners();
        _notify(tr('Доступно обновление', 'Update available'), 'Sharrow $v', K.notifications);
        return update;
      }
      return null;
    } catch (e) {
      log.w('Update check failed: $e');
      if (throwErrors) rethrow;
      return null;
    } finally {
      client.close(force: true);
    }
  }

  // ---------------- actions ----------------

  Future<void> selectServer(String id) async {
    final changed = subs.selectedServer?.id != id;
    subs.selectServer(id);
    if (changed && (conn.isConnected || conn.status == ConnStatus.connecting)) {
      await conn.connect(mode: conn.activeMode ?? conn.preferredMode);
    }
  }

  void completeOnboarding() {
    settings.set(K.onboardingDone, true);
    notifyListeners();
  }

  Future<void> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      log.w('Cannot open $url: $e');
    }
  }

  Future<void> openFolder(Directory dir) async {
    if (!Plat.isDesktop) return;
    final cmd = Platform.isWindows ? 'explorer' : (Platform.isMacOS ? 'open' : 'xdg-open');
    await Process.start(cmd, [dir.path], mode: ProcessStartMode.detached);
  }

  Future<bool> relaunchAsAdmin() async {
    await conn.disconnect(user: false);
    settings.flush();
    await subs.save();
    await SingleInstance.release();
    final ok = await Privileges.relaunchElevated(['--tun']);
    if (ok) {
      await _shutdown();
      exit(0);
    }
    await SingleInstance.acquire(const []);
    return false;
  }

  String previewConfig() {
    final server = subs.selectedServer;
    if (server == null) return '{}';
    final profile = subs.routingFor(server)?..useCachedGeo(AppPaths.core.path);
    final cfg = XrayConfigBuilder.build(server, settings.snapshot, mode: conn.activeMode ?? conn.preferredMode, mobile: Plat.isMobile, profile: profile);
    var text = XrayConfigBuilder.encode(cfg, pretty: true);
    if (settings.get(K.maskAddresses)) {
      text = text
          .replaceAll(RegExp(r'"(id|password|pass|auth|secretKey|publicKey|preSharedKey)":\s*"[^"]*"'), r'"$1": "••••••"')
          .replaceAllMapped(RegExp(r'"(address|endpoint)":\s*"([^"]*)"'), (m) => '"${m[1]}": "${_maskHost(m[2]!)}"');
    }
    return text;
  }

  static String _maskHost(String h) => h.length <= 4 ? '••••' : '${h.substring(0, 2)}••••${h.substring(h.length - 2)}';

  Future<void> wipeAll() async {
    await conn.disconnect();
    await subs.wipe();
    settings.reset();
    settings.set(K.onboardingDone, false);
    log.clear();
    notifyListeners();
  }

  // ---------------- reactions ----------------

  void _applyLogSettings() {
    log.maxLines = settings.get(K.logMaxLines);
    log.maskAddresses = settings.get(K.maskAddresses);
    log.minAppLevel = switch (settings.get(K.appLogLevel)) {
      'debug' => LogLevel.debug,
      'warning' => LogLevel.warning,
      'error' => LogLevel.error,
      _ => LogLevel.info,
    };
    unawaited(log.setFileLogging(settings.get(K.logToFile), keepDays: settings.get(K.logKeepDays)));
  }

  static const _restartKeys = {
    'routingMode', 'bypassLan', 'bypassPreset', 'blockAds', 'blockQuic', 'domainStrategy', 'directList', 'proxyList', 'blockList',
    'remoteDns', 'directDns', 'dnsStrategy', 'dnsCache', 'fakeDns', 'dnsHosts', 'tunMtu', 'tunIpv6', 'tunStrict', 'tunDnsHijack',
    'tunAutoRoute', 'tunGateway', 'tunName', 'socksPort', 'httpPort', 'httpInbound', 'allowLan', 'proxyAuth', 'proxyUser', 'proxyPass',
    'logLevel', 'accessLog', 'sniffing', 'sniffRouteOnly', 'mux', 'muxConcurrency', 'fragment', 'fragmentPackets', 'fragmentLength',
    'fragmentInterval', 'preferIpv6', 'tcpFastOpen', 'keepAlive', 'bindInterface', 'configOverride', 'metricsPort', 'setSystemProxy', 'proxyBypass',
  };

  Timer? _restartDebounce;

  void _onSetting(String id) {
    switch (id) {
      case 'language':
        L10n.apply(settings.get(K.language));
        notifyListeners();
        _syncTray();
      case 'logMaxLines' || 'maskAddresses' || 'appLogLevel' || 'logToFile' || 'logKeepDays':
        _applyLogSettings();
      case 'autostart':
        unawaited(AutostartService.apply(settings.get(K.autostart)));
      case 'showTray':
        settings.get(K.showTray) ? tray.init().then((_) => _syncTray()) : tray.dispose();
      case 'customCorePath':
        CoreLocator.customPath = settings.get(K.customCorePath);
        conn.core.version().then((v) {
          coreVersion = v;
          notifyListeners();
        });
      case 'githubMirror':
        installer.mirror = settings.get(K.githubMirror);
      case 'pingInterval':
        _schedulePing();
      case 'watchNetwork':
        settings.get(K.watchNetwork) ? _network.start() : _network.stop();
      case '*':
        L10n.apply(settings.get(K.language));
        _applyLogSettings();
        notifyListeners();
    }
    if ((_restartKeys.contains(id) || id == '*') && conn.isConnected) {
      _restartDebounce?.cancel();
      _restartDebounce = Timer(const Duration(milliseconds: 1200), () => conn.restart());
    }
  }

  void _onNetworkChange() {
    if (!conn.isConnected || conn.activeMode != TunnelMode.tun) return;
    log.i('Network changed — restarting tunnel');
    unawaited(conn.restart());
  }

  void _onSubUpdated(Subscription sub, Object? error) {
    if (error != null) {
      _notify(tr('Не удалось обновить подписку', 'Subscription update failed'), '${sub.name}: $error', K.notifyError);
      return;
    }
    _notify(tr('Подписка обновлена', 'Subscription updated'), tr('${sub.name}: ${sub.servers.length} серверов', '${sub.name}: ${sub.servers.length} servers'),
        K.notifySubUpdate);
    final frac = sub.usedFraction;
    final expiresSoon = sub.expire != null && sub.expire!.difference(DateTime.now()).inDays < 3;
    if (((frac != null && frac > 0.9) || expiresSoon) && _limitWarned.add(sub.id)) {
      _notify(
        tr('Подписка заканчивается', 'Subscription is running out'),
        expiresSoon ? tr('${sub.name}: срок действия скоро истечёт', '${sub.name}: expires soon') : tr('${sub.name}: израсходовано более 90% трафика', '${sub.name}: over 90% of traffic used'),
        K.notifyLimits,
      );
    }
  }

  void _notify(String title, String body, SettingKey<bool> kind) {
    if (!settings.get(K.notifications) || !settings.get(kind)) return;
    unawaited(notifications.show(title, body));
  }

  void _syncTray() {
    if (!Plat.isDesktop || !ready) return;
    final selected = subs.selectedServer;
    tray.update(TrayState(
      connected: conn.isConnected,
      busy: conn.isBusy,
      mode: conn.activeMode?.name ?? conn.preferredMode.name,
      serverName: selected?.name,
      servers: [
        for (final s in subs.selectedSub?.servers ?? const []) TrayServer(s.id, s.name, s.id == selected?.id),
      ],
    ));
  }

  // ---------------- window ----------------

  Future<void> showWindow() async {
    if (!Plat.isDesktop) return;
    await windowManager.show();
    await windowManager.focus();
    visible.value = true;
  }

  @override
  void onWindowClose() async {
    if (_quitting) return;
    if (settings.get(K.closeToTray) && settings.get(K.showTray)) {
      await windowManager.hide();
      visible.value = false;
      conn.stats.pause();
    } else {
      await quit();
    }
  }

  @override
  void onWindowMinimize() {
    visible.value = false;
    conn.stats.pause();
  }

  @override
  void onWindowRestore() => _onShown();

  @override
  void onWindowFocus() => _onShown();

  void _onShown() {
    if (visible.value) return;
    visible.value = true;
    if (conn.isConnected) conn.stats.resume(settings.get(K.metricsPort));
  }

  Future<void> _shutdown() async {
    for (final t in _timers) {
      t.cancel();
    }
    _pingTimer?.cancel();
    _network.stop();
    await conn.disconnect(user: false);
    settings.flush();
    await subs.save();
    await tray.dispose();
    await log.close();
  }

  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    await _shutdown();
    if (Plat.isDesktop) {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    } else {
      await SystemNavigator.pop();
    }
  }

  Future<void> copy(String text) => Clipboard.setData(ClipboardData(text: text));

  String get dataDir => AppPaths.root.path;
}
