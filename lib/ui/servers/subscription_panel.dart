import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/server.dart';
import '../../data/models/settings.dart';
import '../../data/models/subscription.dart';
import '../../modules/subscription/geo.dart';
import '../../state/connection_controller.dart';
import '../../state/scope.dart';
import '../widgets/badges.dart';
import '../widgets/buttons.dart';
import '../widgets/feedback.dart';
import '../widgets/flag.dart';
import '../widgets/pressable.dart';
import '../widgets/surface.dart';

class SubscriptionPanel extends StatefulWidget {
  const SubscriptionPanel({super.key, this.shrinkWrap = false, this.grid = false});

  /// Renders the list inline (for the scrolling mobile layout).
  final bool shrinkWrap;

  /// Subscription details on the left, servers as a grid on the right.
  final bool grid;

  @override
  State<SubscriptionPanel> createState() => _SubscriptionPanelState();
}

class _SubscriptionPanelState extends State<SubscriptionPanel> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: Listenable.merge([app.subs, app.settings]),
      builder: (context, _) {
        final subs = app.subs;
        final sub = subs.selectedSub;
        if (sub == null) {
          return EmptyState(
            icon: Icons.layers_outlined,
            title: tr('Нет подписок', 'No subscriptions'),
            message: tr('Добавьте ссылку на подписку или ключ подключения, чтобы увидеть серверы.', 'Add a subscription link or a connection key to see servers.'),
            action: AppButton(label: tr('Добавить', 'Add'), icon: Icons.add_rounded, onPressed: () => app.page.value = 'add'),
          );
        }
        final servers = subs.visible(sub, query: _query);
        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SubHeader(sub: sub),
            const SizedBox(height: 10),
            _SubInfo(sub: sub),
            const SizedBox(height: 14),
            _SearchRow(controller: _search, onChanged: (v) => setState(() => _query = v), count: servers.length),
            const SizedBox(height: 8),
          ],
        );

        if (widget.grid) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 248,
                child: ListView(
                  padding: const EdgeInsets.only(right: 8),
                  children: [
                    _SubHeader(sub: sub),
                    const SizedBox(height: 10),
                    _SubInfo(sub: sub),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  if (constraints.maxWidth < 48) return const SizedBox.shrink();
                  return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchRow(controller: _search, onChanged: (v) => setState(() => _query = v), count: servers.length),
                    const SizedBox(height: 8),
                    Expanded(
                      child: servers.isEmpty
                          ? _NoResults(query: _query)
                          : GridView.builder(
                              padding: const EdgeInsets.only(bottom: 8),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 156, mainAxisExtent: 128, crossAxisSpacing: 8, mainAxisSpacing: 8),
                              itemCount: servers.length,
                              itemBuilder: (context, i) => _ServerTile(server: servers[i], sub: sub, grid: true),
                            ),
                    ),
                  ],
                );
              }),
            ),
          ],
        );
        }
        if (widget.shrinkWrap) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              for (final s in servers) _ServerTile(server: s, sub: sub, roomy: true),
              if (servers.isEmpty) _NoResults(query: _query),
            ],
          );
        }
        final compact = app.settings.get(K.compactList);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(
              child: servers.isEmpty
                  ? _NoResults(query: _query)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemExtent: compact ? 46 : 58,
                      itemCount: servers.length,
                      itemBuilder: (context, i) => _ServerTile(server: servers[i], sub: sub),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          query.isEmpty ? tr('Список серверов пуст', 'No servers') : tr('Ничего не найдено', 'Nothing found'),
          textAlign: TextAlign.center,
          style: context.tt.bodySmall,
        ),
      );
}

