class ServerProfile {
  ServerProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.address,
    required this.port,
    this.network = 'tcp',
    this.security = 'none',
    this.countryCode,
    required this.outbound,
    this.fullConfig,
    this.rawUri,
    this.ping,
    this.pingAt,
  });

  final String id;
  String name;
  final String protocol;
  final String address;
  final int port;
  final String network;
  final String security;
  final String? countryCode;

  /// Ready-to-use Xray outbound object (without tag).
  final Map<String, dynamic> outbound;

  /// Complete Xray config delivered by a JSON subscription, if any.
  final Map<String, dynamic>? fullConfig;
  final String? rawUri;

  /// null = unknown, -1 = unreachable, otherwise latency in ms.
  int? ping;
  DateTime? pingAt;

  bool get isUnreachable => ping == -1;

  /// QUIC/UDP-only servers can't be measured with a TCP handshake.
  bool get isUdp => protocol == 'hysteria' || protocol == 'wireguard' || network == 'hysteria' || network == 'kcp';

  String get protocolLabel => switch (protocol) {
        'vless' => 'VLESS',
        'vmess' => 'VMess',
        'trojan' => 'Trojan',
        'shadowsocks' => 'Shadowsocks',
        'socks' => 'SOCKS5',
        'http' => 'HTTP',
        'wireguard' => 'WireGuard',
        'hysteria' => 'Hysteria2',
        _ => protocol.toUpperCase(),
      };

  String get transportLabel {
    final parts = <String>[
      switch (network) {
        'raw' => 'TCP',
        'hysteria' => 'QUIC',
        _ => network.toUpperCase(),
      },
    ];
    if (security.isNotEmpty && security != 'none') {
      parts.add(security == 'reality' ? 'Reality' : security.toUpperCase());
    }
    if (fullConfig != null) parts.add('JSON');
    return parts.join(' · ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol,
        'address': address,
        'port': port,
        'network': network,
        'security': security,
        if (countryCode != null) 'cc': countryCode,
        'outbound': outbound,
        if (fullConfig != null) 'full': fullConfig,
        if (rawUri != null) 'uri': rawUri,
        if (ping != null) 'ping': ping,
        if (pingAt != null) 'pingAt': pingAt!.millisecondsSinceEpoch,
      };

  factory ServerProfile.fromJson(Map<String, dynamic> j) => ServerProfile(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        protocol: j['protocol'] as String? ?? 'unknown',
        address: j['address'] as String? ?? '',
        port: (j['port'] as num?)?.toInt() ?? 0,
        network: j['network'] as String? ?? 'tcp',
        security: j['security'] as String? ?? 'none',
        countryCode: j['cc'] as String?,
        outbound: Map<String, dynamic>.from(j['outbound'] as Map? ?? const {}),
        fullConfig: j['full'] == null ? null : Map<String, dynamic>.from(j['full'] as Map),
        rawUri: j['uri'] as String?,
        ping: (j['ping'] as num?)?.toInt(),
        pingAt: j['pingAt'] == null ? null : DateTime.fromMillisecondsSinceEpoch((j['pingAt'] as num).toInt()),
      );
}
