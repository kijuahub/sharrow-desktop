import 'dart:io';

import 'sys.dart';

/// Names of running user applications, as matched by Xray's `process` routing rule.
abstract final class ProcessList {
  static const _systemWin = {
    'system', 'system idle process', 'registry', 'smss.exe', 'csrss.exe', 'wininit.exe', 'winlogon.exe', 'services.exe',
    'lsass.exe', 'svchost.exe', 'fontdrvhost.exe', 'dwm.exe', 'conhost.exe', 'sihost.exe', 'taskhostw.exe', 'ctfmon.exe',
    'runtimebroker.exe', 'searchhost.exe', 'searchindexer.exe', 'startmenuexperiencehost.exe', 'shellexperiencehost.exe',
    'textinputhost.exe', 'dllhost.exe', 'wudfhost.exe', 'audiodg.exe', 'spoolsv.exe', 'memory compression', 'securityhealthservice.exe',
    'msmpeng.exe', 'nissrv.exe', 'lsaiso.exe', 'wmiprvse.exe', 'smartscreen.exe', 'applicationframehost.exe', 'tasklist.exe',
    'xray.exe', 'sharrow.exe', 'backgroundtaskhost.exe', 'usermanagersvc.exe', 'dashost.exe', 'sgrmbroker.exe',
  };

  static Future<List<String>> running() async {
    final names = <String>{};
    try {
      if (Platform.isWindows) {
        final out = await Sys.output('tasklist', ['/fo', 'csv', '/nh']);
        for (final line in out.split('\n')) {
          final m = RegExp(r'^"([^"]+)"').firstMatch(line.trim());
          final name = m?.group(1);
          if (name != null && !_systemWin.contains(name.toLowerCase())) names.add(name);
        }
      } else if (Platform.isLinux) {
        final uid = (await Sys.output('id', ['-u'])).trim();
        for (final d in Directory('/proc').listSync().whereType<Directory>()) {
          final pid = d.uri.pathSegments.where((e) => e.isNotEmpty).last;
          if (int.tryParse(pid) == null) continue;
          try {
            final status = File('${d.path}/status').readAsStringSync();
            if (!RegExp('^Uid:\\s+$uid\\b', multiLine: true).hasMatch(status)) continue;
            final exe = Link('${d.path}/exe').resolveSymbolicLinksSync();
            final name = exe.split('/').last;
            if (name.isNotEmpty && name != 'xray' && name != 'sharrow') names.add(name);
          } catch (_) {}
        }
      } else if (Platform.isMacOS) {
        final out = await Sys.output('ps', ['-axo', 'comm=']);
        for (final line in out.split('\n')) {
          final path = line.trim();
          if (!path.startsWith('/Applications/') && !path.contains('.app/')) continue;
          names.add(path.split('/').last);
        }
      }
    } catch (_) {}
    final list = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}
