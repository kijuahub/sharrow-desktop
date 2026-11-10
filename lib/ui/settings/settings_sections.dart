import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/brand.dart';
import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/platform.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/models/settings.dart';
import '../../data/storage/paths.dart';
import '../../modules/routing/routing_profile.dart';
import '../../modules/system/privileges.dart';
import '../../modules/xray/core_locator.dart';
import '../../state/scope.dart';
import '../../state/settings_controller.dart';
import '../widgets/buttons.dart';
import '../widgets/feedback.dart';
import '../widgets/pressable.dart';
import 'app_routing.dart';
import 'settings_widgets.dart';

class SettingsCategory {
  const SettingsCategory(this.id, this.icon, this.ru, this.en, this.builder);

  final String id;
  final IconData icon;
  final String ru;
  final String en;
  final List<Widget> Function(BuildContext context) builder;

  String get title => tr(ru, en);
}

final kSettingsCategories = <SettingsCategory>[
  SettingsCategory('personal', Icons.person_outline_rounded, 'Персонализация', 'Personalization', _personal),
  SettingsCategory('appearance', Icons.palette_outlined, 'Внешний вид', 'Appearance', _appearance),
  SettingsCategory('connection', Icons.power_settings_new_rounded, 'Подключение', 'Connection', _connection),
  SettingsCategory('servers', Icons.dns_outlined, 'Серверы', 'Servers', _servers),
  SettingsCategory('routing', Icons.alt_route_rounded, 'Маршрутизация', 'Routing', _routing),
  SettingsCategory('dns', Icons.travel_explore_rounded, 'DNS', 'DNS', _dns),
  SettingsCategory('ping', Icons.speed_rounded, 'Ping', 'Ping', _ping),
  SettingsCategory('tun', Icons.lan_outlined, 'TUN', 'TUN', _tun),
  SettingsCategory('proxy', Icons.swap_horiz_rounded, 'Proxy', 'Proxy', _proxy),
  SettingsCategory('xray', Icons.memory_rounded, 'Xray', 'Xray', _xray),
  SettingsCategory('subs', Icons.layers_outlined, 'Подписки', 'Subscriptions', _subscriptions),
  SettingsCategory('updates', Icons.system_update_alt_rounded, 'Обновления', 'Updates', _updates),
  SettingsCategory('logs', Icons.receipt_long_outlined, 'Логи', 'Logs', _logs),
  SettingsCategory('notifications', Icons.notifications_none_rounded, 'Уведомления', 'Notifications', _notifications),
  SettingsCategory('system', Icons.desktop_windows_outlined, 'Система', 'System', _system),
  SettingsCategory('autostart', Icons.rocket_launch_outlined, 'Автозапуск', 'Autostart', _autostart),
  SettingsCategory('network', Icons.wifi_rounded, 'Сеть', 'Network', _network),
  SettingsCategory('privacy', Icons.shield_outlined, 'Конфиденциальность', 'Privacy', _privacy),
  SettingsCategory('advanced', Icons.code_rounded, 'Дополнительно', 'Advanced', _advanced),
  SettingsCategory('about', Icons.info_outline_rounded, 'О программе', 'About', _about),
];

String? _validateJson(String v) {
  if (v.trim().isEmpty) return null;
  try {
    final d = jsonDecode(v);
    return d is Map ? null : tr('Ожидается JSON-объект', 'JSON object expected');
  } catch (e) {
    return tr('Некорректный JSON', 'Invalid JSON');
  }
}

String? _validateRange(String v) => RegExp(r'^\d+(-\d+)?$').hasMatch(v) ? null : tr('Формат: 10-20', 'Format: 10-20');

List<Widget> _personal(BuildContext context) => [
      SettingsGroup(title: tr('Язык и запуск', 'Language & start'), children: [
        ChoiceTile(K.language, title: tr('Язык интерфейса', 'Interface language'), options: {'system': tr('Системный', 'System'), 'ru': 'Русский', 'en': 'English'}),
        ChoiceTile(K.startPage, title: tr('Стартовый раздел', 'Start page'), options: {'servers': tr('Серверы', 'Servers'), 'last': tr('Последний', 'Last used')}),
      ]),
      SettingsGroup(title: tr('Список серверов', 'Server list'), children: [
        SwitchTile(K.showFlags, title: tr('Флаги стран', 'Country flags')),
        SwitchTile(K.showProtocol, title: tr('Протокол и транспорт', 'Protocol and transport'), subtitle: tr('Показывать строку «VLESS · TCP · Reality»', 'Show "VLESS · TCP · Reality" line')),
        SwitchTile(K.compactList, title: tr('Компактный список', 'Compact list')),
      ]),
      SettingsGroup(title: tr('Подключение', 'Connection'), children: [
        SwitchTile(K.showSpeed, title: tr('Скорость и задержка', 'Speed and latency'), subtitle: tr('Показывать текущую скорость при подключении', 'Show live speed while connected')),
        SwitchTile(K.confirmDisconnect, title: tr('Подтверждать отключение', 'Confirm disconnect')),
      ]),
    ];

