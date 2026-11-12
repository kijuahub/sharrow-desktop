/// Product-level constants. Replace URLs with production values.
abstract final class Brand {
  static const appName = 'Sharrow';
  static const website = 'https://github.com/sharrow-app/sharrow-desktop';
  static const buyUrl = 'https://t.me/sharrow_bot';
  static const telegram = 'https://t.me/sharrowvpn';
  static const support = 'https://t.me/sharrow_robot';
  static const sourceUrl = 'https://github.com/sharrow-app/sharrow-desktop';
  static const releasesUrl = 'https://api.github.com/repos/sharrow-app/sharrow-desktop/releases';

  /// JSON: {"version":"1.2.0","url":"https://...","notes":"...","channel":"stable"}
  static const updateFeedUrl = 'https://sharrow.app/api/desktop/latest.json';
  /// Panels (Remnawave, Marzban) pick the response format by User-Agent:
  /// `Happ/` gets Xray JSON configs and the routing profile, v2rayN gets links.
  static const userAgentJson = 'Happ/3.13.0 (Sharrow 1.0)';
  static const userAgentLinks = 'v2rayN/7.0 (Sharrow 1.0)';
}
