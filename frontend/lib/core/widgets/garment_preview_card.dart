import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../theme/app_colors.dart';
import 'price_text.dart';
import 'product_image.dart';

class GarmentPreviewCard extends StatefulWidget {
  const GarmentPreviewCard({
    super.key,
    required this.product,
    this.selectedColor,
    this.selectedSize,
    this.isSelected = false,
    this.onTap,
    this.aspectRatio = 4 / 5,
  });

  final Product product;
  final String? selectedColor;
  final String? selectedSize;
  final bool isSelected;
  final VoidCallback? onTap;
  final double aspectRatio;

  @override
  State<GarmentPreviewCard> createState() => _GarmentPreviewCardState();
}

class _GarmentPreviewCardState extends State<GarmentPreviewCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return AnimatedScale(
      scale: _pressed || widget.isSelected ? 0.98 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Semantics(
        button: widget.onTap != null,
        selected: widget.isSelected,
        label: '선택한 옷 ${product.brand} ${product.name}',
        child: Material(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: widget.isSelected
                  ? AppColors.primaryPurple
                  : AppColors.divider,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) {
              if (mounted) setState(() => _pressed = value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: widget.aspectRatio,
                  child: ProductImage(
                    assetPath: product.displayImage,
                    semanticLabel: '${product.name} 의류 미리보기',
                    placeholderLabel: product.brand,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppColors.secondaryText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.mainText,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      PriceText(
                        price: product.price,
                        originalPrice: product.originalPrice,
                        discountPercent: product.effectiveDiscountPercent,
                        fontSize: 15,
                        compact: true,
                      ),
                      if (widget.selectedColor != null ||
                          widget.selectedSize != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (widget.selectedColor != null)
                              _OptionBadge(label: '컬러 ${widget.selectedColor}'),
                            if (widget.selectedSize != null)
                              _OptionBadge(label: '사이즈 ${widget.selectedSize}'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionBadge extends StatelessWidget {
  const _OptionBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
