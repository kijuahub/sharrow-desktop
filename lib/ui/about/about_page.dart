import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../../core/l10n.dart';
import '../../core/platform.dart';
import '../../core/theme/tokens.dart';
import '../../state/scope.dart';
import '../widgets/buttons.dart';
import '../widgets/feedback.dart';
import '../widgets/mark.dart';
import '../widgets/pressable.dart';
import '../widgets/surface.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: c.border)),
                    child: Center(child: SharrowMark(size: 40, color: c.text)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(Brand.appName, textAlign: TextAlign.center, style: context.tt.headlineMedium),
                const SizedBox(height: 4),
                Text('${tr('Версия', 'Version')} ${app.appVersion} · ${Plat.name}', textAlign: TextAlign.center, style: context.tt.bodySmall),
                const SizedBox(height: 22),
                if (app.update != null) ...[
                  Panel(
                    color: c.accent.withValues(alpha: 0.08),
                    borderColor: c.accent.withValues(alpha: 0.3),
                    child: Row(children: [
                      Icon(Icons.system_update_alt_rounded, color: c.accent, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${tr('Доступна версия', 'Version available')} ${app.update!.version}', style: context.tt.titleSmall)),
                      AppButton(label: tr('Скачать', 'Download'), height: 34, onPressed: () => app.openUrl(app.update!.url)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
                Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(children: [
                    _Row(tr('Ядро', 'Core'), app.coreVersion != null ? 'Xray ${app.coreVersion}' : tr('не установлено', 'not installed')),
                    const Hairline(),
                    _Row(tr('Хранилище ключей', 'Key storage'), app.subs.keySource == 'keychain' ? tr('Системное (защищённое)', 'System keychain') : tr('Локальный файл', 'Local file')),
                    const Hairline(),
                    _Row(tr('Шифрование', 'Encryption'), 'AES-256-GCM'),
                  ]),
                ),
                const SizedBox(height: 16),
                Panel(
                  padding: const EdgeInsets.all(6),
                  child: Column(children: [
                    _Link(Icons.language_rounded, tr('Сайт', 'Website'), () => app.openUrl(Brand.website)),
                    _Link(Icons.send_rounded, 'Telegram', () => app.openUrl(Brand.telegram)),
                    _Link(Icons.support_agent_rounded, tr('Поддержка', 'Support'), () => app.openUrl(Brand.support)),
                    _Link(Icons.description_outlined, tr('Лицензии', 'Licenses'), () => showLicensePage(context: context, applicationName: Brand.appName, applicationVersion: app.appVersion)),
                  ]),
                ),
                const SizedBox(height: 16),
                AppButton.secondary(
                  label: tr('Проверить обновления', 'Check for updates'),
                  icon: Icons.refresh_rounded,
                  onPressed: () async {
                    try {
                      final u = await app.checkAppUpdate(throwErrors: true);
                      if (context.mounted) showToast(context, u == null ? tr('Установлена последняя версия', 'You are up to date') : '${tr('Доступна версия', 'Available')} ${u.version}');
                    } catch (_) {
                      if (context.mounted) showToast(context, tr('Не удалось проверить обновления', 'Update check failed'), error: true);
                    }
                  },
                ),
                const SizedBox(height: 24),
                Text('© ${DateTime.now().year} Sharrow. Powered by Xray-core (MPL-2.0).', textAlign: TextAlign.center, style: context.tt.bodySmall?.copyWith(color: c.textTer)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(child: Text(k, style: context.tt.bodyMedium?.copyWith(color: context.c.textSec))),
          Text(v, style: context.tt.bodyMedium),
        ]),
      );
}

class _Link extends StatelessWidget {
  const _Link(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      radius: Radii.md,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(children: [
        Icon(icon, size: 18, color: c.textSec),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: context.tt.bodyMedium)),
        Icon(Icons.arrow_outward_rounded, size: 15, color: c.textTer),
      ]),
    );
  }
}
