import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import 'buttons.dart';

OverlayEntry? _currentToast;

/// Minimal floating toast at the bottom center.
void showToast(BuildContext context, String message, {bool error = false, IconData? icon}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _currentToast?.remove();
  late OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _Toast(message: message, error: error, icon: icon, onDone: () {
        if (_currentToast == entry) _currentToast = null;
        entry.remove();
      }));
  _currentToast = entry;
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, required this.error, required this.onDone, this.icon});

  final String message;
  final bool error;
  final IconData? icon;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Motion.normal)..forward();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(Duration(milliseconds: widget.error ? 4200 : 2600), () async {
      if (!mounted) return;
      await _c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final anim = CurvedAnimation(parent: _c, curve: Motion.emphasized);
    return Positioned(
      left: 16,
      right: 16,
      bottom: 28,
      child: Center(
        child: FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: c.surfaceHi,
                  borderRadius: BorderRadius.circular(Radii.md),
                  border: Border.all(color: widget.error ? c.danger.withValues(alpha: 0.4) : c.borderStrong),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon ?? (widget.error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded),
                        size: 17, color: widget.error ? c.danger : c.success),
                    const SizedBox(width: 10),
                    Flexible(child: Text(widget.message, style: context.tt.bodyMedium, maxLines: 4, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String? confirm,
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => _AppDialog(
      title: title,
      content: Text(message, style: ctx.tt.bodyMedium?.copyWith(color: ctx.c.textSec)),
      actions: [
        AppButton.ghost(label: tr('Отмена', 'Cancel'), onPressed: () => Navigator.pop(ctx, false)),
        destructive
            ? AppButton(label: confirm ?? tr('Удалить', 'Delete'), tone: ButtonTone.danger, onPressed: () => Navigator.pop(ctx, true))
            : AppButton(label: confirm ?? 'OK', onPressed: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> showTextInput(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String? message,
  bool multiline = false,
  String? confirm,
  bool monospace = false,
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => _AppDialog(
      title: title,
      width: multiline ? 560 : 420,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null) ...[
            Text(message, style: ctx.tt.bodySmall),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: ctrl,
            autofocus: true,
            minLines: multiline ? 8 : 1,
            maxLines: multiline ? 16 : 1,
            style: monospace ? ctx.tt.bodyMedium?.copyWith(fontFamily: 'monospace', fontFamilyFallback: const ['Consolas', 'Menlo'], fontSize: 12.5) : null,
            decoration: InputDecoration(hintText: hint),
            onSubmitted: multiline ? null : (v) => Navigator.pop(ctx, v),
          ),
        ],
      ),
      actions: [
        AppButton.ghost(label: tr('Отмена', 'Cancel'), onPressed: () => Navigator.pop(ctx)),
        AppButton(label: confirm ?? tr('Сохранить', 'Save'), onPressed: () => Navigator.pop(ctx, ctrl.text)),
      ],
    ),
  );
}

Future<void> showInfoDialog(BuildContext context, {required String title, required Widget content, List<Widget>? actions, double width = 560}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _AppDialog(
      title: title,
      width: width,
      content: content,
      actions: actions ?? [AppButton.secondary(label: tr('Закрыть', 'Close'), onPressed: () => Navigator.pop(ctx))],
    ),
  );
}

class _AppDialog extends StatelessWidget {
  const _AppDialog({required this.title, required this.content, required this.actions, this.width = 420});

  final String title;
  final Widget content;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.tt.titleLarge),
              const SizedBox(height: 12),
              Flexible(child: SingleChildScrollView(child: content)),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                for (var i = 0; i < actions.length; i++) ...[if (i > 0) const SizedBox(width: 8), actions[i]],
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// Popup menu at a pointer position (context menus).
Future<T?> showContextMenuAt<T>(BuildContext context, Offset position, List<PopupMenuEntry<T>> items) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & overlay.size),
    items: items,
  );
}

PopupMenuItem<T> menuItem<T>(BuildContext context, T value, IconData icon, String label, {bool danger = false}) {
  final c = context.c;
  return PopupMenuItem<T>(
    value: value,
    height: 36,
    child: Row(children: [
      Icon(icon, size: 16, color: danger ? c.danger : c.textSec),
      const SizedBox(width: 10),
      Text(label, style: context.tt.bodyMedium?.copyWith(color: danger ? c.danger : c.text)),
    ]),
  );
}
