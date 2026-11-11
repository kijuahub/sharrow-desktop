import 'package:flutter/foundation.dart';


@immutable
class SettingKey<T> {
  const SettingKey(this.id, this.def);

  final String id;
  final T def;
}

/// Every persisted setting with its default value.
abstract final class K {
  // Personalization
  static const language = SettingKey<String>('language', 'system');
  static const startPage = SettingKey<String>('startPage', 'servers');
  static const showFlags = SettingKey<bool>('showFlags', true);
  static const compactList = SettingKey<bool>('compactList', false);
  static const showSpeed = SettingKey<bool>('showSpeed', true);
  static const confirmDisconnect = SettingKey<bool>('confirmDisconnect', false);

  // Appearance
  static const themeMode = SettingKey<String>('themeMode', 'dark');
  static const accent = SettingKey<int>('accent', 0xFF5B8CFF);
  static const appIcon = SettingKey<String>('appIcon', 'default');
  static const connectStyle = SettingKey<String>('connectStyle', 'standard');
  static const planetBehindButton = SettingKey<bool>('planetBehindButton', false);
  static const font = SettingKey<String>('font', 'inter');
  static const animations = SettingKey<bool>('animations', true);

  /// Home screen art: `planet`, `space` or `image`.
  static const homeScene = SettingKey<String>('homeScene', 'planet');
  static const homeImage = SettingKey<String>('homeImage', '');
  static const globe = SettingKey<bool>('globe', true);
  static const globeRotation = SettingKey<bool>('globeRotation', true);
  static const globeSpeed = SettingKey<double>('globeSpeed', 1.0);
  static const lowFps = SettingKey<bool>('lowFps', false);
  static const glass = SettingKey<bool>('glass', true);
  static const textScale = SettingKey<double>('textScale', 1.0);
  static const sidebarExpanded = SettingKey<bool>('sidebarExpanded', false);

  // Connection
  static const defaultMode = SettingKey<String>('defaultMode', 'proxy');
  static const autoConnect = SettingKey<bool>('autoConnect', false);
  static const restoreConnection = SettingKey<bool>('restoreConnection', true);
  static const reconnect = SettingKey<bool>('reconnect', true);
  static const reconnectAttempts = SettingKey<int>('reconnectAttempts', 5);
  static const connectTimeout = SettingKey<int>('connectTimeout', 12);

  // Servers
  static const autoSelectFastest = SettingKey<bool>('autoSelectFastest', false);
  static const sortBy = SettingKey<String>('sortBy', 'none');
  static const hideUnreachable = SettingKey<bool>('hideUnreachable', false);
  static const showProtocol = SettingKey<bool>('showProtocol', true);
  static const pingAfterUpdate = SettingKey<bool>('pingAfterUpdate', true);

  // Routing
  static const routingMode = SettingKey<String>('routingMode', 'rules');
  static const bypassLan = SettingKey<bool>('bypassLan', true);
  static const bypassPreset = SettingKey<String>('bypassPreset', 'none');
  static const blockAds = SettingKey<bool>('blockAds', false);
  static const blockQuic = SettingKey<bool>('blockQuic', false);
  static const domainStrategy = SettingKey<String>('domainStrategy', 'IPIfNonMatch');
  static const directList = SettingKey<List<String>>('directList', []);
  static const proxyList = SettingKey<List<String>>('proxyList', []);
  static const blockList = SettingKey<List<String>>('blockList', []);

  /// Per-application routing (desktop): 'off', 'proxy' (only listed apps via VPN),
  /// 'direct' (listed apps bypass VPN).
  static const appRouting = SettingKey<String>('appRouting', 'off');
  static const appList = SettingKey<List<String>>('appList', []);
  static const telegramViaProxy = SettingKey<bool>('telegramViaProxy', true);

  // DNS
  static const remoteDns = SettingKey<String>('remoteDns', 'https://1.1.1.1/dns-query');
  static const directDns = SettingKey<String>('directDns', '8.8.8.8');
  static const dnsStrategy = SettingKey<String>('dnsStrategy', 'UseIPv4');
  static const dnsCache = SettingKey<bool>('dnsCache', true);
  static const fakeDns = SettingKey<bool>('fakeDns', false);
  static const dnsHosts = SettingKey<List<String>>('dnsHosts', []);

