import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../widgets/surface.dart';
import 'connect_panel.dart';
import 'subscription_panel.dart';

class ServersPage extends StatelessWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 760) return const _NarrowLayout();
      final left = (box.maxWidth * 0.38).clamp(320.0, 440.0);
      return Row(
        children: [
          SizedBox(
            width: left,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 12, 0),
              child: SubscriptionPanel(),
            ),
          ),
          const Hairline(vertical: true),
          const Expanded(child: ConnectPanel()),
        ],
      );
    });
  }
}

class _NarrowLayout extends StatefulWidget {
  const _NarrowLayout();

  @override
  State<_NarrowLayout> createState() => _NarrowLayoutState();
}

class _NarrowLayoutState extends State<_NarrowLayout> {
  final listKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: ConnectPanel(
            compact: true,
            onServerCardTap: () {
              final ctx = listKey.currentContext;
              if (ctx != null) Scrollable.ensureVisible(ctx, duration: Motion.slow, curve: Motion.curve);
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            key: listKey,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: const SubscriptionPanel(shrinkWrap: true),
          ),
        ),
      ],
    );
  }
}