class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.sub});

  final Subscription sub;

  Future<void> _menu(BuildContext context) async {
    final app = context.app;
    final box = context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset(box.size.width - 8, box.size.height));
    final v = await showContextMenuAt<String>(context, pos, [
      menuItem(context, 'rename', Icons.edit_outlined, tr('Переименовать', 'Rename')),
      if (!sub.isManual) menuItem(context, 'url', Icons.link_rounded, tr('Изменить ссылку', 'Edit URL')),
      if (!sub.isManual) menuItem(context, 'copy', Icons.copy_rounded, tr('Копировать ссылку', 'Copy URL')),
      if (!sub.isManual)
        menuItem(context, 'auto', sub.autoUpdate ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, tr('Автообновление', 'Auto-update')),
      if (sub.webPage != null) menuItem(context, 'web', Icons.open_in_new_rounded, tr('Личный кабинет', 'Account page')),
      const PopupMenuDivider(height: 8),
      menuItem(context, 'delete', Icons.delete_outline_rounded, tr('Удалить', 'Delete'), danger: true),
    ]);
    if (!context.mounted || v == null) return;
    switch (v) {
      case 'rename':
        final name = await showTextInput(context, title: tr('Название подписки', 'Subscription name'), initial: sub.name);
        if (name != null) app.subs.rename(sub.id, name);
      case 'url':
        final url = await showTextInput(context, title: tr('Ссылка на подписку', 'Subscription URL'), initial: sub.url ?? '');
        if (url != null && url.trim().isNotEmpty) {
          app.subs.setUrl(sub.id, url);
          await app.subs.update(sub.id);
        }
      case 'copy':
        await app.copy(sub.url ?? '');
        if (context.mounted) showToast(context, tr('Ссылка скопирована', 'Link copied'));
      case 'auto':
        app.subs.setAutoUpdate(sub.id, !sub.autoUpdate);
      case 'web':
        await app.openUrl(sub.webPage!);
      case 'delete':
        final ok = await showConfirm(context,
            title: tr('Удалить подписку?', 'Delete subscription?'), message: tr('«${sub.name}» и все её серверы будут удалены.', '"${sub.name}" and all its servers will be removed.'), destructive: true);
        if (ok) app.subs.remove(sub.id);
    }
  }

  Future<void> _pickSub(BuildContext context) async {
    final app = context.app;
    final box = context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset(0, box.size.height));
    final v = await showContextMenuAt<String>(context, pos, [
      for (final s in app.subs.subs)
        PopupMenuItem(
          value: s.id,
          height: 38,
          child: Row(children: [
            Icon(s.id == sub.id ? Icons.check_rounded : Icons.layers_outlined, size: 16, color: s.id == sub.id ? context.c.accent : context.c.textSec),
            const SizedBox(width: 10),
            Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 10),
            Text('${s.servers.length}', style: context.tt.labelMedium),
          ]),
        ),
      const PopupMenuDivider(height: 8),
      menuItem(context, '+', Icons.add_rounded, tr('Добавить подписку', 'Add subscription')),
    ]);
    if (v == null) return;
    if (v == '+') {
      app.page.value = 'add';
    } else {
      app.subs.select(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final updating = app.subs.updating.contains(sub.id);
    final pinging = app.subs.pinging.contains(sub.id);
    return Row(
      children: [
        Expanded(
          child: Builder(
            builder: (ctx) => Pressable(
              onTap: () => _pickSub(ctx),
              radius: Radii.md,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Flexible(child: Text(sub.name, style: context.tt.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 4),
                  Icon(Icons.unfold_more_rounded, size: 16, color: c.textTer),
                ],
              ),
            ),
          ),
        ),
        if (!sub.isManual) ...[
          const SizedBox(width: 8),
          IconBtn(
            icon: Icons.refresh_rounded,
            tooltip: tr('Обновить подписку', 'Update subscription'),
            spinning: updating,
            onTap: updating
                ? null
                : () async {
                    await app.subs.update(sub.id);
                    if (!context.mounted) return;
                    final s = app.subs.subs.where((x) => x.id == sub.id).firstOrNull;
                    if (s?.lastError != null) {
                      showToast(context, s!.lastError!, error: true);
                    } else {
                      showToast(context, tr('Подписка обновлена', 'Subscription updated'));
                    }
                  },
          ),
        ],
        const SizedBox(width: 8),
        IconBtn(
          icon: Icons.speed_rounded,
          tooltip: tr('Проверить пинг', 'Test latency'),
          spinning: pinging,
          onTap: pinging ? null : () => app.subs.pingSub(sub.id),
        ),
        const SizedBox(width: 8),
        Builder(builder: (ctx) => IconBtn(icon: Icons.more_horiz_rounded, tooltip: tr('Настройки подписки', 'Subscription settings'), onTap: () => _menu(ctx))),
      ],
    );
  }
}

class _SubInfo extends StatelessWidget {
  const _SubInfo({required this.sub});

