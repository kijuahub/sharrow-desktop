import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/settings.dart';
import '../../state/scope.dart';
import '../widgets/buttons.dart';
import '../widgets/feedback.dart';

/// Centered prompt shown when a newer GitHub release is available.
Future<void> showUpdatePrompt(BuildContext context) {
  final app = context.app;
  final update = app.update;
  if (update == null) return Future.value();
  var skip = false;
  var busy = false;
  double? progress;
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('Доступно обновление!', 'Update available!'), textAlign: TextAlign.center, style: ctx.tt.titleLarge),
                const SizedBox(height: 8),
                Text('Sharrow ${update.version}', textAlign: TextAlign.center, style: ctx.tt.bodyMedium?.copyWith(color: ctx.c.textSec)),
                if (busy) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                ],
                CheckboxListTile(
                  value: skip,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(tr('Не показывать снова', "Don't show again"), style: ctx.tt.bodyMedium),
                  onChanged: busy ? null : (v) => setLocal(() => skip = v ?? false),
                ),
                Row(children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: tr('Напомнить позже', 'Remind later'),
                      onPressed: busy
                          ? null
                          : () {
                              if (skip) app.settings.set(K.skipUpdateVersion, update.version);
                              Navigator.pop(ctx);
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      label: tr('Обновить', 'Update'),
                      loading: busy,
                      onPressed: () async {
                        setLocal(() {
                          busy = true;
                          progress = null;
                        });
                        try {
                          await app.installAppUpdate((p) {
                            if (ctx.mounted) setLocal(() => progress = p);
                          });
                          if (skip) app.settings.set(K.skipUpdateVersion, update.version);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (_) {
                          if (ctx.mounted) {
                            setLocal(() => busy = false);
                            showToast(ctx, tr('Не удалось скачать обновление', 'Update download failed'), error: true);
                          }
                        }
                      },
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      );
    }),
  );
}