List<Widget> _appearance(BuildContext context) => [
      SettingsGroup(title: tr('Тема', 'Theme'), children: [
        ChoiceTile(K.themeMode, title: tr('Оформление', 'Appearance'), segmented: true, options: {
          'dark': tr('Тёмная', 'Dark'),
          'black': tr('Чёрная', 'Black'),
          'light': tr('Светлая', 'Light'),
          'system': tr('Авто', 'Auto'),
        }),
        const AccentTile(),
        ChoiceTile(K.font, title: tr('Шрифт', 'Font'), options: const {'inter': 'Inter', 'onest': 'Onest'}),
        SwitchTile(K.glass, title: tr('Эффект стекла', 'Glass effect'), subtitle: tr('Размытие под плавающими панелями', 'Blur behind floating panels')),
        SliderTile(K.textScale, title: tr('Размер текста', 'Text size'), min: 0.85, max: 1.25, divisions: 8, format: (v) => '${(v * 100).round()}%'),
      ]),
      SettingsGroup(title: tr('Планета', 'Globe'), children: [
        SwitchTile(K.globe, title: tr('Показывать планету', 'Show globe')),
        SwitchTile(K.globeRotation, title: tr('Вращение', 'Rotation'), enabled: context.app.settings.get(K.globe)),
        SliderTile(K.globeSpeed, title: tr('Скорость вращения', 'Rotation speed'), min: 0.25, max: 3, divisions: 11, format: (v) => '×${v.toStringAsFixed(2)}', enabled: context.app.settings.get(K.globe)),
      ]),
      SettingsGroup(
        title: tr('Анимации и производительность', 'Animations & performance'),
        footer: tr('Режим 30 FPS заметно снижает нагрузку на GPU/CPU на слабых устройствах.', '30 FPS mode noticeably reduces GPU/CPU load on low-end devices.'),
        children: [
          SwitchTile(K.animations, title: tr('Анимации интерфейса', 'Interface animations')),
          SwitchTile(K.lowFps, title: tr('Экономичный режим (30 FPS)', 'Battery saver (30 FPS)')),
        ],
      ),
    ];

List<Widget> _connection(BuildContext context) => [
      SettingsGroup(title: tr('Режим', 'Mode'), children: [
        ChoiceTile(K.defaultMode, title: tr('Режим по умолчанию', 'Default mode'), subtitle: tr('Используется для автоподключения', 'Used for auto-connect'), options: const {'proxy': 'Proxy', 'tun': 'TUN'}),
      ]),
      SettingsGroup(title: tr('Автоматизация', 'Automation'), children: [
        SwitchTile(K.autoConnect, title: tr('Подключаться при запуске', 'Connect on launch')),
        SwitchTile(K.restoreConnection, title: tr('Восстанавливать подключение', 'Restore connection'), subtitle: tr('Переподключиться, если VPN был включён при закрытии', 'Reconnect if VPN was on when the app closed')),
        SwitchTile(K.reconnect, title: tr('Автопереподключение', 'Auto-reconnect'), subtitle: tr('При неожиданном разрыве или сбое ядра', 'On unexpected drop or core crash')),
        NumberTile(K.reconnectAttempts, title: tr('Попыток переподключения', 'Reconnect attempts'), min: 1, max: 20, enabled: context.app.settings.get(K.reconnect)),
        NumberTile(K.connectTimeout, title: tr('Таймаут подключения', 'Connect timeout'), min: 5, max: 60, suffix: tr('с', 's')),
      ]),
    ];

List<Widget> _servers(BuildContext context) => [
      SettingsGroup(title: tr('Выбор сервера', 'Server selection'), children: [
        SwitchTile(K.autoSelectFastest, title: tr('Автовыбор быстрого сервера', 'Auto-select fastest server'), subtitle: tr('Перед подключением проверить пинг и выбрать лучший', 'Ping and pick the best before connecting')),
        SwitchTile(K.pingAfterUpdate, title: tr('Пинг после обновления подписки', 'Ping after subscription update')),
      ]),
      SettingsGroup(title: tr('Отображение', 'Display'), children: [
        ChoiceTile(K.sortBy, title: tr('Сортировка', 'Sorting'), options: {'none': tr('Как в подписке', 'As provided'), 'ping': tr('По пингу', 'By latency'), 'name': tr('По имени', 'By name')}, segmented: false),
        SwitchTile(K.hideUnreachable, title: tr('Скрывать недоступные', 'Hide unreachable')),
      ]),
    ];

