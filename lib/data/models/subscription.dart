import 'dart:math';

import 'server.dart';

enum LinkKind { support, telegram, web, custom }

class SubLink {
  const SubLink({required this.title, required this.url, this.kind = LinkKind.custom});

  final String title;
  final String url;
  final LinkKind kind;

  Map<String, dynamic> toJson() => {'title': title, 'url': url, 'kind': kind.name};

  factory SubLink.fromJson(Map<String, dynamic> j) => SubLink(
        title: j['title'] as String? ?? '',
        url: j['url'] as String? ?? '',
        kind: LinkKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => LinkKind.custom),
      );
}

class Subscription {
  Subscription({
    required this.id,
    required this.name,
    this.url,
    required this.addedAt,
    this.updatedAt,
    this.lastError,
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expire,
    this.providerInterval,
    this.announce,
    this.webPage,
    List<SubLink>? links,
    List<ServerProfile>? servers,
    this.autoUpdate = true,
    this.customName = false,
    this.routing,
  })  : links = links ?? [],
        servers = servers ?? [];

  final String id;
  String name;

  /// null for manually added keys.
  String? url;
  final DateTime addedAt;
  DateTime? updatedAt;
  String? lastError;
  int upload;
  int download;
  int total;
  DateTime? expire;

  /// Update interval in hours suggested by the provider.
  int? providerInterval;
  String? announce;
  String? webPage;
  List<SubLink> links;
  List<ServerProfile> servers;
  bool autoUpdate;

  /// User renamed the subscription — do not overwrite with provider title.
  bool customName;

  /// Routing profile JSON sent by the provider (Happ format), if any.
  Map<String, dynamic>? routing;

  bool get isManual => url == null;
  int get used => upload + download;
  bool get hasTraffic => total > 0 || used > 0;
  double? get usedFraction => total > 0 ? (used / total).clamp(0.0, 1.0) : null;
  int? get remaining => total > 0 ? max(0, total - used) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'addedAt': addedAt.millisecondsSinceEpoch,
        if (updatedAt != null) 'updatedAt': updatedAt!.millisecondsSinceEpoch,
        if (lastError != null) 'lastError': lastError,
        'upload': upload,
        'download': download,
        'total': total,
        if (expire != null) 'expire': expire!.millisecondsSinceEpoch,
        if (providerInterval != null) 'interval': providerInterval,
        if (announce != null) 'announce': announce,
        if (webPage != null) 'webPage': webPage,
        'links': links.map((l) => l.toJson()).toList(),
        'servers': servers.map((s) => s.toJson()).toList(),
        'autoUpdate': autoUpdate,
        'customName': customName,
        if (routing != null) 'routing': routing,
      };

  factory Subscription.fromJson(Map<String, dynamic> j) {
    DateTime? ts(Object? v) => v == null ? null : DateTime.fromMillisecondsSinceEpoch((v as num).toInt());
    return Subscription(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      url: j['url'] as String?,
      addedAt: ts(j['addedAt']) ?? DateTime.now(),
      updatedAt: ts(j['updatedAt']),
      lastError: j['lastError'] as String?,
      upload: (j['upload'] as num?)?.toInt() ?? 0,
      download: (j['download'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num?)?.toInt() ?? 0,
      expire: ts(j['expire']),
      providerInterval: (j['interval'] as num?)?.toInt(),
      announce: j['announce'] as String?,
      webPage: j['webPage'] as String?,
      links: [for (final l in (j['links'] as List? ?? const [])) SubLink.fromJson(Map<String, dynamic>.from(l as Map))],
      servers: [for (final s in (j['servers'] as List? ?? const [])) ServerProfile.fromJson(Map<String, dynamic>.from(s as Map))],
      autoUpdate: j['autoUpdate'] as bool? ?? true,
      customName: j['customName'] as bool? ?? false,
      routing: j['routing'] == null ? null : Map<String, dynamic>.from(j['routing'] as Map),
    );
  }
}
