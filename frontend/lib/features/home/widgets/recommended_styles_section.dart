import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../../models/product.dart';

class RecommendedStylesSection extends StatelessWidget {
  const RecommendedStylesSection({
    super.key,
    required this.products,
    required this.onViewAll,
    required this.onProductTap,
    required this.onTryOn,
    required this.onFavorite,
    this.isLoading = false,
    this.hasError = false,
  });

  final List<Product> products;
  final VoidCallback onViewAll;
  final ValueChanged<Product> onProductTap;
  final ValueChanged<Product> onTryOn;
  final ValueChanged<Product> onFavorite;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '추천 스타일',
          subtitle: '지금 입어보기 좋은 아이템을 골랐어요.',
          actionLabel: '전체보기',
          onAction: onViewAll,
        ),
        const SizedBox(height: 14),
        if (isLoading)
          const _RecommendationLoading()
        else if (hasError || products.isEmpty)
          EmptyStateCard(
            icon: Icons.checkroom_outlined,
            title: hasError ? '추천 상품을 불러오지 못했어요.' : '추천할 상품을 준비 중이에요.',
            description: '쇼핑 탭에서 다양한 상품을 먼저 둘러보세요.',
            actionLabel: '쇼핑 둘러보기',
            onAction: onViewAll,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth < 400 ? 214.0 : 232.0;
              return SizedBox(
                height: cardWidth * 1.25 + 205,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 4),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductCard(
                      width: cardWidth,
                      product: product,
                      onTap: () => onProductTap(product),
                      onTryOn: () => onTryOn(product),
                      onFavorite: () => onFavorite(product),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

class _RecommendationLoading extends StatelessWidget {
  const _RecommendationLoading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 438,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) => Container(
          width: 218,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
              const SizedBox(height: 126),
            ],
          ),
        ),
      ),
    );
  }
}
