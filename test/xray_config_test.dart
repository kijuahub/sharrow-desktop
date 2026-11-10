import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sharrow/data/models/settings.dart';
import 'package:sharrow/modules/routing/routing_profile.dart';
import 'package:sharrow/modules/subscription/link_parser.dart';
import 'package:sharrow/modules/xray/config_builder.dart';

/// Validates generated configs with a real core when `XRAY_BIN` is set:
///   XRAY_BIN=path/to/xray flutter test test/xray_config_test.dart
const _links = [
  'vless://11111111-2222-3333-4444-555555555555@example.com:443?type=tcp&security=reality&pbk=Z84J2IelR9ch3k8VtlVhhs5ycBUlXA7wHBWcBrjqnAw&sni=www.microsoft.com&fp=chrome&sid=6ba85179e30d4fc2&flow=xtls-rprx-vision#%F0%9F%87%A9%F0%9F%87%AA%20Germany',
  'vless://11111111-2222-3333-4444-555555555555@example.com:443?type=ws&security=tls&path=%2Fws&host=cdn.example.com&sni=cdn.example.com#NL%20WS',
  'vless://11111111-2222-3333-4444-555555555555@example.com:443?type=xhttp&security=tls&path=%2Fx&mode=auto&sni=example.com#FI%20XHTTP',
  'vless://11111111-2222-3333-4444-555555555555@example.com:443?type=grpc&security=tls&serviceName=grpc&sni=example.com#US%20gRPC',
  'vless://11111111-2222-3333-4444-555555555555@example.com:8443?type=httpupgrade&security=tls&path=%2Fup&host=example.com#PL',
  'trojan://secret@example.com:443?security=tls&sni=example.com&type=tcp#Trojan',
  'vmess://eyJ2IjoiMiIsInBzIjoiSlAgVk1lc3MiLCJhZGQiOiJleGFtcGxlLmNvbSIsInBvcnQiOiI0NDMiLCJpZCI6IjExMTExMTExLTIyMjItMzMzMy00NDQ0LTU1NTU1NTU1NTU1NSIsImFpZCI6IjAiLCJuZXQiOiJ3cyIsInR5cGUiOiJub25lIiwiaG9zdCI6ImV4YW1wbGUuY29tIiwicGF0aCI6Ii92bSIsInRscyI6InRscyJ9',
  'ss://MjAyMi1ibGFrZTMtYWVzLTI1Ni1nY206QVFJREJBVUdCd2dKQ2dzTURRNFBFQkVTRXhRVkZoY1lHUm9iSEIwZUh5QT0@example.com:8388#SS2022',
  'ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ@example.com:8388#SS',
  'socks://dXNlcjpwYXNz@example.com:1080#Socks',
  'wireguard://cGsJ1O3%2F5YCHi%2BktaIP6Vex4g9wB5Gb0ywFtwy2E2EE%3D@example.com:51820?publickey=mU8s0DzhX5yP6kFv3vF3aYvM2mJk7zKZ8pQ%2FxG0kH0U%3D&address=10.0.0.2%2F32&mtu=1420#WG',
  'hysteria2://p%40ss@example.com:443?sni=example.com&obfs=salamander&obfs-password=obfspw&insecure=1#%F0%9F%87%B3%F0%9F%87%B1%20HY2',
  'hy2://user:pass@example.com:443,20000-30000/?sni=example.com&alpn=h3#HY2%20hop',
];

/// Happ routing profile as sent in the `routing` header.
final _profileLink = 'happ://routing/onadd/${base64.encode(utf8.encode(jsonEncode({
      'Name': 'RU',
      'GlobalProxy': 'false',
      'RemoteDNSType': 'DoH',
      'RemoteDNSDomain': 'https://cloudflare-dns.com/dns-query',
      'RemoteDNSIP': '1.1.1.1',
      'DomesticDNSType': 'DoU',
      'DomesticDNSDomain': '',
      'DomesticDNSIP': '77.88.8.8',
      'DnsHosts': {'dns.google': '8.8.8.8'},
      'RouteOrder': 'block-proxy-direct',
      'DirectSites': ['geosite:category-ru', 'domain:example.ru'],
      'DirectIp': ['geoip:ru', 'geoip:private'],
      'ProxySites': ['geosite:youtube', 'domain:openai.com'],
      'ProxyIp': ['149.154.160.0/20'],
      'BlockSites': ['geosite:category-ads-all'],
      'BlockIp': [],
      'DomainStrategy': 'IPIfNonMatch',
      'FakeDNS': 'true',
    })))}';