List<Widget> _routing(BuildContext context) {
  final app = context.app;
  final s = app.settings;
  final rules = s.get(K.routingMode) == 'rules';
  final server = app.subs.selectedServer;
  final profile = server == null ? null : app.subs.subOf(server.id)?.routing;
  final profileName = profile == null ? null : RoutingProfile(profile).name;
  return [
    SettingsGroup(
      title: tr('Профиль из подписки', 'Subscription profile'),
      footer: tr(
        'Провайдер может прислать профиль маршрутизации (как в Happ): какие сайты идут через VPN, какие напрямую, DNS и свои geo-базы. Пока он активен, режим и списки ниже не применяются; блокировка QUIC, приложения и Telegram — применяются.',
        'The provider may send a routing profile (Happ format): which sites go via VPN or direct, DNS and its own geo databases. While active, the mode and lists below are ignored; QUIC blocking, apps and Telegram still apply.',
      ),
      children: [
        SwitchTile(K.subRouting, title: tr('Использовать профиль провайдера', 'Use provider profile')),
        InfoTile(
          title: tr('Текущий профиль', 'Current profile'),
          value: profileName ?? (server?.fullConfig != null ? tr('из JSON-конфига', 'from JSON config') : tr('не прислан', 'not provided')),
        ),
      ],
    ),
    SettingsGroup(title: tr('Режим маршрутизации', 'Routing mode'), children: [
      ChoiceTile(K.routingMode, title: tr('Режим', 'Mode'), options: {'global': tr('Глобальный', 'Global'), 'rules': tr('По правилам', 'Rules')}),
      ChoiceTile(K.bypassPreset, title: tr('Прямое подключение для', 'Direct connection for'), enabled: rules, segmented: false, options: {
        'none': tr('Не использовать', 'None'),
        'ru': tr('Россия (домены .ru/.рф, GeoIP RU)', 'Russia (.ru domains, GeoIP RU)'),
        'cn': tr('Китай (GeoSite/GeoIP CN)', 'China (GeoSite/GeoIP CN)'),
        'ir': tr('Иран (GeoSite/GeoIP IR)', 'Iran (GeoSite/GeoIP IR)'),
      }),
      SwitchTile(K.bypassLan, title: tr('Локальная сеть напрямую', 'Bypass LAN'), subtitle: '10.0.0.0/8, 192.168.0.0/16, 172.16.0.0/12'),
      ChoiceTile(K.domainStrategy, title: tr('Стратегия доменов', 'Domain strategy'), segmented: false, options: const {
        'AsIs': 'AsIs',
        'IPIfNonMatch': 'IPIfNonMatch',
        'IPOnDemand': 'IPOnDemand',
      }),
    ]),
    SettingsGroup(title: tr('Блокировка', 'Blocking'), children: [
      SwitchTile(K.blockAds, title: tr('Блокировать рекламу', 'Block ads'), subtitle: 'geosite:category-ads-all'),
      SwitchTile(K.blockQuic, title: tr('Блокировать QUIC', 'Block QUIC'), subtitle: tr('UDP/443 — браузеры перейдут на TCP', 'UDP/443 — browsers fall back to TCP')),
      SwitchTile(K.telegramViaProxy, title: tr('Telegram всегда через VPN', 'Telegram always via VPN'), subtitle: tr('IP-адреса и домены Telegram не уходят напрямую', 'Telegram IPs and domains never go direct')),
    ]),
    SettingsGroup(
      title: tr('Свои правила', 'Custom rules'),
      footer: tr('Домены: example.com, *.example.com, geosite:google, full:, regexp:, keyword:. IP: 1.2.3.4, 10.0.0.0/8, geoip:us.',
          'Domains: example.com, *.example.com, geosite:google, full:, regexp:, keyword:. IPs: 1.2.3.4, 10.0.0.0/8, geoip:us.'),
      children: [
        ListEditTile(K.proxyList, title: tr('Через VPN', 'Via VPN'), hint: 'youtube.com\ngeosite:google'),
        ListEditTile(K.directList, title: tr('Напрямую', 'Direct'), hint: 'example.ru\n192.168.1.0/24'),
        ListEditTile(K.blockList, title: tr('Блокировать', 'Block'), hint: 'ads.example.com'),
      ],
    ),
    if (Plat.isDesktop) const AppRoutingGroup(),
  ];
}

List<Widget> _dns(BuildContext context) => [
      SettingsGroup(title: tr('Серверы', 'Servers'), children: [
        TextTile(K.remoteDns, title: tr('Удалённый DNS', 'Remote DNS'), subtitle: tr('Через VPN; поддерживается DoH/DoT', 'Via VPN; DoH/DoT supported'), hint: 'https://1.1.1.1/dns-query'),
        TextTile(K.directDns, title: tr('Прямой DNS', 'Direct DNS'), subtitle: tr('Для доменов, идущих напрямую', 'For direct domains'), hint: '8.8.8.8'),
        ChoiceTile(K.dnsStrategy, title: tr('Тип запросов', 'Query strategy'), options: const {'UseIP': 'IPv4+6', 'UseIPv4': 'IPv4', 'UseIPv6': 'IPv6'}),
      ]),
      SettingsGroup(title: tr('Поведение', 'Behaviour'), children: [
        SwitchTile(K.dnsCache, title: tr('Кэш DNS', 'DNS cache')),
        SwitchTile(K.fakeDns, title: 'FakeDNS', subtitle: tr('Только в режиме TUN: быстрее резолвинг, меньше утечек', 'TUN mode only: faster resolution, fewer leaks')),
        ListEditTile(K.dnsHosts, title: tr('Статические записи (hosts)', 'Static records (hosts)'), hint: 'example.com 1.2.3.4'),
      ]),
    ];

List<Widget> _ping(BuildContext context) => [
      SettingsGroup(title: tr('Проверка задержки', 'Latency test'), children: [
        NumberTile(K.pingTimeout, title: tr('Таймаут', 'Timeout'), min: 500, max: 10000, step: 500, suffix: 'ms'),
        NumberTile(K.pingConcurrency, title: tr('Параллельных проверок', 'Concurrent checks'), min: 1, max: 64),
        SwitchTile(K.pingOnStart, title: tr('Пинг при запуске', 'Ping on launch')),
        NumberTile(K.pingInterval, title: tr('Автопроверка каждые', 'Auto-check every'), subtitle: tr('0 — выключено', '0 — off'), min: 0, max: 120, step: 5, suffix: tr('мин', 'min')),
      ]),
      SettingsGroup(
        title: tr('Реальная задержка', 'Real delay'),
        footer: tr('Для активного сервера выполняется HTTP-запрос через туннель — это реальное время ответа.', 'For the active server an HTTP request is sent through the tunnel — real response time.'),
        children: [
          SwitchTile(K.realDelay, title: tr('Измерять через туннель', 'Measure through tunnel')),
          TextTile(K.pingTestUrl, title: tr('Тестовый URL', 'Test URL'), hint: 'https://www.gstatic.com/generate_204'),
        ],
      ),
    ];

