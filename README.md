# Sharrow

Кроссплатформенный VPN-клиент на Flutter + Xray-core: Windows, Linux, Android, iOS (и macOS).

## Быстрый старт (Windows)

1. Включите **режим разработчика** Windows (нужен Flutter для символьных ссылок плагинов):
   `start ms-settings:developers` → «Режим разработчика».
2. Скачайте ядро для упаковки и запустите:

```powershell
pwsh tool/fetch_core.ps1        # -> core\xray.exe, geoip.dat, geosite.dat, wintun.dll
flutter pub get
flutter run -d windows
```

Без папки `core` приложение само предложит скачать ядро с GitHub при первом подключении.
Режиму TUN на Windows нужны права администратора — клиент предложит перезапуститься с ними.

## Сборка

| Платформа | Команда | Результат |
|---|---|---|
| Windows | `flutter build windows --release` → `iscc windows\installer\sharrow.iss` | `dist\*-setup.exe` |
| Linux | `tool/fetch_core.sh linux` → `flutter build linux --release` → `tool/package_linux.sh` | `.deb`, `.rpm`, `.AppImage` |
| Android | `tool/fetch_core.sh android` (нужны Go + gomobile) → `flutter build apk --split-per-abi` | `.apk` |
| iOS | см. ниже → `flutter build ipa` | `.ipa` |

Всё это делает `.github/workflows/build.yml` по тегу `v*`.

### Android
Ядро встраивается библиотекой [libXray](https://github.com/XTLS/libXray) (`android/app/libs/libXray.aar`).
TUN создаёт `SharrowVpnService`, дескриптор передаётся в Xray через `XRAY_TUN_FD`. Без AAR приложение собирается,
но подключение сообщит, что ядро не встроено.

### iOS
Для VPN на iOS нужен Apple Developer аккаунт и Network Extension:
1. `tool/fetch_core.sh ios` → `ios/Frameworks/LibXray.xcframework`.
2. В Xcode: *File → New → Target → Network Extension (Packet Tunnel)*, bundle id `<app id>.PacketTunnel`,
   заменить сгенерированный файл на `ios/PacketTunnel/PacketTunnelProvider.swift`, подключить `LibXray.xcframework`
   и geo-файлы из `ios/PacketTunnel/Resources`.
3. Включить capability *Network Extensions → Packet Tunnel* и общую App Group для обоих таргетов.

Неподписанный `.ipa` из CI устанавливается только через AltStore/Sideloadly.

## Проверка конфигов

```powershell
$env:XRAY_BIN = "core\xray.exe"; flutter test
```

Тест собирает конфиги для всех протоколов (VLESS Reality/WS/gRPC/XHTTP/HTTPUpgrade, Trojan, VMess, SS/SS2022, SOCKS,
WireGuard) в режимах Proxy и TUN и проверяет их реальным ядром (`xray run -test`).

## Структура

```
lib/
  core/        тема, токены, локализация, форматирование, бренд
  data/        модели (сервер, подписка, настройки), зашифрованное хранилище
  modules/
    xray/          сборка конфига, запуск ядра (desktop/mobile), установщик, статистика
    subscription/  парсер ссылок, загрузка подписок, гео-определение стран
    routing/       правила маршрутизации и пресеты
    ping/          TCP-пинг и реальная задержка
    system/        системный прокси, трей, автозапуск, уведомления, права, single-instance
    logs/          журнал с маскированием
  state/       контроллеры (приложение, настройки, подписки, подключение)
  ui/          экраны и виджеты
```

## Что настроить перед релизом

- `lib/core/brand.dart` — ссылки (сайт, оплата, Telegram, поддержка, фид обновлений) и тарифы `kPlans` — сейчас заглушки.
- Подпись Android (`android/app/build.gradle.kts`, сейчас debug-ключ) и iOS.
- Фид обновлений `Brand.updateFeedUrl` должен отдавать `{"version": "1.0.1", "url": "...", "notes": "..."}`.

Шрифт Inter — SIL Open Font License (`assets/fonts/Inter-LICENSE.txt`). Xray-core — MPL-2.0.