  final Subscription sub;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final app = context.app;
    final frac = sub.usedFraction;
    final small = context.tt.bodySmall;
    final barColor = frac == null ? c.accent : (frac > 0.9 ? c.danger : (frac > 0.75 ? c.warning : c.accent));

    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _Meta(icon: Icons.event_outlined, text: '${tr('Добавлена', 'Added')} ${Fmt.date(sub.addedAt)}'),
              if (!sub.isManual)
                _Meta(
                  icon: sub.lastError != null ? Icons.sync_problem_rounded : Icons.sync_rounded,
                  text: '${tr('Обновлена', 'Updated')} ${Fmt.ago(sub.updatedAt)}',
                  color: sub.lastError != null ? c.danger : null,
                ),
              _Meta(icon: Icons.dns_outlined, text: tr('${sub.servers.length} серв.', '${sub.servers.length} servers')),
            ],
          ),
          if (sub.hasTraffic || sub.expire != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    sub.total > 0 ? '${Fmt.bytes(sub.used)} ${tr('из', 'of')} ${Fmt.bytes(sub.total)}' : '${Fmt.bytes(sub.used)} ${tr('использовано', 'used')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.tt.labelLarge,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    sub.total > 0 ? '${tr('Осталось', 'Left')} ${Fmt.bytes(sub.remaining!)}' : tr('Безлимит', 'Unlimited'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: small,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: frac ?? (sub.total == 0 && sub.used > 0 ? 1 : 0)),
                duration: Motion.slow,
                curve: Motion.curve,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 4,
                  color: frac == null ? c.success.withValues(alpha: 0.6) : barColor,
                  backgroundColor: c.surfaceHi,
                ),
              ),
            ),
            if (sub.expire != null) ...[
              const SizedBox(height: 8),
              Text(
                '${tr('Действует до', 'Valid until')} ${Fmt.date(sub.expire!)} · ${Fmt.daysLeft(sub.expire!)}',
                style: small?.copyWith(color: sub.expire!.difference(DateTime.now()).inDays < 3 ? c.warning : null),
              ),
            ],
          ],
          if (sub.announce != null && sub.announce!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(Radii.md)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.campaign_outlined, size: 16, color: c.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(sub.announce!.trim(), style: small?.copyWith(color: c.text), maxLines: 5, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ],
          if (sub.links.isNotEmpty || sub.webPage != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final l in sub.links)
                  ChipButton(
                    label: l.title,
                    icon: switch (l.kind) {
                      LinkKind.telegram => Icons.send_rounded,
                      LinkKind.support => Icons.support_agent_rounded,
                      LinkKind.web => Icons.open_in_new_rounded,
                      LinkKind.custom => Icons.link_rounded,
                    },
                    onTap: () => app.openUrl(l.url),
                  ),
                if (sub.webPage != null) ChipButton(label: tr('Кабинет', 'Account'), icon: Icons.person_outline_rounded, onTap: () => app.openUrl(sub.webPage!)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final col = color ?? context.c.textSec;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: col),
      const SizedBox(width: 5),
      Text(text, style: context.tt.bodySmall?.copyWith(color: col)),
    ]);
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.controller, required this.onChanged, required this.count});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int count;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final sort = app.settings.get(K.sortBy);
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: context.tt.bodyMedium,
              decoration: InputDecoration(
                hintText: tr('Поиск серверов', 'Search servers'),
                prefixIcon: Icon(Icons.search_rounded, size: 17, color: c.textTer),
                prefixIconConstraints: const BoxConstraints(minWidth: 40),
                contentPadding: const EdgeInsets.fromLTRB(0, 10, 14, 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Builder(
          builder: (ctx) => IconBtn(
            icon: Icons.sort_rounded,
            size: 36,
            selected: sort != 'none',
            tooltip: tr('Сортировка', 'Sort'),
            onTap: () async {
              final box = ctx.findRenderObject() as RenderBox;
              final v = await showContextMenuAt<String>(ctx, box.localToGlobal(Offset(0, box.size.height)), [
                for (final (k, l) in [('none', tr('Как в подписке', 'Subscription order')), ('ping', tr('По пингу', 'By latency')), ('name', tr('По имени', 'By name'))])
                  menuItem(ctx, k, sort == k ? Icons.check_rounded : Icons.circle_outlined, l),
              ]);
              if (v != null) app.settings.set(K.sortBy, v);
            },
          ),
        ),
      ],
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({required this.server, required this.sub, this.roomy = false, this.grid = false});

  final ServerProfile server;
  final Subscription sub;

  /// Not inside a fixed-extent list, so the tile sets its own height.
  final bool roomy;

  final bool grid;

  Future<void> _context(BuildContext context, Offset pos) async {
    final app = context.app;
    final v = await showContextMenuAt<String>(context, pos, [
      menuItem(context, 'connect', Icons.power_settings_new_rounded, tr('Подключиться', 'Connect')),
      menuItem(context, 'ping', Icons.speed_rounded, tr('Проверить пинг', 'Test latency')),
      menuItem(context, 'rename', Icons.edit_outlined, tr('Переименовать', 'Rename')),
      if (server.rawUri != null) menuItem(context, 'copy', Icons.copy_rounded, tr('Копировать ключ', 'Copy key')),
      menuItem(context, 'info', Icons.info_outline_rounded, tr('Подробности', 'Details')),
      if (sub.isManual) ...[
        const PopupMenuDivider(height: 8),
        menuItem(context, 'delete', Icons.delete_outline_rounded, tr('Удалить', 'Delete'), danger: true),
      ],
    ]);
    if (!context.mounted || v == null) return;
    switch (v) {
      case 'connect':
        await app.selectServer(server.id);
        if (!app.conn.isConnected) await app.conn.connect();
      case 'ping':
        await app.subs.pingServer(server);
      case 'rename':
        final name = await showTextInput(context, title: tr('Название сервера', 'Server name'), initial: server.name);
        if (name != null) app.subs.renameServer(server.id, name);
      case 'copy':
        await app.copy(server.rawUri!);
        if (context.mounted) showToast(context, tr('Ключ скопирован', 'Key copied'));
      case 'info':
        _details(context);
      case 'delete':
        final ok = await showConfirm(context, title: tr('Удалить сервер?', 'Delete server?'), message: server.name, destructive: true);
        if (ok) app.subs.removeServer(server.id);
    }
  }

  void _details(BuildContext context) {
    final mask = context.app.settings.get(K.maskAddresses);
    String addr(String a) => mask && a.length > 4 ? '${a.substring(0, 2)}••••${a.substring(a.length - 2)}' : a;
    final rows = <(String, String)>[
      (tr('Протокол', 'Protocol'), server.protocolLabel),
      (tr('Транспорт', 'Transport'), server.transportLabel),
      (tr('Адрес', 'Address'), '${addr(server.address)}:${server.port}'),
      (tr('Страна', 'Country'), Geo.countryName(server.countryCode, ru: L10n.isRu) ?? '—'),
      (tr('Пинг', 'Latency'), server.ping == null ? '—' : (server.ping! < 0 ? tr('недоступен', 'unreachable') : '${server.ping} ms')),
    ];
    showInfoDialog(
      context,
      title: Geo.cleanName(server.name),
      width: 420,
      content: Column(
        children: [
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                SizedBox(width: 110, child: Text(k, style: context.tt.bodySmall)),
                Expanded(child: SelectableText(v, style: context.tt.bodyMedium)),
              ]),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final c = context.c;
    final selected = app.subs.selectedServer?.id == server.id;
    final active = selected && app.conn.status == ConnStatus.connected;
    final compact = app.settings.get(K.compactList);
    final showFlags = app.settings.get(K.showFlags);
    if (grid) {
      return Pressable(
        onTap: () => app.selectServer(server.id),
        onSecondaryTapAt: (p) => _context(context, p),
        onLongPress: () {
          final box = context.findRenderObject() as RenderBox;
          _context(context, box.localToGlobal(box.size.center(Offset.zero)));
        },
        selected: selected,
        selectedColor: c.accent.withValues(alpha: active ? 0.16 : 0.1),
        color: selected ? null : c.surfaceHi,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showFlags) FlagIcon(server.countryCode, size: 28),
            if (showFlags) const SizedBox(height: 8),
            Text(Geo.cleanName(server.name), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: context.tt.labelLarge?.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
            const SizedBox(height: 4),
            PingBadge(ping: server.ping, loading: app.subs.pinging.contains(sub.id), udp: server.isUdp),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Pressable(
        onTap: () => app.selectServer(server.id),
        onSecondaryTapAt: (p) => _context(context, p),
        onLongPress: () {
          final box = context.findRenderObject() as RenderBox;
          _context(context, box.localToGlobal(box.size.center(Offset.zero)));
        },
        selected: selected,
        selectedColor: c.accent.withValues(alpha: active ? 0.16 : 0.1),
        border: Border.all(color: selected && !c.glassStyle ? c.accent.withValues(alpha: active ? 0.45 : 0.28) : Colors.transparent),
        radius: c.glassStyle ? 16 : Radii.md,
        padding: EdgeInsets.symmetric(horizontal: roomy ? 14 : 10, vertical: roomy ? (compact ? 10 : 12) : 0),
        child: Row(
          children: [
            if (showFlags) ...[FlagIcon(server.countryCode, size: compact ? 20 : 26), const SizedBox(width: 11)],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Geo.cleanName(server.name),
                    style: context.tt.titleSmall?.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!compact && app.settings.get(K.showProtocol)) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${server.protocolLabel} · ${server.transportLabel}',
                      style: context.tt.bodySmall?.copyWith(fontSize: 11.5, color: c.textTer),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            PingBadge(ping: server.ping, loading: app.subs.pinging.contains(sub.id), udp: server.isUdp),
          ],
        ),
      ),
    );
  }
}
