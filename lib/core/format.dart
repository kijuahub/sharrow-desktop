import 'l10n.dart';

abstract final class Fmt {
  static String bytes(num value, {int digits = 1}) {
    final units = L10n.isRu
        ? const ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ']
        : const ['B', 'KB', 'MB', 'GB', 'TB'];
    var v = value.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    final text = i == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(v >= 100 ? 0 : digits);
    return '$text ${units[i]}';
  }

  static String speed(num bytesPerSecond) => '${bytes(bytesPerSecond)}/${tr('с', 's')}';

  static String duration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    return '${two(h)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  static const _monthsRu = ['янв.', 'февр.', 'мар.', 'апр.', 'мая', 'июн.', 'июл.', 'авг.', 'сент.', 'окт.', 'нояб.', 'дек.'];
  static const _monthsEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String date(DateTime d, {bool withYear = true}) {
    final l = d.toLocal();
    final now = DateTime.now();
    final showYear = withYear && l.year != now.year;
    if (L10n.isRu) {
      return '${l.day} ${_monthsRu[l.month - 1]}${showYear ? ' ${l.year}' : ''}';
    }
    return '${_monthsEn[l.month - 1]} ${l.day}${showYear ? ', ${l.year}' : ''}';
  }

  static String dateTime(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date(l)}, ${two(l.hour)}:${two(l.minute)}';
  }

  static String time(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
  }

  static String ago(DateTime? d) {
    if (d == null) return tr('никогда', 'never');
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 45) return tr('только что', 'just now');
    if (diff.inMinutes < 60) return tr('${diff.inMinutes} мин назад', '${diff.inMinutes} min ago');
    if (diff.inHours < 24) return tr('${diff.inHours} ч назад', '${diff.inHours} h ago');
    if (diff.inDays < 7) return tr('${diff.inDays} дн. назад', '${diff.inDays} d ago');
    return date(d);
  }

  static String daysLeft(DateTime expire) {
    final days = expire.difference(DateTime.now()).inDays;
    if (days < 0) return tr('истекла', 'expired');
    if (days == 0) return tr('сегодня', 'today');
    return tr('$days дн.', '$days d');
  }
}
