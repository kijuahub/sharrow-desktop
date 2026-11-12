import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../data/models/settings.dart';
import '../../state/scope.dart';
import '../widgets/surface.dart';
import 'connect_panel.dart';
import 'island_bar.dart';
import 'subscription_panel.dart';

class ServersPage extends StatelessWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: context.app.settings,
      builder: (context, _) {
        final settings = context.app.settings;
        final layout = settings.get(K.serversLayout);
        final scene = settings.get(K.homeScene);
        final blend = scene == 'space' || scene == 'image' || (scene == 'planet' && settings.get(K.globeSpace));
        return LayoutBuilder(builder: (context, box) {
          if (box.maxWidth < 760) return const _NarrowLayout();
          if (layout == 'island') {
            return const Stack(
              children: [
                ConnectPanel(island: true),
                Positioned(top: 12, left: 16, right: 16, child: DynamicIsland()),
              ],
            );
          }
          final right = layout == 'right';
          final width = (box.maxWidth * 0.38).clamp(320.0, 440.0);
          final list = SizedBox(
            width: width,
            child: Padding(
              padding: EdgeInsets.fromLTRB(right ? 12 : 16, 12, right ? 16 : 12, 0),
              child: const SubscriptionPanel(),
            ),
          );
          final stage = Expanded(child: ConnectPanel(fade: blend, fadeEnd: right));
          return Row(
            children: [
              if (right) stage else list,
              if (!blend) const Hairline(vertical: true),
              if (right) list else stage,
            ],
          );
        });
      },
    );
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
