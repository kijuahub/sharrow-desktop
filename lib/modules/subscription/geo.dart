/// Country detection from server names and approximate coordinates for the globe.
abstract final class Geo {
  /// ISO code -> (lat, lon, English name, Russian name).
  static const countries = <String, (double, double, String, String)>{
    'US': (39.8, -98.6, 'United States', 'США'),
    'CA': (56.1, -106.3, 'Canada', 'Канада'),
    'MX': (23.6, -102.5, 'Mexico', 'Мексика'),
    'BR': (-14.2, -51.9, 'Brazil', 'Бразилия'),
    'AR': (-38.4, -63.6, 'Argentina', 'Аргентина'),
    'CL': (-35.7, -71.5, 'Chile', 'Чили'),
    'CO': (4.6, -74.3, 'Colombia', 'Колумбия'),
    'PE': (-9.2, -75.0, 'Peru', 'Перу'),
    'GB': (52.4, -1.5, 'United Kingdom', 'Великобритания'),
    'IE': (53.4, -8.2, 'Ireland', 'Ирландия'),
    'FR': (46.6, 2.2, 'France', 'Франция'),
    'DE': (51.2, 10.4, 'Germany', 'Германия'),
    'NL': (52.2, 5.3, 'Netherlands', 'Нидерланды'),
    'BE': (50.5, 4.5, 'Belgium', 'Бельгия'),
    'LU': (49.8, 6.1, 'Luxembourg', 'Люксембург'),
    'CH': (46.8, 8.2, 'Switzerland', 'Швейцария'),
    'AT': (47.5, 14.6, 'Austria', 'Австрия'),
    'ES': (40.4, -3.7, 'Spain', 'Испания'),
    'PT': (39.4, -8.2, 'Portugal', 'Португалия'),
    'IT': (41.9, 12.6, 'Italy', 'Италия'),
    'PL': (51.9, 19.1, 'Poland', 'Польша'),
    'CZ': (49.8, 15.5, 'Czechia', 'Чехия'),
    'SK': (48.7, 19.7, 'Slovakia', 'Словакия'),
    'HU': (47.2, 19.5, 'Hungary', 'Венгрия'),
    'RO': (45.9, 24.9, 'Romania', 'Румыния'),
    'BG': (42.7, 25.5, 'Bulgaria', 'Болгария'),
    'GR': (39.1, 21.8, 'Greece', 'Греция'),
    'RS': (44.0, 21.0, 'Serbia', 'Сербия'),
    'HR': (45.1, 15.2, 'Croatia', 'Хорватия'),
    'SI': (46.2, 14.9, 'Slovenia', 'Словения'),
    'MD': (47.4, 28.4, 'Moldova', 'Молдова'),
    'UA': (48.4, 31.2, 'Ukraine', 'Украина'),
    'BY': (53.7, 27.9, 'Belarus', 'Беларусь'),
    'LT': (55.2, 23.9, 'Lithuania', 'Литва'),
    'LV': (56.9, 24.6, 'Latvia', 'Латвия'),
    'EE': (58.6, 25.0, 'Estonia', 'Эстония'),
    'FI': (61.9, 25.7, 'Finland', 'Финляндия'),
    'SE': (60.1, 18.6, 'Sweden', 'Швеция'),
    'NO': (60.5, 8.5, 'Norway', 'Норвегия'),
    'DK': (56.3, 9.5, 'Denmark', 'Дания'),
    'IS': (64.9, -19.0, 'Iceland', 'Исландия'),
    'RU': (55.8, 37.6, 'Russia', 'Россия'),
    'KZ': (48.0, 66.9, 'Kazakhstan', 'Казахстан'),
    'UZ': (41.4, 64.6, 'Uzbekistan', 'Узбекистан'),
    'KG': (41.2, 74.8, 'Kyrgyzstan', 'Киргизия'),
    'GE': (42.3, 43.4, 'Georgia', 'Грузия'),
    'AM': (40.1, 45.0, 'Armenia', 'Армения'),
    'AZ': (40.1, 47.6, 'Azerbaijan', 'Азербайджан'),
    'TR': (39.0, 35.2, 'Turkey', 'Турция'),
    'IL': (31.0, 34.9, 'Israel', 'Израиль'),
    'AE': (23.4, 53.8, 'UAE', 'ОАЭ'),
    'SA': (23.9, 45.1, 'Saudi Arabia', 'Саудовская Аравия'),
    'QA': (25.4, 51.2, 'Qatar', 'Катар'),
    'BH': (26.0, 50.6, 'Bahrain', 'Бахрейн'),
    'IR': (32.4, 53.7, 'Iran', 'Иран'),
    'EG': (26.8, 30.8, 'Egypt', 'Египет'),
    'ZA': (-30.6, 22.9, 'South Africa', 'ЮАР'),
    'NG': (9.1, 8.7, 'Nigeria', 'Нигерия'),
    'KE': (-0.0, 37.9, 'Kenya', 'Кения'),
    'MA': (31.8, -7.1, 'Morocco', 'Марокко'),
    'IN': (21.0, 78.0, 'India', 'Индия'),
    'PK': (30.4, 69.3, 'Pakistan', 'Пакистан'),
    'CN': (35.9, 104.2, 'China', 'Китай'),
    'HK': (22.3, 114.2, 'Hong Kong', 'Гонконг'),
    'TW': (23.7, 121.0, 'Taiwan', 'Тайвань'),
    'JP': (36.2, 138.3, 'Japan', 'Япония'),
    'KR': (35.9, 127.8, 'South Korea', 'Южная Корея'),
    'SG': (1.35, 103.8, 'Singapore', 'Сингапур'),
    'MY': (4.2, 102.0, 'Malaysia', 'Малайзия'),
    'TH': (15.9, 100.9, 'Thailand', 'Таиланд'),
    'VN': (14.1, 108.3, 'Vietnam', 'Вьетнам'),
    'ID': (-0.8, 113.9, 'Indonesia', 'Индонезия'),
    'PH': (12.9, 121.8, 'Philippines', 'Филиппины'),
    'AU': (-25.3, 133.8, 'Australia', 'Австралия'),
    'NZ': (-40.9, 174.9, 'New Zealand', 'Новая Зеландия'),
    'CY': (35.1, 33.4, 'Cyprus', 'Кипр'),
    'MT': (35.9, 14.4, 'Malta', 'Мальта'),
    'AL': (41.2, 20.2, 'Albania', 'Албания'),
    'MK': (41.6, 21.7, 'North Macedonia', 'Северная Македония'),
    'BA': (43.9, 17.7, 'Bosnia', 'Босния'),
    'ME': (42.7, 19.4, 'Montenegro', 'Черногория'),
    'MN': (46.9, 103.8, 'Mongolia', 'Монголия'),
  };

