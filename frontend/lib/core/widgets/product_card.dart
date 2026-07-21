import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../theme/app_colors.dart';
import 'price_text.dart';
import 'product_image.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onFavorite,
    this.onTryOn,
    this.isSelected = false,
    this.width,
    this.showTryOnButton = true,
    this.imageAspectRatio = 4 / 5,
  });

  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onTryOn;
  final bool isSelected;
  final double? width;
  final bool showTryOnButton;
  final double imageAspectRatio;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final selectedOrPressed = widget.isSelected || _pressed;

    return AnimatedScale(
      scale: selectedOrPressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: SizedBox(
        width: widget.width,
        child: Semantics(
          container: true,
          label:
              '${product.brand} ${product.name}, ${PriceText.formatWon(product.price)}',
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
                    aspectRatio: widget.imageAspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ProductImage(
                          assetPath: product.displayImage,
                          semanticLabel: '${product.name} 상품 이미지',
                          placeholderLabel: product.brand,
                          borderRadius: BorderRadius.zero,
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: _FavoriteButton(
                            isFavorite: product.isFavorite,
                            onPressed: widget.onFavorite,
                          ),
                        ),
                        if (widget.isSelected)
                          const Positioned(
                            left: 10,
                            top: 10,
                            child: _ProductSelectedBadge(),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                        const SizedBox(height: 5),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.mainText,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
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
                        if (widget.showTryOnButton) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: product.isInStock
                                  ? widget.onTryOn
                                  : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryPurple,
                                disabledForegroundColor:
                                    AppColors.secondaryText,
                                side: const BorderSide(
                                  color: AppColors.divider,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 17,
                              ),
                              label: Text(
                                product.isInStock ? '입혀보기' : '품절',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
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
      ),
    );
  }
}

class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton({required this.isFavorite, this.onPressed});

  final bool isFavorite;
  final VoidCallback? onPressed;

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.24), weight: 45),
      TweenSequenceItem(tween: Tween<double>(begin: 1.24, end: 1), weight: 55),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: IconButton.filledTonal(
        onPressed: widget.onPressed == null
            ? null
            : () {
                _controller.forward(from: 0);
                widget.onPressed!();
              },
        tooltip: widget.isFavorite ? '찜 해제' : '찜하기',
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: Icon(
            widget.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            key: ValueKey(widget.isFavorite),
            size: 22,
          ),
        ),
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: AppColors.surface.withValues(alpha: 0.92),
          foregroundColor: widget.isFavorite
              ? AppColors.error
              : AppColors.mainText,
          disabledBackgroundColor: AppColors.surface.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _ProductSelectedBadge extends StatelessWidget {
  const _ProductSelectedBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 15, color: AppColors.surface),
            SizedBox(width: 3),
            Text(
              '선택',
              style: TextStyle(
                color: AppColors.surface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
