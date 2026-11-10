import 'dart:convert';
import 'dart:io';

import '../../data/models/server.dart';
import '../../data/models/settings.dart';
import '../routing/routing_builder.dart';
import '../routing/routing_profile.dart';

enum TunnelMode { proxy, tun }

class ConfigException implements Exception {
  ConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Generates a complete Xray JSON configuration for a server.
abstract final class XrayConfigBuilder {
  static String? _hostOf(String dns) {
    final uri = Uri.tryParse(dns.contains('://') ? dns : 'udp://$dns');
    final host = uri?.host ?? '';
    return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host) ? host : null;
  }

  static Map<String, dynamic> _sniffing(Settings s, {bool fake = false}) => {
        'enabled': s.get(K.sniffing) || fake,
        'destOverride': ['http', 'tls', 'quic', if (fake) 'fakedns'],
        'routeOnly': s.get(K.sniffRouteOnly),
      };

  static List<Map<String, dynamic>> inbounds(Settings s, TunnelMode mode, {required bool mobile}) {
    final listen = s.get(K.allowLan) ? '0.0.0.0' : '127.0.0.1';
    final fake = s.get(K.fakeDns) && mode == TunnelMode.tun;
    final auth = s.get(K.proxyAuth) && s.get(K.proxyPass).isNotEmpty;
    final list = <Map<String, dynamic>>[
      {
        'tag': 'socks-in',
        'listen': listen,
        'port': s.get(K.socksPort),
        'protocol': 'socks',
        'settings': {
          'udp': true,
          'auth': auth ? 'password' : 'noauth',
          if (auth) 'accounts': [
            {'user': s.get(K.proxyUser), 'pass': s.get(K.proxyPass)},
          ],
        },
        'sniffing': _sniffing(s),
      },
      if (s.get(K.httpInbound))
        {
          'tag': 'http-in',
          'listen': listen,
          'port': s.get(K.httpPort),
          'protocol': 'http',
          'settings': {
            if (auth) 'accounts': [
              {'user': s.get(K.proxyUser), 'pass': s.get(K.proxyPass)},
            ],
          },
          'sniffing': _sniffing(s),
        },
    ];

    if (mode == TunnelMode.tun) {
      final ipv6 = s.get(K.tunIpv6);
      final tun = <String, dynamic>{
        'name': Platform.isMacOS ? 'utun9' : s.get(K.tunName),
        'mtu': s.get(K.tunMtu),
      };
      if (!mobile) {
        final gw = s.get(K.tunGateway).trim();
        if (gw.isNotEmpty) tun['gateway'] = [gw, if (ipv6) 'fdfe:dcba:9876::1/126'];
        tun['dns'] = ['1.1.1.1'];
        if (Platform.isWindows) tun['desc'] = 'Sharrow';
        if (s.get(K.tunAutoRoute)) {
          tun['autoSystemRoutingTable'] = ['0.0.0.0/0', if (ipv6) '::/0'];
          final iface = s.get(K.bindInterface).trim();
          tun['autoOutboundsInterface'] = iface.isEmpty ? 'auto' : iface;
        }
        if (Platform.isWindows && s.get(K.tunStrict)) {
          tun['autoSystemWfpBlockLeak'] = ['dns', 'misconfigtun'];
        }
      }
      list.add({'tag': 'tun-in', 'port': 0, 'protocol': 'tun', 'settings': tun, 'sniffing': _sniffing(s, fake: fake)});
    }
    return list;
  }

  static Map<String, dynamic> _sockopt(Settings s) => {
        if (s.get(K.tcpFastOpen)) 'tcpFastOpen': true,
        if (s.get(K.keepAlive) > 0) 'tcpKeepAliveIdle': s.get(K.keepAlive),
      };

  /// Xray 26.11 refuses to start when `allowInsecure` is present (replaced by
  /// `pinnedPeerCertSha256`); old links and provider JSON still carry it.
  static void _dropRemovedTls(Map<String, dynamic> outbound) {
    final stream = outbound['streamSettings'];
    if (stream is Map && stream['tlsSettings'] is Map) (stream['tlsSettings'] as Map).remove('allowInsecure');
  }

