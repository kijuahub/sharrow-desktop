import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/brand.dart';
import '../core/l10n.dart';
import '../core/platform.dart';
import '../data/storage/paths.dart';
import '../modules/routing/routing_profile.dart';
import '../data/models/server.dart';
import '../data/models/settings.dart';
import '../data/models/subscription.dart';
import '../data/storage/secure_box.dart';
import '../modules/logs/log_service.dart';
import '../modules/ping/ping_service.dart';
import '../modules/subscription/link_parser.dart';
import '../modules/subscription/subscription_fetcher.dart';
import '../modules/system/device_id.dart';
import 'settings_controller.dart';

class AddResult {
  AddResult(this.subscription, this.added);

  final Subscription subscription;
  final int added;
}

class SubscriptionsController extends ChangeNotifier {
  SubscriptionsController(this.settings, {required this.proxyProvider});

  final SettingsController settings;

  /// Local HTTP proxy to use for subscription requests, if any.
  final String? Function() proxyProvider;

  final _fetcher = SubscriptionFetcher();
  final ping = PingService();
  late SecureBox _box;
  Timer? _saveTimer;

  List<Subscription> subs = [];
  final Set<String> updating = {};
  final Set<String> pinging = {};

  /// Called after a subscription was refreshed (for notifications/limits).
  void Function(Subscription sub, Object? error)? onUpdated;

  String get keySource => _box.keySource;

  /// Device id for the x-hwid header, derived once and cached in settings.
  Future<String> hwid() async {
    final cached = settings.get(K.hwid);
    if (cached.isNotEmpty) return cached;
    final id = await DeviceId.compute();
    settings.set(K.hwid, id);
    return id;
  }

  Subscription? get selectedSub {
    final id = settings.get(K.selectedSub);
    return subs.where((s) => s.id == id).firstOrNull ?? subs.firstOrNull;
  }

  ServerProfile? get selectedServer {
    final id = settings.get(K.selectedServer);
    if (id.isNotEmpty) {
      for (final s in subs) {
        for (final srv in s.servers) {
          if (srv.id == id) return srv;
        }
      }
    }
    return selectedSub?.servers.firstOrNull;
  }

  Iterable<ServerProfile> get allServers => subs.expand((s) => s.servers);

  ServerProfile? serverById(String id) => allServers.where((s) => s.id == id).firstOrNull;

  Subscription? subOf(String serverId) => subs.where((s) => s.servers.any((x) => x.id == serverId)).firstOrNull;

  bool get isPinging => pinging.isNotEmpty;

  Future<void> load() async {
    _box = await SecureBox.open('vault.bin');
    try {
      final text = await _box.read();
      if (text != null) {
        final data = jsonDecode(text) as Map;
        subs = [for (final s in (data['subs'] as List? ?? const [])) Subscription.fromJson(Map<String, dynamic>.from(s as Map))];
      }
    } catch (e) {
      log.e('Failed to read encrypted storage', e);
      subs = [];
    }
    log.i('Loaded ${subs.length} subscription(s), key storage: ${_box.keySource}');
  }