  // Ping
  static const pingTimeout = SettingKey<int>('pingTimeout', 3000);
  static const pingConcurrency = SettingKey<int>('pingConcurrency', 16);
  static const pingOnStart = SettingKey<bool>('pingOnStart', true);
  static const pingInterval = SettingKey<int>('pingInterval', 0);
  static const pingTestUrl = SettingKey<String>('pingTestUrl', 'https://www.gstatic.com/generate_204');

  /// `tcp`, `icmp`, `http-get` or `http-head`.
  static const pingMethod = SettingKey<String>('pingMethod', 'tcp');
  static const realDelay = SettingKey<bool>('realDelay', true);

  // TUN
  static const tunName = SettingKey<String>('tunName', 'sharrow0');
  static const tunMtu = SettingKey<int>('tunMtu', 1500);
  static const tunIpv6 = SettingKey<bool>('tunIpv6', false);
  static const tunStrict = SettingKey<bool>('tunStrict', true);
  static const tunDnsHijack = SettingKey<bool>('tunDnsHijack', true);
  static const tunAutoRoute = SettingKey<bool>('tunAutoRoute', true);
  static const tunGateway = SettingKey<String>('tunGateway', '172.19.0.1/30');

  // Proxy
  static const socksPort = SettingKey<int>('socksPort', 10808);
  static const httpPort = SettingKey<int>('httpPort', 10809);
  static const httpInbound = SettingKey<bool>('httpInbound', true);
  static const allowLan = SettingKey<bool>('allowLan', false);
  static const setSystemProxy = SettingKey<bool>('setSystemProxy', true);
  static const proxyBypass = SettingKey<String>(
      'proxyBypass', 'localhost;127.*;10.*;172.16.*;172.17.*;172.18.*;172.19.*;172.2*;172.30.*;172.31.*;192.168.*;<local>');
  static const proxyAuth = SettingKey<bool>('proxyAuth', false);
  static const proxyUser = SettingKey<String>('proxyUser', 'sharrow');
  static const proxyPass = SettingKey<String>('proxyPass', '');

  // Xray
  static const logLevel = SettingKey<String>('logLevel', 'warning');
  static const accessLog = SettingKey<bool>('accessLog', false);
  static const sniffing = SettingKey<bool>('sniffing', true);
  static const sniffRouteOnly = SettingKey<bool>('sniffRouteOnly', false);
  static const mux = SettingKey<bool>('mux', false);
  static const muxConcurrency = SettingKey<int>('muxConcurrency', 8);
  static const fragment = SettingKey<bool>('fragment', false);
  static const fragmentPackets = SettingKey<String>('fragmentPackets', 'tlshello');
  static const fragmentLength = SettingKey<String>('fragmentLength', '100-200');
  static const fragmentInterval = SettingKey<String>('fragmentInterval', '10-20');
  static const customCorePath = SettingKey<String>('customCorePath', '');

  // Subscriptions
  static const subAutoUpdate = SettingKey<bool>('subAutoUpdate', true);
  static const subInterval = SettingKey<int>('subInterval', 12);
  static const subRespectProvider = SettingKey<bool>('subRespectProvider', true);
  static const subUpdateOnStart = SettingKey<bool>('subUpdateOnStart', true);
  /// Empty = derived from [subFormat].
  static const subUserAgent = SettingKey<String>('subUserAgent', '');

  /// 'json' (Xray JSON configs, Happ-compatible) or 'links' (share links).
  static const subFormat = SettingKey<String>('subFormat', 'json');

  /// Apply the routing profile sent by the subscription provider.
  static const subRouting = SettingKey<bool>('subRouting', true);
  static const subViaProxy = SettingKey<bool>('subViaProxy', false);
  static const subTimeout = SettingKey<int>('subTimeout', 20);
  static const sendHwid = SettingKey<bool>('sendHwid', true);

