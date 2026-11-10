import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../logs/log_service.dart';
import '../subscription/link_parser.dart';

/// Routing profile delivered by a subscription (Happ format: `routing` header
/// or a `happ://routing/add|onadd/<base64 json>` line in the body).
class RoutingProfile {
  RoutingProfile(this.raw);

  /// Original JSON as sent by the provider; persisted as is.
  final Map<String, dynamic> raw;

  /// Local copies of the profile's own geo databases (file names inside the
  /// Xray asset dir); resolved right before building the config.
  String? geoipFile;
  String? geositeFile;

  Object? _v(String key) {
    final k = key.toLowerCase();
    for (final e in raw.entries) {
      if (e.key.toLowerCase() == k) return e.value;
    }
    return null;
  }

  String _s(String key, [String fallback = '']) {
    final v = _v(key);
    return v == null || '$v'.trim().isEmpty ? fallback : '$v'.trim();
  }

  bool _b(String key, bool fallback) {
    final v = _v(key);
    if (v is bool) return v;
    if (v == null || '$v'.isEmpty) return fallback;
    return '$v'.toLowerCase() == 'true';
  }

  List<String> _l(String key) {
    final v = _v(key);
    if (v is List) return v.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
    if (v is String && v.trim().isNotEmpty) return v.split(RegExp(r'[,\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return const [];
  }

  String get name => _s('Name', 'Routing');
  bool get globalProxy => _b('GlobalProxy', true);
  bool get fakeDns => _b('FakeDNS', false);
  String get domainStrategy {
    final v = _s('DomainStrategy', 'IPIfNonMatch');
    return const {'AsIs', 'IPIfNonMatch', 'IPOnDemand'}.contains(v) ? v : 'IPIfNonMatch';
  }

  List<String> get routeOrder {
    final parts = _s('RouteOrder', 'block-proxy-direct').toLowerCase().split('-').where((e) => const {'block', 'proxy', 'direct'}.contains(e)).toList();
    for (final p in const ['block', 'proxy', 'direct']) {
      if (!parts.contains(p)) parts.add(p);
    }
    return parts;
  }

  List<String> sites(String kind) => _l('${kind}Sites');
  List<String> ips(String kind) => _l('${kind}Ip');

  String get geoipUrl => _s('Geoipurl');
  String get geositeUrl => _s('Geositeurl');

  Map<String, String> get hosts {
    final v = _v('DnsHosts');
    if (v is Map) return {for (final e in v.entries) '${e.key}': '${e.value}'};
    return const {};
  }

  ({String type, String domain, String ip}) dnsOf(String prefix) => (
        type: _s('${prefix}DNSType', 'DoU').toLowerCase(),
        domain: _s('${prefix}DNSDomain'),
        ip: _s('${prefix}DNSIP'),
      );

  /// Rewrites `geosite:x` / `geoip:x` to the profile's own databases when present.
  String geo(String entry) {
    if (entry.startsWith('geosite:') && geositeFile != null) return 'ext:$geositeFile:${entry.substring(8)}';
    if (entry.startsWith('geoip:') && geoipFile != null && entry != 'geoip:private') return 'ext:$geoipFile:${entry.substring(6)}';
    return entry;
  }

  /// Accepts a `happ://routing/...` link, `base64:`/plain base64 or raw JSON.
  /// Returns null for `happ://routing/off` or anything unparseable.
  static RoutingProfile? parse(String? value) {
    if (value == null) return null;
    var v = value.trim();
    if (v.isEmpty) return null;
    final lower = v.toLowerCase();
    if (lower.startsWith('happ://routing/')) {
      if (lower.startsWith('happ://routing/off')) return null;
      final rest = v.substring('happ://routing/'.length);
      final slash = rest.indexOf('/');
      v = slash < 0 ? rest : rest.substring(slash + 1);
    }
    if (!v.startsWith('{')) v = LinkParser.tryBase64(v) ?? v;
    try {
      final j = jsonDecode(v);
      if (j is Map) return RoutingProfile(Map<String, dynamic>.from(j));
    } catch (_) {}
    return null;
  }

  static String _fileFor(String url) => 'rp-${LinkParser.hashId(url).substring(0, 10)}.dat';

  static const _stall = Duration(seconds: 20);

  /// Uses already downloaded geo databases without touching the network.
  void useCachedGeo(String dir) {
    String? cached(String url) {
      if (url.isEmpty) return null;
      final name = _fileFor(url);
      return File('$dir${Platform.pathSeparator}$name').existsSync() ? name : null;
    }

    geoipFile = cached(geoipUrl);
    geositeFile = cached(geositeUrl);
  }

  /// Downloads the profile's geo databases into [dir] (once; refreshed weekly)
  /// and points [geoipFile]/[geositeFile] at them. Failures fall back to the
  /// default databases.
  Future<void> ensureGeo(String dir, {String? httpProxy}) async {
    Future<String?> fetch(String url) async {
      if (url.isEmpty || !url.startsWith('http')) return null;
      final name = _fileFor(url);
      final file = File('$dir${Platform.pathSeparator}$name');
      final fresh = file.existsSync() && DateTime.now().difference(file.lastModifiedSync()) < const Duration(days: 7);
      if (fresh) return name;
      final client = HttpClient()..connectionTimeout = _stall;
      if (httpProxy != null) client.findProxy = (_) => 'PROXY $httpProxy';
      try {
        final req = await client.getUrl(Uri.parse(url)).timeout(_stall);
        final res = await req.close().timeout(_stall);
        if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
        final bytes = await res.timeout(_stall).fold<List<int>>(<int>[], (a, b) => a..addAll(b));
        if (bytes.length < 1024) throw const FormatException('file is too small');
        final tmp = File('${file.path}.new');
        await tmp.writeAsBytes(bytes, flush: true);
        if (file.existsSync()) await file.delete();
        await tmp.rename(file.path);
        log.i('Routing profile geo downloaded: $url');
        return name;
      } catch (e) {
        log.w('Routing profile geo failed ($url): $e');
        return file.existsSync() ? name : null;
      } finally {
        client.close(force: true);
      }
    }

    geoipFile = await fetch(geoipUrl);
    geositeFile = await fetch(geositeUrl);
  }
}