  static Map<String, dynamic> proxyOutbound(ServerProfile server, Settings s) {
    final out = jsonDecode(jsonEncode(server.outbound)) as Map<String, dynamic>;
    _dropRemovedTls(out);
    out['tag'] = 'proxy';
    final stream = Map<String, dynamic>.from(out['streamSettings'] as Map? ?? {});
    final sockopt = Map<String, dynamic>.from(stream['sockopt'] as Map? ?? {})..addAll(_sockopt(s));
    final udp = server.protocol == 'wireguard' || server.protocol == 'hysteria' || stream['network'] == 'hysteria' || stream['network'] == 'kcp';
    if (s.get(K.fragment) && !udp && (stream['security'] == 'tls' || stream['security'] == 'reality')) {
      sockopt['dialerProxy'] = 'fragment';
    }
    if (sockopt.isNotEmpty) stream['sockopt'] = sockopt;
    if (stream.isNotEmpty) out['streamSettings'] = stream;

    final hasFlow = jsonEncode(out['settings']).contains('"flow":"xtls');
    if (s.get(K.mux) && !hasFlow && !udp) {
      out['mux'] = {'enabled': true, 'concurrency': s.get(K.muxConcurrency), 'xudpConcurrency': 16, 'xudpProxyUDP443': 'reject'};
    }
    return out;
  }

  static List<Map<String, dynamic>> _utilityOutbounds(Settings s) => [
        {
          'tag': 'direct',
          'protocol': 'freedom',
          'settings': {'domainStrategy': s.get(K.preferIpv6) ? 'UseIP' : 'UseIPv4'},
          if (_sockopt(s).isNotEmpty) 'streamSettings': {'sockopt': _sockopt(s)},
        },
        {'tag': 'block', 'protocol': 'blackhole', 'settings': {'response': {'type': 'http'}}},
        {'tag': 'dns-out', 'protocol': 'dns'},
        if (s.get(K.fragment))
          {
            'tag': 'fragment',
            'protocol': 'freedom',
            'settings': {
              'fragment': {
                'packets': s.get(K.fragmentPackets),
                'length': s.get(K.fragmentLength),
                'interval': s.get(K.fragmentInterval),
              },
            },
            'streamSettings': {
              'sockopt': {'tcpNoDelay': true, ..._sockopt(s)},
            },
          },
      ];