  // Updates
  static const checkAppUpdates = SettingKey<bool>('checkAppUpdates', true);
  static const updateChannel = SettingKey<String>('updateChannel', 'stable');
  static const autoUpdateGeo = SettingKey<bool>('autoUpdateGeo', true);
  static const geoSource = SettingKey<String>('geoSource', 'xray');
  static const autoUpdateCore = SettingKey<bool>('autoUpdateCore', false);
  static const githubMirror = SettingKey<String>('githubMirror', '');

  // Logs
  static const logToFile = SettingKey<bool>('logToFile', false);
  static const logMaxLines = SettingKey<int>('logMaxLines', 2000);
  static const logKeepDays = SettingKey<int>('logKeepDays', 7);
  static const appLogLevel = SettingKey<String>('appLogLevel', 'info');

  // Notifications
  static const notifications = SettingKey<bool>('notifications', true);
  static const notifyConnect = SettingKey<bool>('notifyConnect', true);
  static const notifyDisconnect = SettingKey<bool>('notifyDisconnect', false);
  static const notifyError = SettingKey<bool>('notifyError', true);
  static const notifySubUpdate = SettingKey<bool>('notifySubUpdate', false);
  static const notifyLimits = SettingKey<bool>('notifyLimits', true);

  // System
  static const closeToTray = SettingKey<bool>('closeToTray', true);
  static const showTray = SettingKey<bool>('showTray', true);
  static const startMinimized = SettingKey<bool>('startMinimized', false);
  static const trayClick = SettingKey<String>('trayClick', 'show');

  // Autostart
  static const autostart = SettingKey<bool>('autostart', false);
  static const autostartMinimized = SettingKey<bool>('autostartMinimized', true);
  static const autostartConnect = SettingKey<bool>('autostartConnect', false);
  static const autostartDelay = SettingKey<int>('autostartDelay', 0);

  // Network
  static const preferIpv6 = SettingKey<bool>('preferIpv6', false);
  static const tcpFastOpen = SettingKey<bool>('tcpFastOpen', false);
  static const keepAlive = SettingKey<int>('keepAlive', 0);
  static const bindInterface = SettingKey<String>('bindInterface', '');
  static const watchNetwork = SettingKey<bool>('watchNetwork', true);

  // Privacy
  static const maskAddresses = SettingKey<bool>('maskAddresses', true);
  static const clearClipboard = SettingKey<bool>('clearClipboard', false);
  static const clipboardDetect = SettingKey<bool>('clipboardDetect', true);

  // Advanced
  static const debugMode = SettingKey<bool>('debugMode', false);
  static const metricsPort = SettingKey<int>('metricsPort', 10813);
  static const configOverride = SettingKey<String>('configOverride', '');

  // Internal state (not shown as settings)
  static const onboardingDone = SettingKey<bool>('_onboardingDone', false);
  static const hwid = SettingKey<String>('_hwid', '');
  static const selectedSub = SettingKey<String>('_selectedSub', '');
  static const selectedServer = SettingKey<String>('_selectedServer', '');
  static const lastMode = SettingKey<String>('_lastMode', 'proxy');
  static const wasConnected = SettingKey<bool>('_wasConnected', false);
  static const proxyApplied = SettingKey<bool>('_proxyApplied', false);
  static const geoUpdatedAt = SettingKey<int>('_geoUpdatedAt', 0);
  static const lastUpdateCheck = SettingKey<int>('_lastUpdateCheck', 0);
  static const lastPage = SettingKey<String>('_lastPage', 'servers');
  static const lastSettingsSection = SettingKey<String>('_lastSettingsSection', 'personal');
}

/// Immutable snapshot of settings values; unknown keys fall back to defaults.
@immutable
class Settings {
  const Settings(this.values);

  final Map<String, Object?> values;

  T get<T>(SettingKey<T> key) {
    final v = values[key.id];
    if (v == null) return key.def;
    if (key.def is List<String>) {
      return (v is List ? v.map((e) => e.toString()).toList() : key.def) as T;
    }
    if (key.def is double && v is num) return v.toDouble() as T;
    if (key.def is int && v is num) return v.toInt() as T;
    return v is T ? v as T : key.def;
  }

  Settings copyWith(String id, Object? value) => Settings({...values, id: value});
}
