import 'package:flutter/material.dart';

import '../../core/brand.dart';
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
import '../widgets/pressable.dart';
import '../widgets/surface.dart';
import '../settings/theme_studio.dart';
import '../widgets/title_bar.dart';
import 'admin_dialog.dart';
import 'update_dialog.dart';

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
  bool _menu = false;
  bool _adminDialogOpen = false;
  bool _updatePrompted = false;
  late final ConnectionController _conn;

  @override
  void initState() {
    super.initState();
    _conn = context.app.conn..addListener(_onConn);
    context.app.addListener(_offerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerUpdate());
  }

  @override
  void dispose() {
    context.app.removeListener(_offerUpdate);
    _conn.removeListener(_onConn);
    super.dispose();
  }

  void _offerUpdate() {
    if (!mounted || _updatePrompted || _adminDialogOpen) return;
    final app = context.app;
    final update = app.update;
    if (update == null || app.settings.get(K.skipUpdateVersion) == update.version) return;
    _updatePrompted = true;
    showUpdatePrompt(context);
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

      return ListenableBuilder(
        listenable: Listenable.merge([app.settings, themeStudio]),
        builder: (context, _) {
          final spec = SidebarSpec(app.settings.snapshot);
          final flush = spec.inset == 0 && spec.radius == 0 && !spec.border;
          final inTitle = spec.place == 'title';
          final drawerW = spec.expandedWidth + spec.inset * 2;
          final burger = IconBtn(
            icon: Icons.menu_rounded,
            tooltip: tr('Меню', 'Menu'),
            onTap: () {
              if (inTitle && !narrow) {
                setState(() => _menu = !_menu);
              } else {
                _toggle(narrow);
              }
            },
          );
          final title = inTitle
              ? _TitleButton(open: _menu, onTap: () => setState(() => _menu = !_menu))
              : Text('Sharrow', style: context.tt.titleSmall);
          final titleTint = app.settings.get(K.colorTitle);
          Widget top = Plat.isDesktop
              ? TitleBar(leading: narrow || !inTitle ? burger : null, title: title, absorbTitle: inTitle)
              : SafeArea(
                  bottom: false,
                  child: SizedBox(height: 48, child: Row(children: [const SizedBox(width: 8), burger, const SizedBox(width: 6), title])),
                );
          if (titleTint != 0) {
            top = ColoredBox(color: Color(titleTint), child: top);
          } else if (c.glassStyle) {
            top = Frost(child: top);
          }
          final side = Sidebar(expanded: app.settings.get(K.sidebarExpanded), spec: spec);
          final showSide = !narrow && !inTitle;
          final preview = themeStudio.draft != null;
          final expandedSide = app.settings.get(K.sidebarExpanded);
          final sideW = showSide && spec.place == 'right' ? (expandedSide ? spec.expandedWidth : spec.collapsed) + spec.inset * 2 : 0.0;
          final room = (box.maxWidth - sideW - 24).clamp(0.0, 420.0);
          var paneW = box.maxWidth * 0.4;
          if (paneW > room) paneW = room;
          final shell = Column(
            children: [
              top,
              Expanded(
                child: Stack(
                  children: [
                    Row(
                      children: [
                        if (showSide && spec.place != 'right') side,
                        if (showSide && flush && spec.place != 'right') const Hairline(vertical: true),
                        Expanded(child: IgnorePointer(ignoring: preview, child: SafeArea(top: false, child: content))),
                        if (showSide && flush && spec.place == 'right') const Hairline(vertical: true),
                        if (showSide && spec.place == 'right') side,
                      ],
                    ),
                    if (preview && paneW > 160)
                      Positioned(
                        top: 10,
                        right: 10 + sideW,
                        bottom: 10,
                        width: paneW,
                        child: const _StudioIn(),
                      ),
                    if (inTitle && _menu) ...[
                      Positioned.fill(child: GestureDetector(onTap: () => setState(() => _menu = false), behavior: HitTestBehavior.opaque, child: const SizedBox.expand())),
                      Positioned(top: 8, left: 0, right: 0, child: Center(child: _TitleMenu(spec: spec, onPick: () => setState(() => _menu = false)))),
                    ],
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
                        left: spec.place == 'right' ? null : (_drawer ? 0 : -(drawerW + 24)),
                        right: spec.place == 'right' ? (_drawer ? 0 : -(drawerW + 24)) : null,
                        width: drawerW,
                        child: Material(
                          color: Colors.transparent,
                          child: Sidebar(expanded: true, spec: spec, onNavigate: () => setState(() => _drawer = false)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
          return shell;
        },
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

class SidebarSpec {
  SidebarSpec(Settings s)
      : rail = sidebarRail(s),
        radius = s.get(K.sidebarRadius).clamp(0, 24),
        border = s.get(K.sidebarBorder),
        inset = s.get(K.sidebarInset).clamp(0, 16),
        center = s.get(K.sidebarIcons) == 'center',
        place = s.get(K.sidebarPlace);

  final double rail;
  final double radius;
  final bool border;
  final double inset;
  final bool center;
  final String place;

  double get collapsed => rail;
  double get expandedWidth => (rail * 2.7).clamp(180.0, 300.0);
  double get iconSize => (rail * 0.34).clamp(16.0, 40.0);
  double get tileHeight => (rail * 0.72).clamp(36.0, 84.0);
}

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.expanded, required this.spec, this.onNavigate});

  final bool expanded;
  final SidebarSpec spec;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final nav = _NavColumn(expanded: expanded, spec: spec, onNavigate: onNavigate);
    final radius = BorderRadius.circular(spec.radius);
    final edge = c.isDark ? const Color(0x28FFFFFF) : const Color(0x28000000);
    return AnimatedContainer(
      duration: Motion.normal,
      curve: Motion.emphasized,
      width: expanded ? spec.expandedWidth : spec.collapsed,
      margin: EdgeInsets.all(spec.inset),
      decoration: BoxDecoration(
        color: c.sidebar,
        borderRadius: radius,
        border: spec.border ? Border.all(color: edge) : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: LayoutBuilder(builder: (context, constraints) {
          final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: h),
              child: IntrinsicHeight(child: nav),
            ),
          );
        }),
      ),
    );
  }
}

class _StudioIn extends StatelessWidget {
  const _StudioIn();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: Motion.normal,
      curve: Motion.emphasized,
      builder: (_, t, child) => FractionalTranslation(translation: Offset(t, 0), child: child),
      child: const ThemeStudioPane(),
    );
  }
}

