// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:window_manager/legacy.dart';

import '../../core/platform.dart';
import '../../core/theme/tokens.dart';

/// Frameless window chrome: drag area + native-looking caption buttons.
class TitleBar extends StatelessWidget {
  const TitleBar({super.key, this.leading, this.title, this.height = 44});

  final Widget? leading;
  final Widget? title;
  final double height;

  @override
  Widget build(BuildContext context) {
    final mac = Plat.isMacOS;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(width: mac ? 76 : 8),
          ?leading,
          Expanded(
            child: DragToMoveArea(
              child: SizedBox.expand(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Align(alignment: Alignment.centerLeft, child: title),
                ),
              ),
            ),
          ),
          if (!mac) const _CaptionButtons(),
        ],
      ),
    );
  }
}

class _CaptionButtons extends StatefulWidget {
  const _CaptionButtons();

  @override
  State<_CaptionButtons> createState() => _CaptionButtonsState();
}

class _CaptionButtonsState extends State<_CaptionButtons> with WindowListener {
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _maximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Caption(icon: Icons.remove_rounded, onTap: () => windowManager.minimize()),
        _Caption(
          icon: _maximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
          iconSize: _maximized ? 12 : 14,
          onTap: () => _maximized ? windowManager.unmaximize() : windowManager.maximize(),
        ),
        _Caption(icon: Icons.close_rounded, onTap: () => windowManager.close(), danger: true),
      ],
    );
  }
}

class _Caption extends StatefulWidget {
  const _Caption({required this.icon, required this.onTap, this.danger = false, this.iconSize = 16});

  final IconData icon;
  final VoidCallback onTap;
  final bool danger;
  final double iconSize;

  @override
  State<_Caption> createState() => _CaptionState();
}

class _CaptionState extends State<_Caption> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          width: 46,
          height: double.infinity,
          color: _hover ? (widget.danger ? const Color(0xFFE81123) : c.hover) : Colors.transparent,
          child: Icon(widget.icon, size: widget.iconSize, color: _hover && widget.danger ? Colors.white : c.textSec),
        ),
      ),
    );
  }
}