List<Widget> _tun(BuildContext context) {
  return [
    if (Plat.isWindows)
      FutureBuilder<bool>(
        future: Privileges.isElevated(),
        builder: (context, snap) => snap.data == false
            ? SettingsGroup(children: [
                ActionTile(
                  title: tr('Нужны права администратора', 'Administrator rights required'),
                  subtitle: tr('Режим TUN создаёт виртуальный сетевой адаптер (Wintun).', 'TUN mode creates a virtual network adapter (Wintun).'),
                  label: tr('Перезапустить', 'Restart'),
                  icon: Icons.admin_panel_settings_outlined,
                  onTap: () => context.app.relaunchAsAdmin(),
                ),
              ])
            : const SizedBox.shrink(),
      ),
    SettingsGroup(title: tr('Интерфейс', 'Interface'), children: [
      TextTile(K.tunName, title: tr('Имя адаптера', 'Adapter name'), hint: 'sharrow0'),
      NumberTile(K.tunMtu, title: 'MTU', min: 1280, max: 9000, step: 10),
      TextTile(K.tunGateway, title: tr('Адрес интерфейса', 'Interface address'), hint: '172.19.0.1/30'),
      SwitchTile(K.tunIpv6, title: 'IPv6', subtitle: tr('Направлять IPv6-трафик в туннель', 'Route IPv6 traffic through the tunnel')),
    ]),
    SettingsGroup(title: tr('Маршруты и защита', 'Routes & protection'), children: [
      SwitchTile(K.tunAutoRoute, title: tr('Автоматические маршруты', 'Automatic routes'), subtitle: tr('Весь трафик системы через туннель', 'All system traffic via tunnel')),
      SwitchTile(K.tunDnsHijack, title: tr('Перехват DNS', 'DNS hijack'), subtitle: tr('Запросы на порт 53 обрабатывает Xray', 'Port 53 queries handled by Xray')),
      if (Plat.isWindows) SwitchTile(K.tunStrict, title: tr('Защита от утечек', 'Leak protection'), subtitle: tr('Блокировать DNS-утечки через WFP', 'Block DNS leaks via WFP')),
    ]),
  ];
}

List<Widget> _proxy(BuildContext context) {
  final s = context.app.settings;
  return [
    SettingsGroup(title: tr('Локальные порты', 'Local ports'), children: [
      NumberTile(K.socksPort, title: 'SOCKS5', min: 1024, max: 65535),
      SwitchTile(K.httpInbound, title: tr('HTTP-прокси', 'HTTP proxy')),
      NumberTile(K.httpPort, title: 'HTTP', min: 1024, max: 65535, enabled: s.get(K.httpInbound)),
      SwitchTile(K.allowLan, title: tr('Доступ из локальной сети', 'Allow LAN connections'), subtitle: tr('Слушать 0.0.0.0 — другие устройства смогут использовать прокси', 'Listen on 0.0.0.0 — other devices can use the proxy')),
    ]),
    if (Plat.isDesktop)
      SettingsGroup(
        title: tr('Системный прокси', 'System proxy'),
        footer: tr(
          'Системный прокси используют браузеры и большинство программ. Telegram, игры и многие мессенджеры его игнорируют — для них включите режим TUN или пропишите прокси в самом приложении.',
          'Browsers and most apps use the system proxy. Telegram, games and many messengers ignore it — use TUN mode or set the proxy inside the app.',
        ),
        children: [
          SwitchTile(K.setSystemProxy, title: tr('Настраивать системный прокси', 'Set system proxy'), subtitle: tr('В режиме Proxy', 'In Proxy mode')),
          TextTile(K.proxyBypass, title: tr('Исключения', 'Bypass list'), wide: true, mono: true, enabled: s.get(K.setSystemProxy)),
          ActionTile(
            title: tr('Подключить Telegram', 'Set up Telegram'),
            subtitle: tr('Добавит SOCKS5 127.0.0.1:${s.get(K.socksPort)} в Telegram', 'Adds SOCKS5 127.0.0.1:${s.get(K.socksPort)} to Telegram'),
            label: tr('Открыть', 'Open'),
            icon: Icons.send_rounded,
            onTap: () => context.app.openUrl(telegramProxyLink(s)),
          ),
        ],
      ),
    SettingsGroup(title: tr('Аутентификация', 'Authentication'), children: [
      SwitchTile(K.proxyAuth, title: tr('Требовать пароль', 'Require password')),
      TextTile(K.proxyUser, title: tr('Пользователь', 'Username'), enabled: s.get(K.proxyAuth)),
      TextTile(K.proxyPass, title: tr('Пароль', 'Password'), obscure: true, enabled: s.get(K.proxyAuth)),
    ]),
  ];
}

String telegramProxyLink(SettingsController s) => Uri(
      scheme: 'tg',
      host: 'socks',
      queryParameters: {
        'server': '127.0.0.1',
        'port': '${s.get(K.socksPort)}',
        if (s.get(K.proxyAuth) && s.get(K.proxyPass).isNotEmpty) ...{'user': s.get(K.proxyUser), 'pass': s.get(K.proxyPass)},
      },
    ).toString();