class _NavColumn extends StatelessWidget {
  const _NavColumn({required this.expanded, required this.spec, this.onNavigate});

  final bool expanded;
  final SidebarSpec spec;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ValueListenableBuilder<String>(
      valueListenable: app.page,
      builder: (context, page, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (spec.center) const Spacer() else const SizedBox(height: 8),
          for (final item in kNav)
            _NavTile(
              item: item,
              selected: page == item.id,
              expanded: expanded,
              spec: spec,
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
          _ConnectionMini(expanded: expanded, spec: spec),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _TitleButton extends StatelessWidget {
  const _TitleButton({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Pressable(
      onTap: onTap,
      radius: 8,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sharrow', style: context.tt.titleSmall),
          const SizedBox(width: 2),
          Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16, color: c.textSec),
        ],
      ),
    );
  }
}

class _TitleMenu extends StatelessWidget {
  const _TitleMenu({required this.spec, required this.onPick});

  final SidebarSpec spec;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return Material(
      color: Colors.transparent,
      child: Frost(
        radius: 16,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ValueListenableBuilder<String>(
              valueListenable: app.page,
              builder: (context, page, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final item in kNav)
                    _NavTile(
                      item: item,
                      selected: page == item.id,
                      expanded: true,
                      spec: spec,
                      onTap: () {
                        if (item.id == 'buy') {
                          app.openUrl(Brand.buyUrl);
                        } else {
                          app.page.value = item.id;
                        }
                        onPick();
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.selected, required this.expanded, required this.spec, required this.onTap});

  final NavItem item;
  final bool selected;
  final bool expanded;
  final SidebarSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final icon = Icon(selected ? item.activeIcon : item.icon, size: spec.iconSize, color: selected ? c.text : c.textSec);
    final label = Expanded(
      child: AnimatedOpacity(
        opacity: expanded ? 1 : 0,
        duration: Motion.fast,
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
            style: context.tt.labelLarge?.copyWith(color: selected ? c.text : c.textSec, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
          ),
        ),
      ),
    );
    final tile = Pressable(
      onTap: onTap,
      selected: selected,
      selectedColor: c.isDark ? const Color(0x14FFFFFF) : const Color(0x0F000000),
      radius: spec.radius > 0 ? 12 : Radii.md,
      padding: EdgeInsets.symmetric(horizontal: expanded ? 11 : 0),
      child: SizedBox(
        height: spec.tileHeight,
        child: expanded ? Row(children: [icon, label]) : Center(child: icon),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
      child: expanded ? tile : Tooltip(message: item.label, preferBelow: false, verticalOffset: 0, margin: EdgeInsets.only(left: spec.collapsed + 8), child: tile),
    );
  }
}

class _ConnectionMini extends StatelessWidget {
  const _ConnectionMini({required this.expanded, required this.spec});

  final bool expanded;
  final SidebarSpec spec;

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
        final dot = StatusDot(color: color, glow: status == ConnStatus.connected);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Pressable(
            onTap: () => app.conn.toggle(),
            tooltip: expanded ? null : label,
            radius: spec.radius > 0 ? 12 : Radii.md,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              children: [
                dot,
                Expanded(
                  child: AnimatedOpacity(
                    opacity: expanded ? 1 : 0,
                    duration: Motion.fast,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
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
