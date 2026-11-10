import '../../data/models/settings.dart';
import 'routing_profile.dart';

/// Builds the Xray `routing` object from user preferences.
abstract final class RoutingBuilder {
  static const presets = {
    'ru': (
      domains: ['domain:ru', 'domain:su', 'domain:xn--p1ai', 'domain:yandex.net', 'domain:yandex.com', 'domain:vk.com', 'domain:userapi.com', 'domain:mail.ru', 'domain:gosuslugi.ru'],
      ips: ['geoip:ru'],
    ),
    'cn': (domains: ['geosite:cn'], ips: ['geoip:cn']),
    'ir': (domains: ['geosite:category-ir', 'domain:ir'], ips: ['geoip:ir']),
  };

  /// Telegram data centers and domains; written out so the rule never depends
  /// on which geoip.dat is installed.
  static const telegram = (
    domains: [
      'domain:telegram.org',
      'domain:telegram.me',
      'domain:t.me',
      'domain:telegra.ph',
      'domain:telesco.pe',
      'domain:tdesktop.com',
      'domain:cdn-telegram.org',
      'domain:telegram-cdn.org',
    ],
    ips: [
      '91.105.192.0/23',
      '91.108.4.0/22',
      '91.108.8.0/22',
      '91.108.12.0/22',
      '91.108.16.0/22',
      '91.108.20.0/22',
      '91.108.56.0/22',
      '95.161.64.0/20',
      '149.154.160.0/20',
      '185.76.151.0/24',
      '2001:67c:4e8::/48',
      '2001:b28:f23c::/48',
      '2001:b28:f23d::/48',
      '2001:b28:f23f::/48',
      '2a0a:f280::/32',
    ],
  );

  /// Splits user entries into Xray domain and IP matchers.
  static ({List<String> domains, List<String> ips}) classify(List<String> entries) {
    final domains = <String>[];
    final ips = <String>[];
    final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}(/\d{1,2})?$');
    final ipv6 = RegExp(r'^[0-9a-fA-F]*:[0-9a-fA-F:]*(/\d{1,3})?$');
    for (final raw in entries) {
      final e = raw.trim();
      if (e.isEmpty || e.startsWith('#')) continue;
      if (e.startsWith('geoip:') || e.startsWith('ext-ip:') || ipv4.hasMatch(e) || ipv6.hasMatch(e)) {
        ips.add(e);
      } else if (e.contains(':')) {
        domains.add(e); // geosite:, domain:, full:, regexp:, keyword:, ext:
      } else if (e.startsWith('*.')) {
        domains.add('domain:${e.substring(2)}');
      } else {
        domains.add('domain:$e');
      }
    }
    return (domains: domains, ips: ips);
  }

  static List<String> apps(Settings s) => s.get(K.appList).map((e) => e.trim()).where((e) => e.isNotEmpty && !e.startsWith('#')).toList();

  /// Per-app and Telegram rules; also injected into provider JSON configs.
  static List<Map<String, dynamic>> appRules(Settings s, {required bool perApp}) {
    final appMode = perApp ? s.get(K.appRouting) : 'off';
    final list = apps(s);
    return [
      if (list.isNotEmpty && appMode != 'off') {'type': 'field', 'process': list, 'outboundTag': appMode == 'direct' ? 'direct' : 'proxy'},
      if (s.get(K.telegramViaProxy)) ...[
        {'type': 'field', 'domain': telegram.domains, 'outboundTag': 'proxy'},
        {'type': 'field', 'ip': telegram.ips, 'outboundTag': 'proxy'},
      ],
    ];
  }

  static void _add(List<Map<String, dynamic>> rules, ({List<String> domains, List<String> ips}) m, String tag) {
    if (m.domains.isNotEmpty) rules.add({'type': 'field', 'domain': m.domains, 'outboundTag': tag});
    if (m.ips.isNotEmpty) rules.add({'type': 'field', 'ip': m.ips, 'outboundTag': tag});
  }

  static Map<String, dynamic> build(
    Settings s, {
    required bool tun,
    required String? directDnsIp,
    bool perApp = true,
    RoutingProfile? profile,
  }) {
    final rules = <Map<String, dynamic>>[];
    final onlyApps = perApp && s.get(K.appRouting) == 'proxy' && apps(s).isNotEmpty;

    if (tun && s.get(K.tunDnsHijack)) {
      rules.add({'type': 'field', 'inboundTag': ['tun-in'], 'port': '53', 'outboundTag': 'dns-out'});
    }
    if (directDnsIp != null) {
      rules.add({'type': 'field', 'ip': [directDnsIp], 'outboundTag': 'direct'});
    }
    rules.add({'type': 'field', 'inboundTag': ['dns-internal'], 'outboundTag': 'proxy'});

    if (s.get(K.blockQuic)) {
      rules.add({'type': 'field', 'network': 'udp', 'port': '443', 'outboundTag': 'block'});
    }

    if (profile != null) {
      rules.addAll(appRules(s, perApp: perApp));
      for (final kind in profile.routeOrder) {
        final name = '${kind[0].toUpperCase()}${kind.substring(1)}';
        final m = classify([...profile.sites(name), ...profile.ips(name)]);
        _add(rules, (domains: m.domains.map(profile.geo).toList(), ips: m.ips.map(profile.geo).toList()), kind);
      }
      if (s.get(K.bypassLan)) rules.add({'type': 'field', 'ip': ['geoip:private'], 'outboundTag': 'direct'});
      rules.add({'type': 'field', 'network': 'tcp,udp', 'outboundTag': profile.globalProxy && !onlyApps ? 'proxy' : 'direct'});
      return {'domainStrategy': profile.domainStrategy, 'rules': rules};
    }

    final block = classify(s.get(K.blockList));
    if (s.get(K.blockAds)) block.domains.add('geosite:category-ads-all');
    _add(rules, block, 'block');

    rules.addAll(appRules(s, perApp: perApp));

    _add(rules, classify(s.get(K.proxyList)), 'proxy');
    _add(rules, classify(s.get(K.directList)), 'direct');

    if (s.get(K.bypassLan)) {
      rules.add({'type': 'field', 'ip': ['geoip:private'], 'outboundTag': 'direct'});
      rules.add({'type': 'field', 'domain': ['domain:local', 'domain:localhost', 'domain:lan'], 'outboundTag': 'direct'});
    }

    if (s.get(K.routingMode) == 'rules') {
      final preset = presets[s.get(K.bypassPreset)];
      if (preset != null) _add(rules, (domains: preset.domains, ips: preset.ips), 'direct');
    }

    rules.add({'type': 'field', 'network': 'tcp,udp', 'outboundTag': onlyApps ? 'direct' : 'proxy'});

    return {'domainStrategy': s.get(K.domainStrategy), 'rules': rules};
  }
}
