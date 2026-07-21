import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PriceText extends StatelessWidget {
  const PriceText({
    super.key,
    required this.price,
    this.originalPrice,
    this.discountPercent = 0,
    this.fontSize = 16,
    this.compact = false,
  });

  final int price;
  final int? originalPrice;
  final int discountPercent;
  final double fontSize;
  final bool compact;

  static String formatWon(int value) {
    final formatted = value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]},',
    );
    return '$formatted원';
  }

  @override
  Widget build(BuildContext context) {
    final hasOriginalPrice =
        originalPrice != null && originalPrice! > price && !compact;
    return Semantics(
      label: [
        if (discountPercent > 0) '$discountPercent퍼센트 할인',
        '판매가 ${formatWon(price)}',
        if (hasOriginalPrice) '정가 ${formatWon(originalPrice!)}',
      ].join(', '),
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (discountPercent > 0)
              Text(
                '$discountPercent%',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            Text(
              formatWon(price),
              style: TextStyle(
                color: AppColors.mainText,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            if (hasOriginalPrice)
              Text(
                formatWon(originalPrice!),
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: (fontSize - 3).clamp(11, fontSize),
                  decoration: TextDecoration.lineThrough,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