List<Widget> _xray(BuildContext context) {
  final app = context.app;
  final s = app.settings;
  return [
    SettingsGroup(title: tr('Ядро', 'Core'), children: [
      InfoTile(title: tr('Версия', 'Version'), value: app.coreVersion != null ? 'Xray ${app.coreVersion}' : tr('не установлено', 'not installed')),
      if (Plat.isDesktop) ...[
        ListenableBuilder(
          listenable: app.installer,
          builder: (context, _) => ActionTile(
            title: tr('Установить / обновить ядро', 'Install / update core'),
            subtitle: app.installer.busy ? app.installer.stage : tr('Последний релиз XTLS/Xray-core', 'Latest XTLS/Xray-core release'),
            label: tr('Обновить', 'Update'),
            icon: Icons.download_rounded,
            loading: app.installer.busy,
            onTap: () async {
              final err = await app.installCore();
              if (context.mounted) showToast(context, err ?? tr('Ядро обновлено: ${app.coreVersion}', 'Core updated: ${app.coreVersion}'), error: err != null);
            },
          ),
        ),
        TextTile(K.customCorePath, title: tr('Свой путь к xray', 'Custom xray path'), hint: CoreLocator.defaultBinary, wide: true, mono: true),
      ],
    ]),
    SettingsGroup(title: tr('Логирование', 'Logging'), children: [
      ChoiceTile(K.logLevel, title: tr('Уровень логов ядра', 'Core log level'), segmented: false, options: const {
        'none': 'none',
        'error': 'error',
        'warning': 'warning',
        'info': 'info',
        'debug': 'debug',
      }),
      SwitchTile(K.accessLog, title: tr('Журнал соединений', 'Access log')),
    ]),
    SettingsGroup(title: 'Sniffing & Mux', children: [
      SwitchTile(K.sniffing, title: 'Sniffing', subtitle: tr('Определять домены по TLS/HTTP для правил', 'Detect domains from TLS/HTTP for routing')),
      SwitchTile(K.sniffRouteOnly, title: tr('Только для маршрутизации', 'Route only'), enabled: s.get(K.sniffing)),
      SwitchTile(K.mux, title: 'Mux', subtitle: tr('Мультиплексирование (несовместимо с XTLS Vision)', 'Multiplexing (incompatible with XTLS Vision)')),
      NumberTile(K.muxConcurrency, title: tr('Потоков Mux', 'Mux concurrency'), min: 1, max: 128, enabled: s.get(K.mux)),
    ]),
    SettingsGroup(
      title: tr('Фрагментация TLS', 'TLS fragmentation'),
      footer: tr('Помогает обходить DPI, который анализирует ClientHello.', 'Helps bypass DPI that inspects ClientHello.'),
      children: [
        SwitchTile(K.fragment, title: tr('Фрагментировать TLS Hello', 'Fragment TLS Hello')),
        ChoiceTile(K.fragmentPackets, title: tr('Пакеты', 'Packets'), enabled: s.get(K.fragment), options: const {'tlshello': 'tlshello', '1-3': '1-3', '1-5': '1-5'}),
        TextTile(K.fragmentLength, title: tr('Длина фрагмента', 'Fragment length'), hint: '100-200', validator: _validateRange, enabled: s.get(K.fragment)),
        TextTile(K.fragmentInterval, title: tr('Интервал, мс', 'Interval, ms'), hint: '10-20', validator: _validateRange, enabled: s.get(K.fragment)),
      ],
    ),
  ];
}

List<Widget> _subscriptions(BuildContext context) {
  final app = context.app;
  final s = app.settings;
  return [
    SettingsGroup(title: tr('Автообновление', 'Auto-update'), children: [
      SwitchTile(K.subAutoUpdate, title: tr('Обновлять автоматически', 'Update automatically')),
      NumberTile(K.subInterval, title: tr('Интервал', 'Interval'), min: 1, max: 168, suffix: tr('ч', 'h'), enabled: s.get(K.subAutoUpdate)),
      SwitchTile(K.subRespectProvider, title: tr('Интервал провайдера', 'Provider interval'), subtitle: tr('Использовать profile-update-interval, если задан', 'Use profile-update-interval if provided')),
      SwitchTile(K.subUpdateOnStart, title: tr('Обновлять при запуске', 'Update on launch')),
    ]),
    SettingsGroup(
      title: tr('Формат', 'Format'),
      footer: tr(
        'Xray JSON — готовые конфиги провайдера со всеми протоколами (в т.ч. Hysteria2), балансировкой и профилем маршрутизации, как в Happ. Ссылки — классический список vless://, hy2:// и т.д. Обновите подписку после смены.',
        'Xray JSON — provider-made configs with every protocol (incl. Hysteria2), balancers and the routing profile, like Happ. Links — the classic vless://, hy2:// list. Refresh the subscription after switching.',
      ),
      children: [
        ChoiceTile(K.subFormat, title: tr('Запрашивать', 'Request'), options: {'json': 'Xray JSON', 'links': tr('Ссылки', 'Links')}),
      ],
    ),
    SettingsGroup(title: tr('Запросы', 'Requests'), children: [
      TextTile(K.subUserAgent, title: 'User-Agent', subtitle: tr('Пусто — по формату', 'Empty — by format'), hint: s.get(K.subFormat) == 'links' ? Brand.userAgentLinks : Brand.userAgentJson),
      NumberTile(K.subTimeout, title: tr('Таймаут', 'Timeout'), min: 5, max: 120, step: 5, suffix: tr('с', 's')),
      SwitchTile(K.subViaProxy, title: tr('Через активный VPN', 'Via active VPN'), subtitle: tr('Если подписка блокируется', 'If the subscription URL is blocked')),
    ]),
    SettingsGroup(
      title: tr('Устройство', 'Device'),
      footer: tr(
        'Провайдер видит ID устройства, ОС и модель (заголовки x-hwid, x-device-os, x-ver-os, x-device-model) и может ограничивать число устройств на подписку. ID — хеш системного идентификатора, сам он не передаётся.',
        'The provider sees the device ID, OS and model (x-hwid, x-device-os, x-ver-os, x-device-model headers) and may limit devices per subscription. The ID is a hash of the system identifier, which itself is never sent.',
      ),
      children: [
        SwitchTile(K.sendHwid, title: tr('Передавать ID устройства', 'Send device ID')),
        if (s.get(K.hwid).isNotEmpty)
          InfoTile(title: 'HWID', value: s.get(K.hwid), copyable: true)
        else
          FutureBuilder<String>(
            future: app.subs.hwid(),
            builder: (context, snap) => InfoTile(title: 'HWID', value: snap.data ?? '…', copyable: snap.hasData),
          ),
      ],
    ),
    ListenableBuilder(
      listenable: app.subs,
      builder: (context, _) => SettingsGroup(
        title: tr('Мои подписки', 'My subscriptions'),
        children: [
          if (app.subs.subs.isEmpty)
            InfoTile(title: tr('Подписок пока нет', 'No subscriptions yet'), value: ''),
          for (final sub in app.subs.subs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Icon(sub.isManual ? Icons.key_rounded : Icons.layers_outlined, size: 18, color: context.c.textSec),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sub.name, style: context.tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    Text(
                      '${sub.servers.length} ${tr('серв.', 'servers')} · ${sub.isManual ? tr('вручную', 'manual') : '${tr('обновлена', 'updated')} ${Fmt.ago(sub.updatedAt)}'}',
                      style: context.tt.bodySmall,
                    ),
                  ]),
                ),
                if (!sub.isManual)
                  Transform.scale(
                    scale: 0.75,
                    child: Tooltip(
                      message: tr('Автообновление', 'Auto-update'),
                      child: Switch(value: sub.autoUpdate, onChanged: (v) => app.subs.setAutoUpdate(sub.id, v)),
                    ),
                  ),
                if (!sub.isManual) IconBtn(icon: Icons.refresh_rounded, spinning: app.subs.updating.contains(sub.id), onTap: () => app.subs.update(sub.id)),
                IconBtn(
                  icon: Icons.delete_outline_rounded,
                  onTap: () async {
                    final ok = await showConfirm(context, title: tr('Удалить подписку?', 'Delete subscription?'), message: sub.name, destructive: true);
                    if (ok) app.subs.remove(sub.id);
                  },
                ),
              ]),
            ),
          ActionTile(
            title: tr('Обновить все', 'Update all'),
            label: tr('Обновить', 'Update'),
            icon: Icons.sync_rounded,
            loading: app.subs.updating.isNotEmpty,
            onTap: () => app.subs.updateAll(),
          ),
        ],
      ),
    ),
  ];
}

