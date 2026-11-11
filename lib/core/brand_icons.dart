import 'l10n.dart';

class BrandIcon {
  const BrandIcon(this.id, this.asset, this.ru, this.en);

  final String id;
  final String asset;
  final String ru;
  final String en;

  String get label => tr(ru, en);
}

const kBrandIcons = <BrandIcon>[
  BrandIcon('default', 'assets/icons/app_icon_512.png', 'Стандарт', 'Default'),
  BrandIcon('planet-green', 'assets/icons/brand_planet_green.jpg', 'Зелёная', 'Green'),
  BrandIcon('planet-blue', 'assets/icons/brand_planet_blue.jpg', 'Синяя', 'Blue'),
  BrandIcon('planet-lavender', 'assets/icons/brand_planet_lavender.jpg', 'Лавандовая', 'Lavender'),
  BrandIcon('planet-banana', 'assets/icons/brand_planet_banana.jpg', 'Банановая', 'Banana'),
  BrandIcon('planet-peach', 'assets/icons/brand_planet_peach.jpg', 'Персиковая', 'Peach'),
  BrandIcon('word-lime', 'assets/icons/brand_word_lime.jpg', 'Текст · лайм', 'Word · lime'),
  BrandIcon('word-white', 'assets/icons/brand_word_white.jpg', 'Текст · белый', 'Word · white'),
  BrandIcon('word-blue', 'assets/icons/brand_word_blue.jpg', 'Текст · синий', 'Word · blue'),
];

BrandIcon brandIconById(String id) {
  for (final icon in kBrandIcons) {
    if (icon.id == id) return icon;
  }
  return kBrandIcons.first;
}
