import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/price_text.dart';
import '../../core/widgets/product_image.dart';
import '../../core/widgets/responsive_content.dart';
import '../../providers/app_providers.dart';

/// 찜한 상품 (계약 §11 GET /me/favorites) — 하트 해제 시 목록에서 제거.
class MyFavoritesScreen extends ConsumerWidget {
  const MyFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(myFavoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('찜한 상품')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(myFavoritesProvider.future),
          child: ResponsiveContent(
            child: favorites.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('불러오지 못했어요\n$error')),
              data: (items) => items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        const Icon(Icons.favorite_border_rounded,
                            size: 52, color: AppColors.disabled),
                        const SizedBox(height: 14),
                        const Text('찜한 상품이 없어요.\n마음에 드는 옷에 하트를 눌러보세요!',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 18),
                        Center(
                          child: FilledButton(
                            onPressed: () => context.go('/shop'),
                            child: const Text('쇼핑하러 가기'),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final product = items[index];
                        return Material(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppColors.divider),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () =>
                                context.push('/shop/product/${product.id}'),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: ProductImage(
                                      assetPath: product.displayImage,
                                      semanticLabel: product.title,
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.brand,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: AppColors.primaryPurple,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        Text(
                                          product.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        const SizedBox(height: 2),
                                        PriceText(price: product.price),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: '찜 해제',
                                    icon: const Icon(Icons.favorite_rounded,
                                        color: AppColors.error),
                                    onPressed: () => ref
                                        .read(favoriteProductIdsProvider
                                            .notifier)
                                        .toggle(product.id),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