  static const _keywords = <String, String>{
    'usa': 'US', 'united states': 'US', 'america': 'US', 'сша': 'US', 'америка': 'US', 'new york': 'US', 'los angeles': 'US',
    'chicago': 'US', 'dallas': 'US', 'miami': 'US', 'seattle': 'US', 'san jose': 'US', 'ashburn': 'US', 'нью-йорк': 'US',
    'canada': 'CA', 'канада': 'CA', 'toronto': 'CA', 'montreal': 'CA',
    'mexico': 'MX', 'brazil': 'BR', 'бразилия': 'BR', 'argentina': 'AR', 'chile': 'CL',
    'united kingdom': 'GB', 'britain': 'GB', 'england': 'GB', 'london': 'GB', 'великобритания': 'GB', 'англия': 'GB', 'лондон': 'GB',
    'ireland': 'IE', 'ирландия': 'IE', 'dublin': 'IE',
    'france': 'FR', 'франция': 'FR', 'paris': 'FR', 'париж': 'FR',
    'germany': 'DE', 'германия': 'DE', 'frankfurt': 'DE', 'франкфурт': 'DE', 'berlin': 'DE', 'берлин': 'DE', 'nuremberg': 'DE', 'munich': 'DE', 'falkenstein': 'DE',
    'netherlands': 'NL', 'нидерланды': 'NL', 'holland': 'NL', 'голландия': 'NL', 'amsterdam': 'NL', 'амстердам': 'NL',
    'belgium': 'BE', 'switzerland': 'CH', 'швейцария': 'CH', 'zurich': 'CH', 'austria': 'AT', 'австрия': 'AT', 'vienna': 'AT',
    'spain': 'ES', 'испания': 'ES', 'madrid': 'ES', 'portugal': 'PT', 'italy': 'IT', 'италия': 'IT', 'milan': 'IT',
    'poland': 'PL', 'польша': 'PL', 'warsaw': 'PL', 'czech': 'CZ', 'чехия': 'CZ', 'prague': 'CZ',
    'hungary': 'HU', 'romania': 'RO', 'румыния': 'RO', 'bulgaria': 'BG', 'болгария': 'BG', 'greece': 'GR', 'serbia': 'RS', 'сербия': 'RS',
    'moldova': 'MD', 'молдова': 'MD', 'ukraine': 'UA', 'украина': 'UA', 'belarus': 'BY',
    'lithuania': 'LT', 'литва': 'LT', 'latvia': 'LV', 'латвия': 'LV', 'riga': 'LV', 'estonia': 'EE', 'эстония': 'EE', 'tallinn': 'EE',
    'finland': 'FI', 'финляндия': 'FI', 'helsinki': 'FI', 'хельсинки': 'FI', 'sweden': 'SE', 'швеция': 'SE', 'stockholm': 'SE',
    'norway': 'NO', 'норвегия': 'NO', 'denmark': 'DK', 'iceland': 'IS',
    'russia': 'RU', 'россия': 'RU', 'moscow': 'RU', 'москва': 'RU', 'saint petersburg': 'RU', 'петербург': 'RU',
    'kazakhstan': 'KZ', 'казахстан': 'KZ', 'almaty': 'KZ', 'georgia': 'GE', 'грузия': 'GE', 'tbilisi': 'GE',
    'armenia': 'AM', 'армения': 'AM', 'turkey': 'TR', 'турция': 'TR', 'istanbul': 'TR', 'стамбул': 'TR', 'türkiye': 'TR',
    'israel': 'IL', 'израиль': 'IL', 'emirates': 'AE', 'dubai': 'AE', 'дубай': 'AE', 'оаэ': 'AE',
    'india': 'IN', 'индия': 'IN', 'china': 'CN', 'китай': 'CN', 'hong kong': 'HK', 'hongkong': 'HK', 'гонконг': 'HK',
    'taiwan': 'TW', 'japan': 'JP', 'япония': 'JP', 'tokyo': 'JP', 'токио': 'JP', 'osaka': 'JP',
    'korea': 'KR', 'корея': 'KR', 'seoul': 'KR', 'singapore': 'SG', 'сингапур': 'SG',
    'malaysia': 'MY', 'thailand': 'TH', 'vietnam': 'VN', 'indonesia': 'ID', 'philippines': 'PH',
    'australia': 'AU', 'австралия': 'AU', 'sydney': 'AU', 'new zealand': 'NZ', 'south africa': 'ZA', 'egypt': 'EG', 'cyprus': 'CY',
  };