List<Widget> _updates(BuildContext context) {
  final app = context.app;
  final s = app.settings;
  final geoAt = s.get(K.geoUpdatedAt);
  return [
    SettingsGroup(title: tr('Приложение', 'Application'), children: [
      InfoTile(title: tr('Текущая версия', 'Current version'), value: app.appVersion),
      SwitchTile(K.checkAppUpdates, title: tr('Проверять обновления', 'Check for updates')),
      ChoiceTile(K.updateChannel, title: tr('Канал', 'Channel'), options: {'stable': tr('Стабильный', 'Stable'), 'beta': 'Beta'}),
      ActionTile(
        title: app.update != null ? '${tr('Доступна версия', 'Available')} ${app.update!.version}' : tr('Проверить сейчас', 'Check now'),
        label: app.update != null ? tr('Скачать', 'Download') : tr('Проверить', 'Check'),
        icon: app.update != null ? Icons.download_rounded : Icons.refresh_rounded,
        onTap: () async {
          if (app.update != null) return app.openUrl(app.update!.url);
          try {
            final u = await app.checkAppUpdate(throwErrors: true);
            if (context.mounted) showToast(context, u == null ? tr('Установлена последняя версия', 'You are up to date') : '${tr('Доступна', 'Available')} ${u.version}');
          } catch (_) {
            if (context.mounted) showToast(context, tr('Не удалось проверить обновления', 'Update check failed'), error: true);
          }
        },
      ),
    ]),
    if (Plat.isDesktop)
      SettingsGroup(title: tr('Ядро и базы маршрутизации', 'Core & routing databases'), children: [
        SwitchTile(K.autoUpdateCore, title: tr('Автообновление Xray', 'Auto-update Xray')),
        SwitchTile(K.autoUpdateGeo, title: tr('Автообновление geo-файлов', 'Auto-update geo files'), subtitle: tr('Раз в неделю', 'Weekly')),
        ChoiceTile(K.geoSource, title: tr('Источник geoip/geosite', 'geoip/geosite source'), segmented: false, options: const {
          'xray': 'Loyalsoldier',
          'runetfreedom': 'runetfreedom (RU)',
          'v2fly': 'v2fly',
        }),
        ListenableBuilder(
          listenable: app.installer,
          builder: (context, _) => ActionTile(
            title: tr('Обновить geo-файлы', 'Update geo files'),
            subtitle: geoAt == 0 ? null : '${tr('Обновлены', 'Updated')} ${Fmt.ago(DateTime.fromMillisecondsSinceEpoch(geoAt))}',
            label: tr('Обновить', 'Update'),
            icon: Icons.public_rounded,
            loading: app.installer.busy,
            onTap: () async {
              final err = await app.updateGeo();
              if (context.mounted) showToast(context, err ?? tr('Geo-файлы обновлены', 'Geo files updated'), error: err != null);
            },
          ),
        ),
        TextTile(K.githubMirror, title: tr('Зеркало GitHub', 'GitHub mirror'), subtitle: tr('Префикс для загрузок, если GitHub недоступен', 'Download prefix if GitHub is blocked'), hint: 'https://ghfast.top/'),
      ]),
  ];
}

List<Widget> _logs(BuildContext context) {
  final app = context.app;
  return [
    SettingsGroup(title: tr('Журнал', 'Journal'), children: [
      ChoiceTile(K.appLogLevel, title: tr('Уровень логов клиента', 'Client log level'), segmented: false, options: const {'debug': 'debug', 'info': 'info', 'warning': 'warning', 'error': 'error'}),
      NumberTile(K.logMaxLines, title: tr('Строк в памяти', 'Lines in memory'), min: 200, max: 20000, step: 200),
    ]),
    if (Plat.isDesktop)
      SettingsGroup(title: tr('Файлы', 'Files'), children: [
        SwitchTile(K.logToFile, title: tr('Сохранять в файл', 'Save to file')),
        NumberTile(K.logKeepDays, title: tr('Хранить', 'Keep for'), min: 1, max: 90, suffix: tr('дн.', 'd'), enabled: app.settings.get(K.logToFile)),
        ActionTile(title: tr('Папка логов', 'Logs folder'), subtitle: AppPaths.logs.path, label: tr('Открыть', 'Open'), icon: Icons.folder_open_rounded, onTap: () => app.openFolder(AppPaths.logs)),
      ]),
  ];
}

