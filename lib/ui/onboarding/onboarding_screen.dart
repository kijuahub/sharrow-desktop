import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/platform.dart';
import '../../core/theme/tokens.dart';
import '../../state/scope.dart';
import '../add/add_form.dart';
import '../widgets/buttons.dart';
import '../widgets/mark.dart';
import '../widgets/title_bar.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final app = context.app;
    return Column(
      children: [
        if (Plat.isDesktop) const TitleBar(),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Motion.slow,
                  curve: Motion.emphasized,
                  builder: (context, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: c.border),
                          ),
                          child: Center(child: SharrowMark(size: 34, color: c.text)),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(tr('Добро пожаловать в Sharrow', 'Welcome to Sharrow'), textAlign: TextAlign.center, style: context.tt.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        tr('Добавьте ссылку на подписку или ключ подключения, чтобы начать.', 'Add a subscription link or a connection key to get started.'),
                        textAlign: TextAlign.center,
                        style: context.tt.bodyMedium?.copyWith(color: c.textSec),
                      ),
                      const SizedBox(height: 28),
                      AddForm(onAdded: (_) => app.completeOnboarding()),
                      const SizedBox(height: 6),
                      AppButton.ghost(label: tr('Добавить позже', 'Add later'), expand: true, onPressed: app.completeOnboarding),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
