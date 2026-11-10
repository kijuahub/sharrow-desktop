import 'dart:convert';

import '../../data/models/server.dart';
import 'geo.dart';

class ParseResult {
  ParseResult(this.servers, this.errors, {this.routing});

  final List<ServerProfile> servers;
  final List<String> errors;

  /// `happ://routing/...` link found in the body, if any.
  final String? routing;
}

class ParseException implements Exception {
  ParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Converts share links, base64 subscriptions and Xray JSON configs into [ServerProfile]s.
abstract final class LinkParser {
  static const proxyProtocols = {'vless', 'vmess', 'trojan', 'shadowsocks', 'socks', 'http', 'wireguard', 'hysteria'};
  static const supportedSchemes = {'vless', 'vmess', 'trojan', 'ss', 'socks', 'socks5', 'wireguard', 'wg', 'hysteria2', 'hy2'};

  static bool looksLikeShareLink(String s) {
    final t = s.trim().toLowerCase();
    final i = t.indexOf('://');
    return i > 0 && supportedSchemes.contains(t.substring(0, i));
  }

  static ParseResult parseText(String input, {int depth = 0}) {
    final text = input.trim().replaceFirst('\uFEFF', '');
    final servers = <ServerProfile>[];
    final errors = <String>[];
    if (text.isEmpty) return ParseResult(servers, errors);

    if (text.startsWith('{') || text.startsWith('[')) {
      try {
        return ParseResult(parseJson(jsonDecode(text)), errors);
      } catch (e) {
        errors.add('JSON: $e');
        return ParseResult(servers, errors);
      }
    }

    if (!text.contains('://') && depth < 2) {
      final decoded = tryBase64(text);
      if (decoded != null) return parseText(decoded, depth: depth + 1);
    }

    final seen = <String>{};
    String? routing;
    for (final raw in text.split(RegExp(r'[\r\n]+'))) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) continue;
      if (line.toLowerCase().startsWith('happ://routing/')) {
        routing = line;
        continue;
      }
      if (line.toLowerCase().startsWith('happ://')) continue;
      try {
        final s = parseUri(line);
        if (seen.add(s.id)) servers.add(s);
      } on ParseException catch (e) {
        errors.add(e.message);
      } catch (e) {
        errors.add('${_short(line)}: $e');
      }
    }
    return ParseResult(servers, errors, routing: routing);
  }

  static String _short(String s) => s.length > 48 ? '${s.substring(0, 48)}…' : s;

  static String? tryBase64(String input) {
    var s = input.replaceAll(RegExp(r'\s'), '').replaceAll('-', '+').replaceAll('_', '/');
    if (s.isEmpty || !RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(s)) return null;
    s = s.replaceAll('=', '');
    s = s.padRight(s.length + (4 - s.length % 4) % 4, '=');
    try {
      return utf8.decode(base64.decode(s));
    } catch (_) {
      return null;
    }
  }

  static String _decode(String s) {
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      return s;
    }
  }

  static Map<String, String> _query(String q) {
    final out = <String, String>{};
    for (final part in q.split('&')) {
      if (part.isEmpty) continue;
      final i = part.indexOf('=');
      final k = i < 0 ? part : part.substring(0, i);
      final v = i < 0 ? '' : part.substring(i + 1);
      out[_decode(k)] = _decode(v);
    }
    return out;
  }

  static int _port(Object? v) {
    final p = v is num ? v.toInt() : int.tryParse('$v'.trim());
    if (p == null || p <= 0 || p > 65535) throw ParseException('Invalid port: $v');
    return p;
  }

  /// FNV-1a 64-bit, hex — stable ids that survive renames.
  static String hashId(String input) {
    var h = 0xcbf29ce484222325;
    for (final b in utf8.encode(input)) {
      h ^= b;
      h *= 0x100000001b3;
    }
    return (h & 0x7FFFFFFFFFFFFFFF).toRadixString(16).padLeft(16, '0');
  }

  static (String, int) _hostPort(String s) {
    var hp = s.trim();
    if (hp.endsWith('/')) hp = hp.substring(0, hp.length - 1);
    if (hp.startsWith('[')) {
      final end = hp.indexOf(']');
      if (end < 0) throw ParseException('Invalid IPv6 host');
      return (hp.substring(1, end), _port(hp.substring(end + 2)));
    }
    final i = hp.lastIndexOf(':');
    if (i < 0) throw ParseException('Missing port');
    return (hp.substring(0, i), _port(hp.substring(i + 1)));
  }

  static ServerProfile parseUri(String line) {
    final idx = line.indexOf('://');
    if (idx < 0) throw ParseException('${_short(line)}: unknown format');
    final scheme = line.substring(0, idx).toLowerCase();
    return switch (scheme) {
      'vless' => _parseStandard(line, 'vless'),
      'trojan' => _parseStandard(line, 'trojan'),
      'vmess' => _parseVmess(line),
      'ss' => _parseShadowsocks(line),
      'socks' || 'socks5' => _parseSocks(line),
      'wireguard' || 'wg' => _parseWireguard(line),
      'hysteria2' || 'hy2' => _parseHysteria2(line),
      'tuic' || 'hysteria' => throw ParseException('$scheme: протокол не поддерживается ядром Xray'),
      _ => throw ParseException('${_short(line)}: unknown scheme "$scheme"'),
    };
  }

  /// Splits `scheme://userinfo@host:port/path?query#name`.
  static ({String user, String host, int port, Map<String, String> q, String name, String withoutName}) _split(String line) {
    var rest = line;
    var name = '';
    final hash = rest.indexOf('#');
    if (hash >= 0) {
      name = _decode(rest.substring(hash + 1)).trim();
      rest = rest.substring(0, hash);
    }
    final withoutName = rest;
    rest = rest.substring(rest.indexOf('://') + 3);
    var query = '';
    final qi = rest.indexOf('?');
    if (qi >= 0) {
      query = rest.substring(qi + 1);
      rest = rest.substring(0, qi);
    }
    final at = rest.lastIndexOf('@');
    if (at < 0) throw ParseException('${_short(line)}: missing credentials');
    final user = _decode(rest.substring(0, at));
    var hostPart = rest.substring(at + 1);
    final slash = hostPart.indexOf('/');
    if (slash >= 0) hostPart = hostPart.substring(0, slash);
    final (host, port) = _hostPort(hostPart);
    return (user: user, host: host, port: port, q: _query(query), name: name, withoutName: withoutName);
  }

  static ServerProfile _make({
    required String protocol,
    required String host,
    required int port,
    required String name,
    required Map<String, dynamic> outbound,
    required String idSource,
    String network = 'tcp',
    String security = 'none',
    String? raw,
  }) {
    final display = name.isEmpty ? '$host:$port' : name;
    return ServerProfile(
      id: hashId(idSource),
      name: display,
      protocol: protocol,
      address: host,
      port: port,
      network: network,
      security: security,
      countryCode: Geo.detect(display),
      outbound: outbound,
      rawUri: raw,
    );
  }

  static ServerProfile _parseStandard(String line, String protocol) {
    final p = _split(line);
    final q = p.q;
    final network = (q['type'] ?? 'tcp').toLowerCase();
    final security = (q['security'] ?? (protocol == 'trojan' ? 'tls' : 'none')).toLowerCase();
    final settings = protocol == 'vless'
        ? {
            'vnext': [
              {
                'address': p.host,
                'port': p.port,
                'users': [
                  {
                    'id': p.user,
                    'encryption': (q['encryption'] ?? '').isEmpty ? 'none' : q['encryption'],
                    if ((q['flow'] ?? '').isNotEmpty) 'flow': q['flow'],
                  },
                ],
              },
            ],
          }
        : {
            'servers': [
              {'address': p.host, 'port': p.port, 'password': p.user},
            ],
          };
    final stream = streamSettings(network, security, q, p.host);
    return _make(
      protocol: protocol,
      host: p.host,
      port: p.port,
      name: p.name,
      network: stream['network'] as String,
      security: security,
      outbound: {'protocol': protocol, 'settings': settings, 'streamSettings': stream},
      idSource: p.withoutName,
      raw: line,
    );
  }

  static ServerProfile _parseVmess(String line) {
    final body = line.substring(8).split('#').first;
    final decoded = tryBase64(body);
    if (decoded == null || !decoded.trimLeft().startsWith('{')) {
      // vmess://uuid@host:port?... (standard URI format)
      final p = _split(line);
      final q = p.q;
      final network = (q['type'] ?? 'tcp').toLowerCase();
      final security = (q['security'] ?? 'none').toLowerCase();
      final stream = streamSettings(network, security, q, p.host);
      return _make(
        protocol: 'vmess',
        host: p.host,
        port: p.port,
        name: p.name,
        network: stream['network'] as String,
        security: security,
        outbound: {
          'protocol': 'vmess',
          'settings': {
            'vnext': [
              {
                'address': p.host,
                'port': p.port,
                'users': [
                  {'id': p.user, 'security': q['encryption'] ?? 'auto'},
                ],
              },
            ],
          },
          'streamSettings': stream,
        },
        idSource: p.withoutName,
        raw: line,
      );
    }
    final j = jsonDecode(decoded) as Map<String, dynamic>;
    String s(String k) => (j[k] ?? '').toString().trim();
    final host = s('add');
    final port = _port(j['port']);
    final network = s('net').isEmpty ? 'tcp' : s('net').toLowerCase();
    final security = s('tls').isEmpty ? 'none' : s('tls').toLowerCase();
    final q = <String, String>{
      if (s('host').isNotEmpty) 'host': s('host'),
      if (s('path').isNotEmpty) 'path': s('path'),
      if (s('type').isNotEmpty) 'headerType': s('type'),
      if (s('sni').isNotEmpty) 'sni': s('sni'),
      if (s('alpn').isNotEmpty) 'alpn': s('alpn'),
      if (s('fp').isNotEmpty) 'fp': s('fp'),
      if (s('pbk').isNotEmpty) 'pbk': s('pbk'),
      if (s('sid').isNotEmpty) 'sid': s('sid'),
      if (network == 'grpc') 'serviceName': s('path'),
      if (network == 'grpc' && s('type') == 'multi') 'mode': 'multi',
      if (network == 'kcp') 'seed': s('path'),
      if (network == 'xhttp' && s('type').isNotEmpty) 'mode': s('type'),
    };
    final stream = streamSettings(network, security, q, host);
    final id = s('id');
    return _make(
      protocol: 'vmess',
      host: host,
      port: port,
      name: s('ps'),
      network: stream['network'] as String,
      security: security,
      outbound: {
        'protocol': 'vmess',
        'settings': {
          'vnext': [
            {
              'address': host,
              'port': port,
              'users': [
                {'id': id, 'security': s('scy').isEmpty ? 'auto' : s('scy')},
              ],
            },
          ],
        },
        'streamSettings': stream,
      },
      idSource: 'vmess://$id@$host:$port/$network/$security/${s('path')}/${s('host')}',
      raw: line,
    );
  }

  static ServerProfile _parseShadowsocks(String line) {
    var body = line.substring(5);
    var name = '';
    final hash = body.indexOf('#');
    if (hash >= 0) {
      name = _decode(body.substring(hash + 1)).trim();
      body = body.substring(0, hash);
    }
    final qi = body.indexOf('?');
    if (qi >= 0) body = body.substring(0, qi);

    String method, password, host;
    int port;
    final at = body.lastIndexOf('@');
    if (at >= 0) {
      final userInfo = body.substring(0, at);
      final cred = tryBase64(userInfo) ?? _decode(userInfo);
      final c = cred.indexOf(':');
      if (c < 0) throw ParseException('ss: invalid credentials');
      method = cred.substring(0, c);
      password = cred.substring(c + 1);
      (host, port) = _hostPort(body.substring(at + 1));
    } else {
      final decoded = tryBase64(body);
      if (decoded == null) throw ParseException('ss: invalid link');
      final a = decoded.lastIndexOf('@');
      final c = decoded.indexOf(':');
      if (a < 0 || c < 0 || c > a) throw ParseException('ss: invalid link');
      method = decoded.substring(0, c);
      password = decoded.substring(c + 1, a);
      (host, port) = _hostPort(decoded.substring(a + 1));
    }
    return _make(
      protocol: 'shadowsocks',
      host: host,
      port: port,
      name: name,
      outbound: {
        'protocol': 'shadowsocks',
        'settings': {
          'servers': [
            {'address': host, 'port': port, 'method': method.toLowerCase(), 'password': password},
          ],
        },
        'streamSettings': {'network': 'tcp'},
      },
      idSource: 'ss://$method:$password@$host:$port',
      raw: line,
    );
  }

  static ServerProfile _parseSocks(String line) {
    final hasAuth = line.substring(line.indexOf('://') + 3).split('#').first.contains('@');
    String host;
    int port;
    String user = '', pass = '';
    String name = '';
    if (hasAuth) {
      final p = _split(line);
      host = p.host;
      port = p.port;
      name = p.name;
      final cred = tryBase64(p.user) ?? p.user;
      final c = cred.indexOf(':');
      user = c < 0 ? cred : cred.substring(0, c);
      pass = c < 0 ? '' : cred.substring(c + 1);
    } else {
      var body = line.substring(line.indexOf('://') + 3);
      final hash = body.indexOf('#');
      if (hash >= 0) {
        name = _decode(body.substring(hash + 1));
        body = body.substring(0, hash);
      }
      (host, port) = _hostPort(body.split('?').first);
    }
    return _make(
      protocol: 'socks',
      host: host,
      port: port,
      name: name,
      outbound: {
        'protocol': 'socks',
        'settings': {
          'servers': [
            {
              'address': host,
              'port': port,
              if (user.isNotEmpty) 'users': [
                {'user': user, 'pass': pass},
              ],
            },
          ],
        },
      },
      idSource: 'socks://$user@$host:$port',
      raw: line,
    );
  }

  static ServerProfile _parseWireguard(String line) {
    final p = _split(line);
    final q = p.q;
    final publicKey = q['publickey'] ?? q['publicKey'] ?? '';
    if (publicKey.isEmpty) throw ParseException('wireguard: missing public key');
    final addresses = (q['address'] ?? q['ip'] ?? '10.0.0.2/32').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final reserved = (q['reserved'] ?? '').split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList();
    return _make(
      protocol: 'wireguard',
      host: p.host,
      port: p.port,
      name: p.name,
      network: 'udp',
      outbound: {
        'protocol': 'wireguard',
        'settings': {
          'secretKey': p.user,
          'address': addresses,
          'peers': [
            {
              'publicKey': publicKey,
              'endpoint': '${p.host.contains(':') ? '[${p.host}]' : p.host}:${p.port}',
              if ((q['presharedkey'] ?? '').isNotEmpty) 'preSharedKey': q['presharedkey'],
            },
          ],
          'mtu': int.tryParse(q['mtu'] ?? '') ?? 1420,
          if (reserved.length == 3) 'reserved': reserved,
        },
      },
      idSource: p.withoutName,
      raw: line,
    );
  }

  /// `hysteria2://auth@host:port[,hop-ports]/?sni=&insecure=1&obfs=salamander&obfs-password=&mport=#name`
  static ServerProfile _parseHysteria2(String line) {
    var body = line.substring(line.indexOf('://') + 3);
    var name = '';
    final hash = body.indexOf('#');
    if (hash >= 0) {
      name = _decode(body.substring(hash + 1)).trim();
      body = body.substring(0, hash);
    }
    var query = '';
    final qi = body.indexOf('?');
    if (qi >= 0) {
      query = body.substring(qi + 1);
      body = body.substring(0, qi);
    }
    if (body.endsWith('/')) body = body.substring(0, body.length - 1);
    final q = _query(query);
    final at = body.lastIndexOf('@');
    final auth = at < 0 ? '' : _decode(body.substring(0, at));
    var hostPart = at < 0 ? body : body.substring(at + 1);

    // Port hopping may be written into the authority: host:443,20000-50000
    var hop = q['mport'] ?? q['ports'] ?? '';
    final colon = hostPart.lastIndexOf(':');
    if (colon > 0 && !hostPart.endsWith(']')) {
      final ports = hostPart.substring(colon + 1);
      if (ports.contains(',') || ports.contains('-')) {
        hop = hop.isEmpty ? ports : hop;
        final first = RegExp(r'\d+').firstMatch(ports)?.group(0) ?? '443';
        hostPart = '${hostPart.substring(0, colon)}:$first';
      }
    } else if (colon < 0 || hostPart.endsWith(']')) {
      hostPart = '$hostPart:443';
    }
    final (host, port) = _hostPort(hostPart);

    final sni = q['sni'] ?? q['peer'] ?? (_isIp(host) ? null : host);
    final alpn = (q['alpn'] ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final obfs = (q['obfs'] ?? '').toLowerCase();
    final obfsPass = q['obfs-password'] ?? q['obfs_password'] ?? q['obfsParam'] ?? '';
    final quic = <String, dynamic>{
      if (hop.isNotEmpty) 'udpHop': {'ports': hop, 'interval': int.tryParse(q['hopInterval'] ?? q['mportHopInt'] ?? '') ?? 30},
      if ((q['upmbps'] ?? '').isNotEmpty) 'brutalUp': '${q['upmbps']} mbps',
      if ((q['downmbps'] ?? '').isNotEmpty) 'brutalDown': '${q['downmbps']} mbps',
    };
    final finalmask = <String, dynamic>{
      if (obfs == 'salamander' && obfsPass.isNotEmpty)
        'udp': [
          {'type': 'salamander', 'settings': {'password': obfsPass}},
        ],
      if (quic.isNotEmpty) 'quicParams': quic,
    };
    final pin = q['pinSHA256'] ?? q['pinsha256'] ?? '';
    final stream = <String, dynamic>{
      'network': 'hysteria',
      'security': 'tls',
      'tlsSettings': {
        if (sni != null && sni.isNotEmpty) 'serverName': sni,
        'alpn': alpn.isEmpty ? ['h3'] : alpn,
        if (pin.isNotEmpty) 'pinnedPeerCertSha256': pin.replaceAll(':', '').toLowerCase(),
      },
      'hysteriaSettings': {'version': 2, 'auth': auth},
      if (finalmask.isNotEmpty) 'finalmask': finalmask,
    };
    return _make(
      protocol: 'hysteria',
      host: host,
      port: port,
      name: name,
      network: 'hysteria',
      security: 'tls',
      outbound: {
        'protocol': 'hysteria',
        'settings': {'version': 2, 'address': host, 'port': port},
        'streamSettings': stream,
      },
      idSource: 'hy2://$auth@$host:$port/$query',
      raw: line,
    );
  }

  static bool _isIp(String host) => RegExp(r'^[\d.]+$').hasMatch(host) || host.contains(':');

  static Map<String, dynamic> streamSettings(String networkIn, String securityIn, Map<String, String> q, String host) {
    var network = networkIn.toLowerCase();
    if (network == 'raw') network = 'tcp';
    if (network == 'h2' || network == 'http' || network == 'splithttp') network = 'xhttp';
    if (network == 'mkcp') network = 'kcp';
    final security = securityIn == 'xtls' ? 'tls' : securityIn;
    final path = q['path'];
    final hostHeader = q['host'];
    final s = <String, dynamic>{'network': network};

    switch (network) {
      case 'tcp':
        if (q['headerType'] == 'http') {
          s['tcpSettings'] = {
            'header': {
              'type': 'http',
              'request': {
                'path': [(path == null || path.isEmpty) ? '/' : path],
                if (hostHeader != null && hostHeader.isNotEmpty) 'headers': {'Host': hostHeader.split(',')},
              },
            },
          };
        }
      case 'ws':
        s['wsSettings'] = {
          'path': (path == null || path.isEmpty) ? '/' : path,
          if (hostHeader != null && hostHeader.isNotEmpty) 'host': hostHeader,
        };
      case 'grpc':
        s['grpcSettings'] = {
          'serviceName': q['serviceName'] ?? path ?? '',
          'multiMode': q['mode'] == 'multi',
          if ((q['authority'] ?? '').isNotEmpty) 'authority': q['authority'],
        };
      case 'httpupgrade':
        s['httpupgradeSettings'] = {
          'path': (path == null || path.isEmpty) ? '/' : path,
          if (hostHeader != null && hostHeader.isNotEmpty) 'host': hostHeader,
        };
      case 'xhttp':
        Map<String, dynamic>? extra;
        if ((q['extra'] ?? '').isNotEmpty) {
          try {
            extra = Map<String, dynamic>.from(jsonDecode(q['extra']!) as Map);
          } catch (_) {}
        }
        s['xhttpSettings'] = {
          'path': (path == null || path.isEmpty) ? '/' : path,
          if (hostHeader != null && hostHeader.isNotEmpty) 'host': hostHeader,
          if ((q['mode'] ?? '').isNotEmpty) 'mode': q['mode'],
          'extra': ?extra,
        };
      case 'kcp':
        s['kcpSettings'] = {
          'header': {'type': q['headerType'] ?? 'none'},
          if ((q['seed'] ?? '').isNotEmpty) 'seed': q['seed'],
        };
    }

    final sni = q['sni'] ?? q['peer'] ?? ((hostHeader?.isNotEmpty ?? false) ? hostHeader : (_isIp(host) ? null : host));
    final alpn = (q['alpn'] ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (security == 'tls') {
      s['security'] = 'tls';
      s['tlsSettings'] = {
        if (sni != null && sni.isNotEmpty) 'serverName': sni,
        'fingerprint': (q['fp'] ?? '').isEmpty ? 'chrome' : q['fp'],
        if (alpn.isNotEmpty) 'alpn': alpn,
        if ((q['pcs'] ?? q['pinnedPeerCertSha256'] ?? '').isNotEmpty) 'pinnedPeerCertSha256': q['pcs'] ?? q['pinnedPeerCertSha256'],
      };
    } else if (security == 'reality') {
      s['security'] = 'reality';
      s['realitySettings'] = {
        'serverName': q['sni'] ?? '',
        'fingerprint': (q['fp'] ?? '').isEmpty ? 'chrome' : q['fp'],
        'publicKey': q['pbk'] ?? '',
        'shortId': q['sid'] ?? '',
        'spiderX': q['spx'] ?? '',
        if ((q['pqv'] ?? '').isNotEmpty) 'mldsa65Verify': q['pqv'],
      };
    }
    return s;
  }

  // ---------- JSON configs ----------

  static List<ServerProfile> parseJson(Object? data) {
    final out = <ServerProfile>[];
    if (data is List) {
      for (final item in data) {
        if (item is Map) out.addAll(parseJson(Map<String, dynamic>.from(item)));
      }
      return out;
    }
    if (data is! Map) throw ParseException('Unsupported JSON');
    final map = Map<String, dynamic>.from(data);
    if (map['outbounds'] is List) {
      final s = _fromFullConfig(map, out.length);
      if (s != null) out.add(s);
    } else if (map['protocol'] is String && proxyProtocols.contains(map['protocol'])) {
      final s = _fromOutbound(map, map['tag']?.toString() ?? '');
      if (s != null) out.add(s);
    }
    return out;
  }

  static ServerProfile? _fromFullConfig(Map<String, dynamic> cfg, int index) {
    final outbounds = (cfg['outbounds'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final main = outbounds.where((o) => proxyProtocols.contains(o['protocol'])).firstOrNull;
    if (main == null) return null;
    final base = _fromOutbound(main, (cfg['remarks'] ?? cfg['remark'] ?? cfg['name'] ?? 'Config ${index + 1}').toString());
    if (base == null) return null;
    return ServerProfile(
      // Remarks and routing differ between provider templates that share one outbound.
      id: hashId(jsonEncode({'remarks': base.name, 'outbounds': cfg['outbounds'], 'routing': cfg['routing']})),
      name: base.name,
      protocol: base.protocol,
      address: base.address,
      port: base.port,
      network: base.network,
      security: base.security,
      countryCode: base.countryCode,
      outbound: main,
      fullConfig: cfg,
    );
  }

  static ServerProfile? _fromOutbound(Map<String, dynamic> o, String name) {
    final protocol = o['protocol'] as String;
    final settings = Map<String, dynamic>.from(o['settings'] as Map? ?? const {});
    String address = '';
    int port = 0;
    Map? first(Object? list) => list is List && list.isNotEmpty && list.first is Map ? list.first as Map : null;
    final node = first(settings['vnext']) ?? first(settings['servers']);
    if (node != null) {
      address = '${node['address'] ?? ''}';
      port = (node['port'] as num?)?.toInt() ?? 0;
    } else if (settings['address'] != null) {
      address = '${settings['address']}';
      port = (settings['port'] as num?)?.toInt() ?? 0;
    } else if (first(settings['peers']) case final peer?) {
      final ep = '${peer['endpoint'] ?? ''}';
      final i = ep.lastIndexOf(':');
      address = i > 0 ? ep.substring(0, i).replaceAll('[', '').replaceAll(']', '') : ep;
      port = i > 0 ? int.tryParse(ep.substring(i + 1)) ?? 0 : 0;
    }
    final stream = Map<String, dynamic>.from(o['streamSettings'] as Map? ?? const {});
    final out = Map<String, dynamic>.from(o)..remove('tag');
    final display = name.isEmpty ? '$address:$port' : name;
    return ServerProfile(
      id: hashId(jsonEncode(out)),
      name: display,
      protocol: protocol,
      address: address,
      port: port,
      network: (stream['network'] ?? 'tcp').toString(),
      security: (stream['security'] ?? 'none').toString(),
      countryCode: Geo.detect(display),
      outbound: out,
    );
  }
}