List<Widget> _notifications(BuildContext context) {
  final on = context.app.settings.get(K.notifications);
  return [
    SettingsGroup(children: [SwitchTile(K.notifications, title: tr('Уведомления', 'Notifications'))]),
    SettingsGroup(title: tr('События', 'Events'), children: [
      SwitchTile(K.notifyConnect, title: tr('Подключение', 'Connected'), enabled: on),
      SwitchTile(K.notifyDisconnect, title: tr('Отключение', 'Disconnected'), enabled: on),
      SwitchTile(K.notifyError, title: tr('Ошибки', 'Errors'), enabled: on),
      SwitchTile(K.notifySubUpdate, title: tr('Обновление подписок', 'Subscription updates'), enabled: on),
      SwitchTile(K.notifyLimits, title: tr('Окончание трафика и срока', 'Traffic and expiry warnings'), enabled: on),
    ]),
    SettingsGroup(children: [
      ActionTile(
        title: tr('Проверить уведомления', 'Test notification'),
        label: tr('Отправить', 'Send'),
        icon: Icons.notifications_active_outlined,
        onTap: () => context.app.notifications.show('Sharrow', tr('Уведомления работают', 'Notifications work')),
      ),
    ]),
  ];
}

List<Widget> _system(BuildContext context) => [
      if (Plat.isDesktop)
        SettingsGroup(title: tr('Трей и окно', 'Tray & window'), children: [
          SwitchTile(K.showTray, title: tr('Значок в трее', 'Tray icon')),
          SwitchTile(K.closeToTray, title: tr('Сворачивать в трей при закрытии', 'Minimize to tray on close'), enabled: context.app.settings.get(K.showTray)),
          ChoiceTile(K.trayClick, title: tr('Клик по значку', 'Tray icon click'), options: {'show': tr('Открыть', 'Open'), 'toggle': tr('Вкл/выкл', 'Toggle')}),
          SwitchTile(K.startMinimized, title: tr('Запускать свёрнутым', 'Start minimized')),
        ]),
      SettingsGroup(title: tr('Информация', 'Information'), children: [
        InfoTile(title: tr('Платформа', 'Platform'), value: Plat.name),
        InfoTile(title: tr('Папка данных', 'Data folder'), value: AppPaths.root.path, copyable: true),
        if (Plat.isDesktop)
          FutureBuilder<bool>(
            future: Privileges.isElevated(),
            builder: (context, snap) => InfoTile(title: tr('Права администратора', 'Administrator'), value: snap.data == true ? tr('Да', 'Yes') : tr('Нет', 'No')),
          ),
      ]),
    ];

List<Widget> _autostart(BuildContext context) {
  final s = context.app.settings;
  if (!Plat.isDesktop) {
    return [
      SettingsGroup(children: [
        InfoTile(title: tr('Автозапуск', 'Autostart'), value: tr('Используйте «Постоянный VPN» в настройках системы', 'Use "Always-on VPN" in system settings')),
      ]),
    ];
  }
  final on = s.get(K.autostart);
  return [
    SettingsGroup(children: [
      SwitchTile(K.autostart, title: tr('Запускать вместе с системой', 'Launch at login')),
    ]),
    SettingsGroup(title: tr('При автозапуске', 'On autostart'), children: [
      SwitchTile(K.autostartMinimized, title: tr('Скрывать окно в трей', 'Hide window to tray'), enabled: on),
      SwitchTile(K.autostartConnect, title: tr('Подключаться автоматически', 'Connect automatically'), enabled: on),
      NumberTile(K.autostartDelay, title: tr('Задержка подключения', 'Connection delay'), subtitle: tr('Дать сети время подняться', 'Give the network time to come up'), min: 0, max: 120, step: 5, suffix: tr('с', 's'), enabled: on),
    ]),
  ];
}

List<Widget> _network(BuildContext context) => [
      SettingsGroup(title: tr('Соединения', 'Connections'), children: [
        SwitchTile(K.preferIpv6, title: tr('Использовать IPv6', 'Use IPv6'), subtitle: tr('Для прямых соединений', 'For direct connections')),
        SwitchTile(K.tcpFastOpen, title: 'TCP Fast Open'),
        NumberTile(K.keepAlive, title: 'TCP Keep-Alive', subtitle: tr('0 — по умолчанию системы', '0 — system default'), min: 0, max: 600, step: 15, suffix: tr('с', 's')),
        TextTile(K.bindInterface, title: tr('Исходящий интерфейс', 'Outbound interface'), subtitle: tr('Пусто — автоматически', 'Empty — automatic'), hint: 'Ethernet / eth0'),
      ]),
      SettingsGroup(title: tr('Смена сети', 'Network changes'), children: [
        SwitchTile(K.watchNetwork, title: tr('Отслеживать смену сети', 'Watch network changes'), subtitle: tr('Перезапускать туннель TUN при смене Wi-Fi/кабеля', 'Restart TUN tunnel on Wi-Fi/cable change')),
      ]),
    ];

List<Widget> _privacy(BuildContext context) {
  final app = context.app;
  return [
    SettingsGroup(title: tr('Данные', 'Data'), children: [
      SwitchTile(K.maskAddresses, title: tr('Скрывать адреса и ключи', 'Mask addresses and keys'), subtitle: tr('В логах, деталях сервера и просмотре конфига', 'In logs, server details and config preview')),
      SwitchTile(K.clipboardDetect, title: tr('Распознавать ссылки в буфере', 'Detect links in clipboard')),
      SwitchTile(K.clearClipboard, title: tr('Очищать буфер после импорта', 'Clear clipboard after import')),
    ]),
    SettingsGroup(
      title: tr('Хранилище', 'Storage'),
      footer: tr('Подписки и ключи шифруются AES-256-GCM. Ключ шифрования хранится в системном хранилище учётных данных.',
          'Subscriptions and keys are encrypted with AES-256-GCM. The encryption key is kept in the OS credential store.'),
      children: [
        InfoTile(title: tr('Ключ шифрования', 'Encryption key'), value: app.subs.keySource == 'keychain' ? tr('Системное хранилище', 'OS keychain') : tr('Файл (только владелец)', 'File (owner only)')),
        ActionTile(
          title: tr('Удалить все данные', 'Erase all data'),
          subtitle: tr('Подписки, ключи, настройки и логи', 'Subscriptions, keys, settings and logs'),
          label: tr('Удалить', 'Erase'),
          danger: true,
          icon: Icons.delete_forever_outlined,
          onTap: () async {
            final ok = await showConfirm(context,
                title: tr('Удалить все данные?', 'Erase all data?'), message: tr('Это действие нельзя отменить.', 'This cannot be undone.'), confirm: tr('Удалить', 'Erase'), destructive: true);
            if (ok) await app.wipeAll();
          },
        ),
      ],
    ),
  ];
}

