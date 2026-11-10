import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/l10n.dart';
import '../../data/models/server.dart';
import '../../data/models/subscription.dart';
import '../routing/routing_profile.dart';
import 'link_parser.dart';

class SubscriptionException implements Exception {
  SubscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FetchResult {
  FetchResult({
    required this.servers,
    required this.errors,
    this.title,
    this.upload,
    this.download,
    this.total,
    this.expire,
    this.interval,
    this.announce,
    this.webPage,
    this.links = const [],
    this.routing,
  });

  final List<ServerProfile> servers;
  final List<String> errors;
  final String? title;
  final int? upload;
  final int? download;
  final int? total;
  final DateTime? expire;
  final int? interval;
  final String? announce;
  final String? webPage;
  final List<SubLink> links;
  final RoutingProfile? routing;
}

class SubscriptionFetcher {
  Future<FetchResult> fetch(
    String url, {
    required String userAgent,
    Duration timeout = const Duration(seconds: 20),
    String? httpProxy,
    Map<String, String> headers = const {},
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw SubscriptionException(tr('Некорректная ссылка на подписку', 'Invalid subscription URL'));
    }
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..userAgent = userAgent
      ..autoUncompress = true;
    if (httpProxy != null) client.findProxy = (_) => 'PROXY $httpProxy';
    try {
      final req = await client.getUrl(uri).timeout(timeout);
      req.headers.set(HttpHeaders.acceptHeader, '*/*');
      headers.forEach(req.headers.set);
      req.followRedirects = true;
      final res = await req.close().timeout(timeout);
      final bytes = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b)).timeout(timeout);
      if (res.statusCode >= 400) {
        throw SubscriptionException(tr('Сервер подписки ответил ошибкой ${res.statusCode}', 'Subscription server returned ${res.statusCode}'));
      }
      final body = utf8.decode(bytes, allowMalformed: true);
      final parsed = LinkParser.parseText(body);
      if (parsed.servers.isEmpty) {
        throw SubscriptionException(parsed.errors.isNotEmpty
            ? tr('Не удалось разобрать подписку: ${parsed.errors.first}', 'Failed to parse subscription: ${parsed.errors.first}')
            : tr('Подписка не содержит серверов', 'Subscription contains no servers'));
      }
      return _withHeaders(res.headers, parsed);
    } on TimeoutException {
      throw SubscriptionException(tr('Превышено время ожидания ответа', 'Request timed out'));
    } on SocketException catch (e) {
      throw SubscriptionException(tr('Нет соединения: ${e.message}', 'Connection failed: ${e.message}'));
    } on HandshakeException {
      throw SubscriptionException(tr('Ошибка TLS при загрузке подписки', 'TLS error while loading subscription'));
    } finally {
      client.close(force: true);
    }
  }

  static String? _decodeValue(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    var s = v.trim();
    if (s.startsWith('base64:')) {
      return LinkParser.tryBase64(s.substring(7)) ?? s.substring(7);
    }
    try {
      // dart:io exposes header bytes as latin1; recover UTF-8 text.
      s = utf8.decode(latin1.encode(s));
    } catch (_) {}
    return s;
  }

  FetchResult _withHeaders(HttpHeaders h, ParseResult parsed) {
    int? up, down, total;
    DateTime? expire;
    final info = h.value('subscription-userinfo');
    if (info != null) {
      for (final part in info.split(';')) {
        final kv = part.split('=');
        if (kv.length != 2) continue;
        final v = int.tryParse(kv[1].trim().split('.').first);
        switch (kv[0].trim().toLowerCase()) {
          case 'upload':
            up = v;
          case 'download':
            down = v;
          case 'total':
            total = v;
          case 'expire':
            if (v != null && v > 0) expire = DateTime.fromMillisecondsSinceEpoch(v * 1000);
        }
      }
    }

    var title = _decodeValue(h.value('profile-title'));
    if (title == null) {
      final cd = h.value('content-disposition');
      final m = cd == null ? null : RegExp(r'filename\*?=(?:UTF-8\x27\x27)?"?([^";]+)"?').firstMatch(cd);
      if (m != null) title = Uri.decodeComponent(m.group(1)!);
    }

    final links = <SubLink>[];
    final support = _decodeValue(h.value('support-url'));
    if (support != null) {
      final isTg = support.contains('t.me/') || support.startsWith('tg:');
      links.add(SubLink(
        title: isTg ? 'Telegram' : tr('Поддержка', 'Support'),
        url: support,
        kind: isTg ? LinkKind.telegram : LinkKind.support,
      ));
    }
    final custom = _decodeValue(h.value('sharrow-links'));
    if (custom != null) {
      try {
        for (final item in jsonDecode(custom) as List) {
          final m = Map<String, dynamic>.from(item as Map);
          final url = '${m['url'] ?? ''}';
          if (url.isEmpty) continue;
          links.add(SubLink(
            title: '${m['title'] ?? url}',
            url: url,
            kind: url.contains('t.me/') ? LinkKind.telegram : LinkKind.custom,
          ));
        }
      } catch (_) {}
    }

    var announce = _decodeValue(h.value('announce'));
    final announceUrl = _decodeValue(h.value('announce-url'));
    if (announceUrl != null) links.add(SubLink(title: tr('Подробнее', 'Learn more'), url: announceUrl, kind: LinkKind.web));
    if (announce != null && announce.length > 400) announce = '${announce.substring(0, 400)}…';

    return FetchResult(
      servers: parsed.servers,
      errors: parsed.errors,
      title: title,
      upload: up,
      download: down,
      total: total,
      expire: expire,
      interval: int.tryParse(h.value('profile-update-interval')?.trim() ?? ''),
      announce: announce,
      webPage: _decodeValue(h.value('profile-web-page-url')),
      links: links,
      routing: RoutingProfile.parse(_decodeValue(h.value('routing'))) ?? RoutingProfile.parse(parsed.routing),
    );
  }
}