  static final _codeToken = RegExp(r'(?:^|[^A-Za-z])([A-Z]{2})(?:[^A-Za-z]|$)');

  /// Detects an ISO 3166-1 alpha-2 code from a server name.
  static String? detect(String name) {
    final runes = name.runes.toList();
    for (var i = 0; i + 1 < runes.length; i++) {
      final a = runes[i], b = runes[i + 1];
      if (a >= 0x1F1E6 && a <= 0x1F1FF && b >= 0x1F1E6 && b <= 0x1F1FF) {
        final code = String.fromCharCodes([a - 0x1F1E6 + 65, b - 0x1F1E6 + 65]);
        return code == 'UK' ? 'GB' : code;
      }
    }
    final lower = name.toLowerCase();
    for (final e in _keywords.entries) {
      if (lower.contains(e.key)) return e.value;
    }
    for (final m in _codeToken.allMatches(name)) {
      final code = m.group(1)!;
      if (code == 'UK') return 'GB';
      if (countries.containsKey(code)) return code;
    }
    return null;
  }

  static (double, double)? coords(String? code) {
    final c = countries[code];
    return c == null ? null : (c.$1, c.$2);
  }

  static String? countryName(String? code, {required bool ru}) {
    final c = countries[code];
    return c == null ? null : (ru ? c.$4 : c.$3);
  }

  /// Strips a leading flag emoji so names don't render it twice next to the flag icon.
  static String cleanName(String name) {
    final runes = name.runes.toList();
    var i = 0;
    while (i + 1 < runes.length && runes[i] >= 0x1F1E6 && runes[i] <= 0x1F1FF && runes[i + 1] >= 0x1F1E6 && runes[i + 1] <= 0x1F1FF) {
      i += 2;
      while (i < runes.length && (runes[i] == 0x20 || runes[i] == 0xFE0F)) {
        i++;
      }
    }
    final out = String.fromCharCodes(runes.sublist(i)).trim();
    return out.isEmpty ? name : out;
  }
}