List<Widget> _advanced(BuildContext context) {
  final app = context.app;
  return [
    SettingsGroup(title: tr('Отладка', 'Debugging'), children: [
      SwitchTile(K.debugMode, title: tr('Режим отладки', 'Debug mode'), subtitle: tr('Подробный DNS-лог ядра', 'Verbose core DNS log')),
      NumberTile(K.metricsPort, title: tr('Порт метрик', 'Metrics port'), subtitle: tr('Локальная статистика скорости', 'Local speed statistics'), min: 1024, max: 65535),
      ActionTile(
        title: tr('Сгенерированный конфиг', 'Generated config'),
        subtitle: tr('Для выбранного сервера', 'For the selected server'),
        label: tr('Показать', 'Show'),
        icon: Icons.data_object_rounded,
        onTap: () {
          String text;
          try {
            text = app.previewConfig();
          } catch (e) {
            text = '$e';
          }
          showInfoDialog(
            context,
            title: tr('Конфигурация Xray', 'Xray configuration'),
            width: 720,
            content: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: context.c.surfaceHi, borderRadius: BorderRadius.circular(Radii.md)),
              child: SelectableText(text, style: TextStyle(fontFamily: AppTheme.mono, fontFamilyFallback: AppTheme.monoFallback, fontSize: 12, color: context.c.text)),
            ),
            actions: [
              AppButton.secondary(
                label: tr('Копировать', 'Copy'),
                icon: Icons.copy_rounded,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  showToast(context, tr('Скопировано', 'Copied'));
                },
              ),
              AppButton(label: tr('Закрыть', 'Close'), onPressed: () => Navigator.pop(context)),
            ],
          );
        },
      ),
    ]),
    SettingsGroup(
      title: tr('Переопределение конфига', 'Config override'),
      footer: tr('JSON-объект глубоко объединяется с итоговой конфигурацией Xray. Применяется при следующем подключении.',
          'A JSON object deep-merged into the final Xray config. Applied on next connection.'),
      children: [
        TextTile(K.configOverride, title: 'JSON', wide: true, mono: true, hint: '{"policy": {"levels": {"0": {"connIdle": 600}}}}', validator: _validateJson),
      ],
    ),
    SettingsGroup(title: tr('Настройки', 'Settings'), children: [
      ActionTile(
        title: tr('Экспорт настроек', 'Export settings'),
        subtitle: tr('В буфер обмена (без подписок)', 'To clipboard (without subscriptions)'),
        label: tr('Копировать', 'Copy'),
        icon: Icons.upload_rounded,
        onTap: () {
          Clipboard.setData(ClipboardData(text: app.settings.exportJson()));
          showToast(context, tr('Настройки скопированы', 'Settings copied'));
        },
      ),
      ActionTile(
        title: tr('Импорт настроек', 'Import settings'),
        label: tr('Вставить', 'Paste'),
        icon: Icons.download_rounded,
        onTap: () async {
          final text = await showTextInput(context, title: tr('Импорт настроек', 'Import settings'), multiline: true, monospace: true, confirm: tr('Импорт', 'Import'));
          if (text == null || !context.mounted) return;
          final ok = app.settings.importJson(text);
          showToast(context, ok ? tr('Настройки импортированы', 'Settings imported') : tr('Некорректные данные', 'Invalid data'), error: !ok);
        },
      ),
      ActionTile(
        title: tr('Сбросить настройки', 'Reset settings'),
        label: tr('Сбросить', 'Reset'),
        danger: true,
        onTap: () async {
          final ok = await showConfirm(context, title: tr('Сбросить настройки?', 'Reset settings?'), message: tr('Подписки останутся.', 'Subscriptions will be kept.'), confirm: tr('Сбросить', 'Reset'), destructive: true);
          if (ok) app.settings.reset();
        },
      ),
      if (Plat.isDesktop) ActionTile(title: tr('Папка данных', 'Data folder'), label: tr('Открыть', 'Open'), icon: Icons.folder_open_rounded, onTap: () => app.openFolder(AppPaths.root)),
    ]),
  ];
}

List<Widget> _about(BuildContext context) {
  final app = context.app;
  return [
    SettingsGroup(children: [
      InfoTile(title: 'Sharrow', value: app.appVersion),
      InfoTile(title: 'Xray-core', value: app.coreVersion ?? '—'),
      InfoTile(title: tr('Платформа', 'Platform'), value: Plat.name),
    ]),
    SettingsGroup(children: [
      for (final (icon, label, url) in [
        (Icons.language_rounded, tr('Сайт', 'Website'), Brand.website),
        (Icons.send_rounded, 'Telegram', Brand.telegram),
        (Icons.privacy_tip_outlined, tr('Конфиденциальность', 'Privacy'), Brand.privacyUrl),
      ])
        Pressable(
          onTap: () => app.openUrl(url),
          radius: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Icon(icon, size: 18, color: context.c.textSec),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: context.tt.bodyMedium)),
            Icon(Icons.arrow_outward_rounded, size: 15, color: context.c.textTer),
          ]),
        ),
    ]),
  ];
}
