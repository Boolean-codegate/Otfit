import 'package:flutter/material.dart';

import '../../models/fitting_result.dart';
import '../theme/app_colors.dart';
import 'price_text.dart';
import 'product_image.dart';

class FittingHistoryCard extends StatefulWidget {
  const FittingHistoryCard({
    super.key,
    required this.result,
    this.onTap,
    this.onTryAgain,
    this.showTryAgain = true,
  });

  final FittingResult result;
  final VoidCallback? onTap;
  final VoidCallback? onTryAgain;
  final bool showTryAgain;

  @override
  State<FittingHistoryCard> createState() => _FittingHistoryCardState();
}

class _FittingHistoryCardState extends State<FittingHistoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final product = result.product;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Semantics(
        container: true,
        label:
            '${product.brand} ${product.name} 피팅 기록, ${_formatDate(result.createdAt)}',
        child: Material(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) {
              if (mounted) setState(() => _pressed = value);
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: AspectRatio(
                      aspectRatio: 4 / 5,
                      child: ProductImage(
                        assetPath: result.resultImageAsset,
                        semanticLabel: '${product.name} AI 피팅 결과',
                        placeholderLabel: 'AI FIT',
                        borderRadius: const BorderRadius.all(
                          Radius.circular(14),
                        ),
                        icon: Icons.auto_awesome_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product.brand,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: AppColors.primaryPurple,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            Text(
                              _formatDate(result.createdAt),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: AppColors.mainText,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 7),
                        PriceText(
                          price: product.price,
                          fontSize: 14,
                          compact: true,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${result.selectedColor} · ${result.selectedSize}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.secondaryText),
                        ),
                        if (widget.showTryAgain) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: widget.onTryAgain,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryPurple,
                                side: const BorderSide(
                                  color: AppColors.divider,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text(
                                '다시 입혀보기',
                                style: TextStyle(
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

  static String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}.${twoDigits(date.month)}.${twoDigits(date.day)}';
  }
}
