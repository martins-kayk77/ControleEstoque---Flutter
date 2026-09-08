import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    this.size = 44,
    this.showName = false,
    this.nameStyle,
    super.key,
  });

  static const assetPath = 'assets/brand/logo_prumo.png';

  final double size;
  final bool showName;
  final TextStyle? nameStyle;

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );

    if (!showName) {
      return image;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        image,
        const SizedBox(width: 10),
        Text(
          'Prumo',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              nameStyle ??
              Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
