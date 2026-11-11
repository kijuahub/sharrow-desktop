import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../state/scope.dart';
import '../widgets/buttons.dart';
import '../widgets/feedback.dart';

/// Explains why TUN needs elevation and offers a one-click UAC relaunch.
Future<void> showAdminDialog(BuildContext context) {
  final app = context.app;
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final c = ctx.c;
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.admin_panel_settings_outlined, size: 28, color: c.accent),
                ),
                const SizedBox(height: 16),
                Text(tr('Нужны права администратора', 'Administrator rights required'), textAlign: TextAlign.center, style: ctx.tt.titleLarge),
                const SizedBox(height: 8),
                Text(
                  tr('Режим TUN создаёт виртуальный сетевой адаптер и пускает через VPN весь трафик системы. Для этого Windows требует права администратора.',
                      'TUN mode creates a virtual network adapter and routes all system traffic through the VPN. Windows requires administrator rights for this.'),
                  textAlign: TextAlign.center,
                  style: ctx.tt.bodyMedium?.copyWith(color: c.textSec, height: 1.45),
                ),
                const SizedBox(height: 22),
                AppButton(
                  label: tr('Перезапустить от администратора', 'Restart as administrator'),
                  icon: Icons.shield_outlined,
                  height: 42,
                  expand: true,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await app.relaunchAsAdmin();
                    if (!ok && context.mounted) showToast(context, tr('Запуск с правами отменён', 'Elevation was cancelled'), error: true);
                  },
                ),
                const SizedBox(height: 8),
                AppButton.secondary(
                  label: tr('Подключиться через Proxy', 'Connect via Proxy'),
                  height: 40,
                  expand: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    app.conn.setMode('proxy');
                  },
                ),
                const SizedBox(height: 4),
                AppButton.ghost(label: tr('Отмена', 'Cancel'), height: 36, onPressed: () => Navigator.pop(ctx)),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Shown when Android or iOS refused the VPN configuration.
Future<void> showVpnPermissionDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final c = ctx.c;
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.vpn_key_outlined, size: 28, color: c.accent),
                ),
                const SizedBox(height: 16),
                Text(tr('Нужно разрешение VPN', 'VPN permission required'), textAlign: TextAlign.center, style: ctx.tt.titleLarge),
                const SizedBox(height: 8),
                Text(
                  tr('Система не разрешила конфигурацию VPN. Откройте настройки и добавьте Sharrow.',
                      'The system did not allow the VPN configuration. Open Settings and add Sharrow.'),
                  textAlign: TextAlign.center,
                  style: ctx.tt.bodyMedium?.copyWith(color: c.textSec, height: 1.45),
                ),
                const SizedBox(height: 22),
                AppButton(
                  label: tr('Открыть настройки VPN', 'Open VPN settings'),
                  icon: Icons.settings_outlined,
                  height: 42,
                  expand: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.app.conn.core.openVpnSettings();
                  },
                ),
                const SizedBox(height: 4),
                AppButton.ghost(label: tr('Отмена', 'Cancel'), height: 36, onPressed: () => Navigator.pop(ctx)),
              ],
            ),
          ),
        ),
      );
    },
  );
}
