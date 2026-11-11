import 'package:flutter/material.dart';

import '../../core/brand.dart';
import '../../core/brand_icons.dart';
import '../../core/l10n.dart';
import '../../core/platform.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/settings.dart';
import '../../modules/xray/vpn_core.dart';
import '../../state/connection_controller.dart';
import '../../state/scope.dart';
import '../about/about_page.dart';
import '../add/add_page.dart';
import '../logs/logs_page.dart';
import '../servers/servers_page.dart';
import '../settings/settings_page.dart';
import '../widgets/badges.dart';
import '../widgets/buttons.dart';
import 'admin_dialog.dart';
import '../widgets/mark.dart';
import '../widgets/pressable.dart';
import '../widgets/surface.dart';
import '../widgets/title_bar.dart';

class NavItem {
  const NavItem(this.id, this.icon, this.activeIcon, this.ru, this.en);

  final String id;
  final IconData icon;
  final IconData activeIcon;
  final String ru;
  final String en;

  String get label => tr(ru, en);
}

const kNav = [
  NavItem('add', Icons.add_circle_outline_rounded, Icons.add_circle_rounded, 'Добавить', 'Add'),
  NavItem('servers', Icons.public_rounded, Icons.public_rounded, 'Серверы', 'Servers'),
  NavItem('settings', Icons.tune_rounded, Icons.tune_rounded, 'Настройки', 'Settings'),
  NavItem('logs', Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Логи', 'Logs'),
  NavItem('buy', Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, 'Купить VPN', 'Buy VPN'),
  NavItem('about', Icons.info_outline_rounded, Icons.info_rounded, 'О программе', 'About'),
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  bool _drawer = false;
  bool _adminDialogOpen = false;
  late final ConnectionController _conn;

  @override
  void initState() {
    super.initState();
    _conn = context.app.conn..addListener(_onConn);
  }

  @override
  void dispose() {
    _conn.removeListener(_onConn);
    super.dispose();
  }

  void _onConn() {
    if (_adminDialogOpen || _conn.errorKind != CoreErrorKind.permission) return;
    // iOS shows its own "Add VPN Configurations" alert from prepare().
    if (!Plat.isWindows && !Plat.isAndroid) return;
    _adminDialogOpen = true;
    _conn.clearError();
    final dialog = Plat.isWindows ? showAdminDialog(context) : showVpnPermissionDialog(context);
    dialog.whenComplete(() => _adminDialogOpen = false);
  }

  void _toggle(bool narrow) {
    if (narrow) {
      setState(() => _drawer = !_drawer);
    } else {
      final s = context.app.settings;
      s.set(K.sidebarExpanded, !s.get(K.sidebarExpanded));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    return LayoutBuilder(builder: (context, box) {
      final narrow = box.maxWidth < 640;
      final burger = IconBtn(icon: Icons.menu_rounded, tooltip: tr('Меню', 'Menu'), onTap: () => _toggle(narrow));
      final iconId = app.settings.get(K.appIcon);
      final title = Row(mainAxisSize: MainAxisSize.min, children: [
        if (iconId == 'default')
          SharrowMark(size: 16, color: c.text)
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(brandIconById(iconId).asset, width: 18, height: 18, fit: BoxFit.cover),
          ),
        const SizedBox(width: 8),
        Text('Sharrow', style: context.tt.titleSmall),
      ]);

      final top = Plat.isDesktop
          ? TitleBar(leading: burger, title: title)
          : SafeArea(
              bottom: false,
              child: SizedBox(height: 48, child: Row(children: [const SizedBox(width: 8), burger, const SizedBox(width: 6), title])),
            );

      final content = ValueListenableBuilder<String>(
        valueListenable: app.page,
        builder: (context, page, _) => AnimatedSwitcher(
          duration: app.settings.get(K.animations) ? Motion.normal : Duration.zero,
          switchInCurve: Motion.emphasized,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.012), end: Offset.zero).animate(anim), child: child),
          ),
          child: KeyedSubtree(key: ValueKey('$page/${L10n.lang}'), child: _page(page)),
        ),
      );

      return Column(
        children: [
          top,
          Expanded(
            child: Stack(
              children: [
                Row(
                  children: [
                    if (!narrow) ListenableBuilder(
                      listenable: app.settings,
                      builder: (context, _) => Sidebar(expanded: app.settings.get(K.sidebarExpanded)),
                    ),
                    if (!narrow) const Hairline(vertical: true),
                    Expanded(child: SafeArea(top: false, child: content)),
                  ],
                ),
                if (narrow) ...[
                  IgnorePointer(
                    ignoring: !_drawer,
                    child: AnimatedOpacity(
                      opacity: _drawer ? 1 : 0,
                      duration: Motion.normal,
                      child: GestureDetector(
                        onTap: () => setState(() => _drawer = false),
                        child: Container(color: Colors.black.withValues(alpha: 0.45)),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: Motion.normal,
                    curve: Motion.emphasized,
                    top: 0,
                    bottom: 0,
                    left: _drawer ? 0 : -260,
                    width: 248,
                    child: Material(
                      color: c.sidebar,
                      child: Sidebar(expanded: true, onNavigate: () => setState(() => _drawer = false)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _page(String id) => switch (id) {
        'add' => const AddPage(),
        'settings' => const SettingsPage(),
        'logs' => const LogsPage(),
        'about' => const AboutPage(),
        _ => const ServersPage(),
      };
}

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.expanded, this.onNavigate});

  final bool expanded;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    return AnimatedContainer(
      duration: Motion.normal,
      curve: Motion.emphasized,
      width: expanded ? 216 : 60,
      color: c.sidebar,
      child: ClipRect(
        child: ValueListenableBuilder<String>(
          valueListenable: app.page,
          builder: (context, page, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              for (final item in kNav)
                _NavTile(
                  item: item,
                  selected: page == item.id,
                  expanded: expanded,
                  onTap: () {
                    if (item.id == 'buy') {
                      app.openUrl(Brand.buyUrl);
                    } else {
                      app.page.value = item.id;
                    }
                    onNavigate?.call();
                  },
                ),
              const Spacer(),
              _ConnectionMini(expanded: expanded),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected, required this.expanded, required this.onTap});

  final NavItem item;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tile = Pressable(
      onTap: onTap,
      selected: selected,
      selectedColor: c.isDark ? const Color(0x14FFFFFF) : const Color(0x0F000000),
      radius: Radii.md,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: SizedBox(
        height: 38,
        child: Row(
          children: [
            Icon(selected ? item.activeIcon : item.icon, size: 19, color: selected ? c.text : c.textSec),
            Expanded(
              child: AnimatedOpacity(
                opacity: expanded ? 1 : 0,
                duration: Motion.fast,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: context.tt.labelLarge?.copyWith(color: selected ? c.text : c.textSec, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
      child: expanded ? tile : Tooltip(message: item.label, preferBelow: false, verticalOffset: 0, margin: const EdgeInsets.only(left: 60), child: tile),
    );
  }
}

class _ConnectionMini extends StatelessWidget {
  const _ConnectionMini({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    return ListenableBuilder(
      listenable: app.conn,
      builder: (context, _) {
        final status = app.conn.status;
        final color = switch (status) {
          ConnStatus.connected => c.accent,
          ConnStatus.connecting || ConnStatus.disconnecting => c.warning,
          ConnStatus.disconnected => c.textTer,
        };
        final label = switch (status) {
          ConnStatus.connected => tr('Подключено', 'Connected'),
          ConnStatus.connecting => tr('Подключение', 'Connecting'),
          ConnStatus.disconnecting => tr('Отключение', 'Disconnecting'),
          ConnStatus.disconnected => tr('Отключено', 'Disconnected'),
        };
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Pressable(
            onTap: () => app.conn.toggle(),
            tooltip: expanded ? null : label,
            radius: Radii.md,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              children: [
                StatusDot(color: color, glow: status == ConnStatus.connected),
                Expanded(
                  child: AnimatedOpacity(
                    opacity: expanded ? 1 : 0,
                    duration: Motion.fast,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.clip, style: context.tt.labelMedium),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