  void _changed({bool persist = true}) {
    notifyListeners();
    if (persist) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 500), save);
    }
  }

  Future<void> save() async {
    _saveTimer?.cancel();
    try {
      await _box.write(jsonEncode({'v': 1, 'subs': subs.map((s) => s.toJson()).toList()}));
    } catch (e) {
      log.e('Failed to save encrypted storage', e);
    }
  }

  Future<void> wipe() async {
    subs = [];
    await _box.delete();
    settings.set(K.selectedSub, '');
    settings.set(K.selectedServer, '');
    _changed(persist: false);
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36) + Random().nextInt(1 << 20).toRadixString(36);

  void select(String subId) {
    settings.set(K.selectedSub, subId);
    final sub = subs.where((s) => s.id == subId).firstOrNull;
    final current = settings.get(K.selectedServer);
    if (sub != null && !sub.servers.any((s) => s.id == current) && sub.servers.isNotEmpty) {
      settings.set(K.selectedServer, sub.servers.first.id);
    }
    _changed(persist: false);
  }

  void selectServer(String serverId) {
    final sub = subOf(serverId);
    if (sub != null) settings.set(K.selectedSub, sub.id);
    settings.set(K.selectedServer, serverId);
    _changed(persist: false);
  }

  /// Adds a subscription URL, share link(s) or Xray JSON.
  Future<AddResult> add(String input, {String? name}) async {
    final text = input.trim();
    if (text.isEmpty) throw SubscriptionException(tr('Вставьте ссылку или ключ', 'Paste a link or key'));
    final firstLine = text.split(RegExp(r'\s+')).first;
    if (firstLine.startsWith('http://') || firstLine.startsWith('https://')) {
      final existing = subs.where((s) => s.url == firstLine).firstOrNull;
      if (existing != null) {
        await update(existing.id, throwOnError: true);
        select(existing.id);
        return AddResult(existing, existing.servers.length);
      }
      final sub = Subscription(id: _newId(), name: name?.trim().isNotEmpty == true ? name!.trim() : Uri.parse(firstLine).host, url: firstLine, addedAt: DateTime.now());
      sub.customName = name?.trim().isNotEmpty == true;
      await _refresh(sub);
      subs.add(sub);
      select(sub.id);
      if (sub.servers.isNotEmpty) selectServer(sub.servers.first.id);
      _changed();
      log.i('Subscription added: ${sub.name} (${sub.servers.length} servers)');
      return AddResult(sub, sub.servers.length);
    }

    final parsed = LinkParser.parseText(text);
    if (parsed.servers.isEmpty) {
      throw SubscriptionException(parsed.errors.isNotEmpty ? parsed.errors.first : tr('Не удалось распознать ключ', 'Unrecognized key format'));
    }
    var manual = subs.where((s) => s.isManual).firstOrNull;
    if (manual == null) {
      manual = Subscription(id: _newId(), name: name?.trim().isNotEmpty == true ? name!.trim() : tr('Мои ключи', 'My keys'), addedAt: DateTime.now());
      subs.add(manual);
    }
    final known = manual.servers.map((s) => s.id).toSet();
    final fresh = parsed.servers.where((s) => !known.contains(s.id)).toList();
    manual.servers.addAll(fresh);
    manual.updatedAt = DateTime.now();
    select(manual.id);
    final target = fresh.isNotEmpty ? fresh.first : parsed.servers.first;
    selectServer(manual.servers.firstWhere((s) => s.id == target.id).id);
    _changed();
    log.i('Added ${fresh.length} key(s) to ${manual.name}');
    return AddResult(manual, fresh.length);
  }

  String get userAgent {
    final custom = settings.get(K.subUserAgent).trim();
    if (custom.isNotEmpty) return custom;
    return settings.get(K.subFormat) == 'links' ? Brand.userAgentLinks : Brand.userAgentJson;
  }

  /// Routing profile of the server's subscription, when enabled.
  RoutingProfile? routingFor(ServerProfile server) {
    if (!settings.get(K.subRouting) || server.fullConfig != null) return null;
    final raw = subOf(server.id)?.routing;
    return raw == null ? null : RoutingProfile(raw);
  }

  Future<void> _refresh(Subscription sub) async {
    final r = await _fetcher.fetch(
      sub.url!,
      userAgent: userAgent,
      timeout: Duration(seconds: settings.get(K.subTimeout)),
      httpProxy: settings.get(K.subViaProxy) ? proxyProvider() : null,
      headers: settings.get(K.sendHwid) ? await DeviceId.headers(await hwid()) : const {},
    );
    final oldById = {for (final s in sub.servers) s.id: s};
    for (final s in r.servers) {
      final old = oldById[s.id];
      if (old != null) {
        s.ping = old.ping;
        s.pingAt = old.pingAt;
      }
    }
    sub.servers = r.servers;
    if (!sub.customName && r.title != null && r.title!.trim().isNotEmpty) sub.name = r.title!.trim();
    sub.upload = r.upload ?? 0;
    sub.download = r.download ?? 0;
    sub.total = r.total ?? 0;
    sub.expire = r.expire;
    sub.providerInterval = r.interval;
    sub.announce = r.announce;
    sub.webPage = r.webPage;
    sub.links = r.links;
    sub.routing = r.routing?.raw;
    if (r.routing != null) {
      log.i('${sub.name}: routing profile "${r.routing!.name}"');
      if (Plat.isDesktop) unawaited(r.routing!.ensureGeo(AppPaths.core.path, httpProxy: proxyProvider()));
    }
    sub.updatedAt = DateTime.now();
    sub.lastError = null;
    if (r.errors.isNotEmpty) log.w('${sub.name}: skipped ${r.errors.length} entr(ies): ${r.errors.take(3).join('; ')}');
  }

  Future<void> update(String subId, {bool throwOnError = false}) async {
    final sub = subs.where((s) => s.id == subId).firstOrNull;
    if (sub == null || sub.isManual || updating.contains(subId)) return;
    updating.add(subId);
    _changed(persist: false);
    Object? error;
    try {
      await _refresh(sub);
      final selected = settings.get(K.selectedServer);
      if (settings.get(K.selectedSub) == sub.id && !sub.servers.any((s) => s.id == selected) && sub.servers.isNotEmpty) {
        settings.set(K.selectedServer, sub.servers.first.id);
      }
      log.i('Subscription updated: ${sub.name} (${sub.servers.length} servers)');
    } catch (e) {
      error = e;
      sub.lastError = '$e';
      log.e('Subscription update failed (${sub.name})', e);
    } finally {
      updating.remove(subId);
      _changed();
    }
    onUpdated?.call(sub, error);
    if (error == null && settings.get(K.pingAfterUpdate)) unawaited(pingSub(sub.id));
    if (error != null && throwOnError) throw error;
  }

  bool isDue(Subscription s) {
    if (s.isManual || !s.autoUpdate) return false;
    final hours = settings.get(K.subRespectProvider) && (s.providerInterval ?? 0) > 0 ? s.providerInterval! : settings.get(K.subInterval);
    final last = s.updatedAt;
    return last == null || DateTime.now().difference(last) >= Duration(hours: max(1, hours));
  }

  Future<void> updateAll({bool onlyDue = false}) async {
    for (final s in List.of(subs)) {
      if (s.isManual) continue;
      if (onlyDue && !isDue(s)) continue;
      await update(s.id);
    }
  }

  void remove(String subId) {
    subs.removeWhere((s) => s.id == subId);
    if (settings.get(K.selectedSub) == subId) {
      settings.set(K.selectedSub, subs.firstOrNull?.id ?? '');
      settings.set(K.selectedServer, subs.firstOrNull?.servers.firstOrNull?.id ?? '');
    }
    _changed();
  }

  void rename(String subId, String name) {
    final s = subs.where((s) => s.id == subId).firstOrNull;
    if (s == null || name.trim().isEmpty) return;
    s.name = name.trim();
    s.customName = true;
    _changed();
  }

  void setUrl(String subId, String url) {
    final s = subs.where((s) => s.id == subId).firstOrNull;
    if (s == null || s.isManual) return;
    s.url = url.trim();
    _changed();
  }

  void setAutoUpdate(String subId, bool value) {
    final s = subs.where((s) => s.id == subId).firstOrNull;
    if (s == null) return;
    s.autoUpdate = value;
    _changed();
  }

  void move(int from, int to) {
    if (from == to || from < 0 || from >= subs.length) return;
    final s = subs.removeAt(from);
    subs.insert(to.clamp(0, subs.length), s);
    _changed();
  }

  void removeServer(String serverId) {
    for (final s in subs) {
      s.servers.removeWhere((x) => x.id == serverId);
    }
    if (settings.get(K.selectedServer) == serverId) {
      settings.set(K.selectedServer, selectedSub?.servers.firstOrNull?.id ?? '');
    }
    _changed();
  }

  void renameServer(String serverId, String name) {
    final s = serverById(serverId);
    if (s == null || name.trim().isEmpty) return;
    s.name = name.trim();
    _changed();
  }

  Duration get _pingTimeout => Duration(milliseconds: settings.get(K.pingTimeout));

  Future<void> pingSub(String subId) async {
    final sub = subs.where((s) => s.id == subId).firstOrNull;
    if (sub == null || pinging.contains(subId) || sub.servers.isEmpty) return;
    pinging.add(subId);
    _changed(persist: false);
    var lastNotify = DateTime.now();
    await ping.pingAll(
      sub.servers,
      timeout: _pingTimeout,
      concurrency: settings.get(K.pingConcurrency),
      method: settings.get(K.pingMethod),
      settings: settings.snapshot,
      onResult: (_) {
        final now = DateTime.now();
        if (now.difference(lastNotify).inMilliseconds > 120) {
          lastNotify = now;
          notifyListeners();
        }
      },
    );
    pinging.remove(subId);
    _changed();
  }

  Future<void> pingServer(ServerProfile s) async {
    s.ping = await ping.measure(s, settings.get(K.pingMethod), _pingTimeout, settings: settings.snapshot);
    s.pingAt = DateTime.now();
    _changed();
  }

  Future<ServerProfile?> pickFastest({String? subId}) async {
    final sub = subId == null ? selectedSub : subs.where((s) => s.id == subId).firstOrNull;
    if (sub == null || sub.servers.isEmpty) return null;
    final stale = sub.servers.any((s) => s.ping == null || s.pingAt == null || DateTime.now().difference(s.pingAt!).inMinutes > 10);
    if (stale) await pingSub(sub.id);
    final alive = sub.servers.where((s) => (s.ping ?? -1) > 0).toList()..sort((a, b) => a.ping!.compareTo(b.ping!));
    final best = alive.firstOrNull;
    if (best != null) selectServer(best.id);
    return best;
  }

  List<ServerProfile> visible(Subscription sub, {String query = ''}) {
    var list = sub.servers;
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((s) => s.name.toLowerCase().contains(q) || s.protocol.contains(q) || (s.countryCode?.toLowerCase() == q)).toList();
    }
    if (settings.get(K.hideUnreachable)) list = list.where((s) => !s.isUnreachable).toList();
    switch (settings.get(K.sortBy)) {
      case 'name':
        list = [...list]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'ping':
        int key(ServerProfile s) => (s.ping ?? 0) > 0 ? s.ping! : 1 << 30;
        list = [...list]..sort((a, b) => key(a).compareTo(key(b)));
    }
    return list;
  }
}
