import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../state/scope.dart';
import '../widgets/feedback.dart';
import '../widgets/surface.dart';
import 'add_form.dart';

class AddPage extends StatelessWidget {
  const AddPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final formats = [
      ('VLESS', 'Reality, XTLS Vision, XHTTP, WS, gRPC'),
      ('VMess', 'TCP, WS, gRPC, HTTPUpgrade'),
      ('Trojan', 'TLS, WS, gRPC'),
      ('Shadowsocks', 'AEAD, 2022'),
      ('WireGuard', 'wireguard://'),
      (tr('Подписки', 'Subscriptions'), tr('Base64, список ссылок, JSON Xray', 'Base64, link list, Xray JSON')),
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Добавить VPN', 'Add VPN'), style: context.tt.headlineMedium),
              const SizedBox(height: 6),
              Text(
                tr('Вставьте ссылку на подписку от провайдера или отдельный ключ подключения.', 'Paste a subscription link from your provider or a single connection key.'),
                style: context.tt.bodyMedium?.copyWith(color: c.textSec),
              ),
              const SizedBox(height: 20),
              Panel(
                padding: const EdgeInsets.all(18),
                child: AddForm(
                  showName: true,
                  onAdded: (r) {
                    showToast(context, tr('Добавлено серверов: ${r.added}', 'Servers added: ${r.added}'));
                    context.app.page.value = 'servers';
                  },
                ),
              ),
              const SizedBox(height: 24),
              SectionLabel(tr('Поддерживаемые форматы', 'Supported formats')),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: [
                    for (var i = 0; i < formats.length; i++) ...[
                      if (i > 0) const Hairline(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(children: [
                          SizedBox(width: 120, child: Text(formats[i].$1, style: context.tt.titleSmall)),
                          Expanded(child: Text(formats[i].$2, style: context.tt.bodySmall)),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
