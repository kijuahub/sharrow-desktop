import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n.dart';
import '../../core/platform.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/settings.dart';
import '../../modules/subscription/link_parser.dart';
import '../../state/scope.dart';
import '../../state/subscriptions_controller.dart';
import '../widgets/buttons.dart';
import '../widgets/pressable.dart';

class AddForm extends StatefulWidget {
  const AddForm({super.key, required this.onAdded, this.showName = false, this.autofocus = true});

  final void Function(AddResult result) onAdded;
  final bool showName;
  final bool autofocus;

  @override
  State<AddForm> createState() => _AddFormState();
}

class _AddFormState extends State<AddForm> {
  final _input = TextEditingController();
  final _name = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _clip;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      if (_error != null) setState(() => _error = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _detectClipboard());
  }

  bool _isLink(String s) {
    final t = s.trim();
    return t.startsWith('https://') || t.startsWith('http://') || LinkParser.looksLikeShareLink(t);
  }

  Future<void> _detectClipboard() async {
    if (!mounted || !Plat.isDesktop || !context.app.settings.get(K.clipboardDetect)) return;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (mounted && text.isNotEmpty && text.length < 20000 && _isLink(text)) setState(() => _clip = text);
    } catch (_) {}
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _input.text = text;
      _input.selection = TextSelection.collapsed(offset: text.length);
    }
  }

  Future<void> _submit() async {
    if (_loading) return;
    final app = context.app;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await app.subs.add(_input.text, name: widget.showName ? _name.text : null);
      if (app.settings.get(K.clearClipboard)) await Clipboard.setData(const ClipboardData(text: ''));
      if (!mounted) return;
      _input.clear();
      _name.clear();
      setState(() => _clip = null);
      widget.onAdded(result);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: Motion.normal,
          curve: Motion.curve,
          child: _clip == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Pressable(
                    onTap: () {
                      _input.text = _clip!;
                      setState(() => _clip = null);
                    },
                    color: c.accent.withValues(alpha: 0.1),
                    border: Border.all(color: c.accent.withValues(alpha: 0.25)),
                    radius: Radii.md,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(children: [
                      Icon(Icons.content_paste_go_rounded, size: 16, color: c.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr('Вставить ссылку из буфера обмена', 'Paste link from clipboard'),
                          style: context.tt.labelLarge?.copyWith(color: c.accent),
                        ),
                      ),
                    ]),
                  ),
                ),
        ),
        TextField(
          controller: _input,
          autofocus: widget.autofocus,
          minLines: 1,
          maxLines: 5,
          keyboardType: TextInputType.url,
          style: context.tt.bodyMedium,
          onSubmitted: (_) => _submit(),
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: tr('Ссылка на подписку или ключ (vless://, vmess://, ss://…)', 'Subscription link or key (vless://, vmess://, ss://…)'),
            prefixIcon: Icon(Icons.link_rounded, size: 18, color: c.textTer),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            suffixIcon: IconBtn(icon: Icons.content_paste_rounded, tooltip: tr('Вставить', 'Paste'), onTap: _paste),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          ),
        ),
        if (widget.showName) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _name,
            style: context.tt.bodyMedium,
            decoration: InputDecoration(
              hintText: tr('Название (необязательно)', 'Name (optional)'),
              prefixIcon: Icon(Icons.label_outline_rounded, size: 18, color: c.textTer),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
            ),
          ),
        ],
        AnimatedSize(
          duration: Motion.normal,
          curve: Motion.curve,
          child: _error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.error_outline_rounded, size: 15, color: c.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: context.tt.bodySmall?.copyWith(color: c.danger))),
                  ]),
                ),
        ),
        const SizedBox(height: 14),
        ValueListenableBuilder(
          valueListenable: _input,
          builder: (context, v, _) => AppButton(
            label: tr('Добавить', 'Add'),
            icon: Icons.add_rounded,
            expand: true,
            height: 44,
            loading: _loading,
            onPressed: v.text.trim().isEmpty ? null : _submit,
          ),
        ),
      ],
    );
  }
}
