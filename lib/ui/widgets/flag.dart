import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../modules/subscription/geo.dart';

class FlagIcon extends StatelessWidget {
  const FlagIcon(this.code, {super.key, this.size = 24});

  final String? code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cc = code;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.surfaceHi, shape: BoxShape.circle, border: Border.all(color: c.border)),
      child: Icon(Icons.public_rounded, size: size * 0.6, color: c.textTer),
    );
    if (cc == null || !Geo.countries.containsKey(cc)) return fallback;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.border, width: 1)),
      child: ClipOval(
        child: CountryFlag.fromCountryCode(
          cc,
          theme: ImageTheme(width: size, height: size, shape: const Circle()),
        ),
      ),
    );
  }
}