  static Map<String, dynamic> dns(Settings s, {required bool fake}) {
    final hosts = <String, dynamic>{};
    for (final line in s.get(K.dnsHosts)) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2 && !parts[0].startsWith('#')) hosts[parts[0]] = parts.sublist(1).length == 1 ? parts[1] : parts.sublist(1);
    }
    final preset = RoutingBuilder.presets[s.get(K.bypassPreset)];
    final directDomains = <String>[
      ...RoutingBuilder.classify(s.get(K.directList)).domains,
      if (s.get(K.routingMode) == 'rules' && preset != null) ...preset.domains,
    ];
    return {
      'tag': 'dns-internal',
      if (hosts.isNotEmpty) 'hosts': hosts,
      'servers': [
        if (fake) 'fakedns',
        s.get(K.remoteDns),
        if (directDomains.isNotEmpty) {'address': s.get(K.directDns), 'domains': directDomains, 'skipFallback': true},
        if (directDomains.isEmpty) s.get(K.directDns),
      ],
      'queryStrategy': s.get(K.dnsStrategy),
      'disableCache': !s.get(K.dnsCache),
    };
  }

  /// DNS for a subscription routing profile: remote resolver through the
  /// proxy, domestic one (direct) for the profile's direct domains.
  static ({Map<String, dynamic> dns, String? directIp}) profileDns(RoutingProfile p, Settings s, {required bool fake}) {
    final hosts = <String, dynamic>{...p.hosts};
    String server(({String type, String domain, String ip}) d, {required bool local}) {
      if (d.type == 'doh' && d.domain.startsWith('https://')) {
        final host = Uri.tryParse(d.domain)?.host ?? '';
        if (host.isNotEmpty && d.ip.isNotEmpty && _hostOf(host) == null) hosts.putIfAbsent(host, () => d.ip);
        return local ? d.domain.replaceFirst('https://', 'https+local://') : d.domain;
      }
      return d.ip;
    }

    final remote = server(p.dnsOf('Remote'), local: false);
    final domestic = server(p.dnsOf('Domestic'), local: true);
    final directDomains = [
      for (final e in RoutingBuilder.classify(p.sites('Direct')).domains)
        if (!e.startsWith('regexp:')) p.geo(e),
    ];
    return (
      dns: {
        'tag': 'dns-internal',
        if (hosts.isNotEmpty) 'hosts': hosts,
        'servers': [
          if (fake) 'fakedns',
          remote.isEmpty ? s.get(K.remoteDns) : remote,
          if (domestic.isNotEmpty && directDomains.isNotEmpty) {'address': domestic, 'domains': directDomains, 'skipFallback': true},
        ],
        'queryStrategy': s.get(K.dnsStrategy),
        'disableCache': !s.get(K.dnsCache),
      },
      directIp: domestic.startsWith('https') ? null : _hostOf(domestic),
    );
  }

  static Map<String, dynamic> build(
    ServerProfile server,
    Settings s, {
    required TunnelMode mode,
    bool mobile = false,
    RoutingProfile? profile,
  }) {
    final tun = mode == TunnelMode.tun;
    final fake = (profile?.fakeDns ?? s.get(K.fakeDns)) && tun;
    final loglevel = s.get(K.logLevel);

    Map<String, dynamic> config;
    if (server.fullConfig != null) {
      config = jsonDecode(jsonEncode(server.fullConfig)) as Map<String, dynamic>;
      config.remove('remarks');
      config['inbounds'] = inbounds(s, mode, mobile: mobile);
      final outs = (config['outbounds'] as List).cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      outs.forEach(_dropRemovedTls);
      if (!outs.any((o) => o['tag'] == 'dns-out')) outs.add({'tag': 'dns-out', 'protocol': 'dns'});
      config['outbounds'] = outs;
      final tags = outs.map((o) => o['tag']).toSet();
      final routing = Map<String, dynamic>.from(config['routing'] as Map? ?? {});
      final rules = List<dynamic>.from(routing['rules'] as List? ?? []);
      if (tags.contains('proxy') && tags.contains('direct')) {
        rules.insertAll(0, RoutingBuilder.appRules(s, perApp: !mobile));
      }
      if (tun && s.get(K.tunDnsHijack)) {
        rules.insert(0, {'type': 'field', 'inboundTag': ['tun-in'], 'port': '53', 'outboundTag': 'dns-out'});
      }
      routing['rules'] = rules;
      config['routing'] = routing;
    } else {
      if (server.outbound.isEmpty) throw ConfigException('Empty outbound');
      final pd = profile == null ? null : profileDns(profile, s, fake: fake);
      config = {
        'dns': pd?.dns ?? dns(s, fake: fake),
        'inbounds': inbounds(s, mode, mobile: mobile),
        'outbounds': [proxyOutbound(server, s), ..._utilityOutbounds(s)],
        'routing': RoutingBuilder.build(
          s,
          tun: tun,
          directDnsIp: profile == null ? _hostOf(s.get(K.directDns)) : pd!.directIp,
          perApp: !mobile,
          profile: profile,
        ),
      };
      if (fake) {
        config['fakedns'] = [
          {'ipPool': '198.18.0.0/15', 'poolSize': 65535},
        ];
      }
    }

    config['log'] = {
      'loglevel': loglevel,
      'access': s.get(K.accessLog) ? '' : 'none',
      'dnsLog': s.get(K.debugMode),
    };
    config['stats'] = {};
    config['policy'] = {
      'levels': {
        '0': {'handshake': 4, 'connIdle': 300, 'uplinkOnly': 1, 'downlinkOnly': 1},
      },
      'system': {'statsOutboundUplink': true, 'statsOutboundDownlink': true},
    };
    config['metrics'] = {'tag': 'metrics', 'listen': '127.0.0.1:${s.get(K.metricsPort)}'};

    final override = s.get(K.configOverride).trim();
    if (override.isNotEmpty) {
      try {
        final patch = jsonDecode(override);
        if (patch is Map) _deepMerge(config, Map<String, dynamic>.from(patch));
      } catch (e) {
        throw ConfigException('Config override: $e');
      }
    }
    return config;
  }

  static void _deepMerge(Map<String, dynamic> target, Map<String, dynamic> patch) {
    patch.forEach((k, v) {
      final cur = target[k];
      if (cur is Map && v is Map) {
        final m = Map<String, dynamic>.from(cur);
        _deepMerge(m, Map<String, dynamic>.from(v));
        target[k] = m;
      } else {
        target[k] = v;
      }
    });
  }

  static String encode(Map<String, dynamic> config, {bool pretty = false}) =>
      pretty ? const JsonEncoder.withIndent('  ').convert(config) : jsonEncode(config);
}