/// Remnawave-style Xray JSON subscription (array of full configs).
const _jsonSub = '''
[
  {"remarks": "DE JSON", "outbounds": [
    {"tag": "proxy", "protocol": "vless", "settings": {"vnext": [{"address": "example.com", "port": 443, "users": [{"id": "11111111-2222-3333-4444-555555555555", "encryption": "none", "flow": "xtls-rprx-vision"}]}]},
     "streamSettings": {"network": "tcp", "security": "reality", "realitySettings": {"serverName": "www.microsoft.com", "fingerprint": "chrome", "publicKey": "Z84J2IelR9ch3k8VtlVhhs5ycBUlXA7wHBWcBrjqnAw", "shortId": "6ba85179e30d4fc2"}}},
    {"tag": "direct", "protocol": "freedom"},
    {"tag": "block", "protocol": "blackhole"}
  ], "routing": {"domainStrategy": "IPIfNonMatch", "rules": [{"type": "field", "ip": ["geoip:private"], "outboundTag": "direct"}]}},
  {"remarks": "NL HY2", "outbounds": [
    {"tag": "proxy", "protocol": "hysteria", "settings": {"version": 2, "address": "example.com", "port": 443},
     "streamSettings": {"network": "hysteria", "security": "tls", "tlsSettings": {"serverName": "example.com", "alpn": ["h3"], "allowInsecure": true}, "hysteriaSettings": {"version": 2, "auth": "pw"}}},
    {"tag": "direct", "protocol": "freedom"}
  ]}
]
''';

final _variants = <String, Map<String, Object?>>{
  'default': {},
  'rules-ru': {'routingMode': 'rules', 'bypassPreset': 'ru', 'blockAds': true, 'blockQuic': true, 'directList': ['example.ru', '10.1.0.0/16'], 'proxyList': ['geosite:google']},
  'tweaks': {'fragment': true, 'mux': true, 'fakeDns': true, 'httpInbound': false, 'proxyAuth': true, 'proxyUser': 'u', 'proxyPass': 'p', 'dnsHosts': ['my.lan 192.168.1.10']},
  'apps-only': {'appRouting': 'proxy', 'appList': ['chrome.exe', 'Telegram.exe']},
  'apps-bypass': {'appRouting': 'direct', 'appList': ['steam.exe'], 'routingMode': 'rules', 'bypassPreset': 'ru'},
  'override': {'configOverride': '{"policy":{"levels":{"0":{"connIdle":600}}}}', 'accessLog': true, 'logLevel': 'debug'},
  'profile': {'appRouting': 'proxy', 'appList': ['Telegram.exe'], 'blockQuic': true},
};

void main() {
  final bin = Platform.environment['XRAY_BIN'];

  test('all sample links parse', () {
    for (final l in _links) {
      final s = LinkParser.parseUri(l);
      expect(s.address, 'example.com', reason: l);
    }
  });

  test('hysteria2 links', () {
    final a = LinkParser.parseUri(_links[_links.length - 2]);
    expect(a.protocol, 'hysteria');
    expect(a.isUdp, isTrue);
    final stream = a.outbound['streamSettings'] as Map;
    expect((stream['hysteriaSettings'] as Map)['auth'], 'p@ss');
    expect(((stream['finalmask'] as Map)['udp'] as List).first['type'], 'salamander');
    final b = LinkParser.parseUri(_links.last);
    expect(b.port, 443);
    expect((((b.outbound['streamSettings'] as Map)['finalmask'] as Map)['quicParams'] as Map)['udpHop'], {'ports': '443,20000-30000', 'interval': 30});
  });

  test('routing profile parses from header and body', () {
    final p = RoutingProfile.parse(_profileLink)!;
    expect(p.name, 'RU');
    expect(p.globalProxy, isFalse);
    expect(p.routeOrder, ['block', 'proxy', 'direct']);
    expect(LinkParser.parseText('$_profileLink\n${_links.first}').routing, _profileLink);
    expect(RoutingProfile.parse('happ://routing/off'), isNull);
  });

  test('xray json subscription', () {
    final r = LinkParser.parseText(_jsonSub);
    expect(r.servers.map((s) => s.name), ['DE JSON', 'NL HY2']);
    expect(r.servers.last.protocol, 'hysteria');
  });

  for (final v in _variants.entries) {
    for (final mode in TunnelMode.values) {
      test('configs build and validate: ${v.key}/${mode.name}', () async {
        final settings = Settings(v.value);
        final dir = Directory.systemTemp.createTempSync('sharrow_cfg');
        final profile = v.key == 'profile' ? RoutingProfile.parse(_profileLink) : null;
        try {
          for (final server in [..._links.map(LinkParser.parseUri), ...LinkParser.parseText(_jsonSub).servers]) {
            final cfg = XrayConfigBuilder.encode(XrayConfigBuilder.build(server, settings, mode: mode, profile: profile), pretty: true);
            final dump = Platform.environment['XRAY_DUMP'];
            if (dump != null) File('$dump${Platform.pathSeparator}${v.key}-${mode.name}-${server.protocol}-${server.port}.json').writeAsStringSync(cfg);
            if (bin == null) continue;
            final f = File('${dir.path}${Platform.pathSeparator}c.json')..writeAsStringSync(cfg);
            final r = await Process.run(bin, ['run', '-test', '-c', f.path], environment: {'XRAY_LOCATION_ASSET': File(bin).parent.path});
            expect(r.exitCode, 0, reason: '${server.name} (${server.protocolLabel})\n${r.stdout}\n${r.stderr}\n$cfg');
          }
        } finally {
          dir.deleteSync(recursive: true);
        }
      });
    }
  }
}
