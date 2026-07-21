import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/widgets.dart';
import '../../models/product.dart';
import '../../providers/app_providers.dart';
import 'widgets/home_hero_card.dart';
import 'widgets/partner_malls_section.dart';
import 'widgets/recent_photo_section.dart';
import 'widgets/recommended_styles_section.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPhoto = ref.watch(selectedUserPhotoProvider);
    final productsState = ref.watch(productsProvider);
    final favoriteIds = ref.watch(favoriteProductIdsProvider);
    final recommendedProducts = productsState.when(
      data: (products) => products
          .take(6)
          .map(
            (product) =>
                product.copyWith(isFavorite: favoriteIds.contains(product.id)),
          )
          .toList(growable: false),
      loading: () => const <Product>[],
      error: (error, stackTrace) => const <Product>[],
    );

    void openPhotoSelection() => context.push('/photo');

    void startTryOn(Product product) {
      ref.read(selectedProductProvider.notifier).selectProduct(product);
      if (ref.read(selectedUserPhotoProvider) == null) {
        context.push('/photo');
      } else {
        context.go('/try-on');
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: OTFITAppBar(
        showLogo: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => _showMessage(context, '새로운 알림이 없어요.'),
            tooltip: '알림',
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Tooltip(
              message: '내 프로필',
              child: InkWell(
                onTap: () => context.go('/profile'),
                customBorder: const CircleBorder(),
                child: const SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.lightPurple,
                      child: Text(
                        'O',
                        style: TextStyle(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: ResponsiveContent(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 42),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '오늘은 어떤 스타일을\n입어볼까요?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.mainText,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '사진을 등록하고 원하는 옷을 골라보세요.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 24),
                HomeHeroCard(onSelectPhoto: openPhotoSelection),
                const SizedBox(height: 34),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: selectedPhoto == null ? 680 : 420,
                    ),
                    child: RecentPhotoSection(
                      photoBytes: selectedPhoto?.bytes,
                      onRegister: openPhotoSelection,
                      onChange: openPhotoSelection,
                      onRemove: () {
                        ref.read(selectedUserPhotoProvider.notifier).clear();
                        ref.read(lastPhotoAnalysisProvider.notifier).clear();
                        _showMessage(context, '등록한 사진을 삭제했어요.');
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 38),
                RecommendedStylesSection(
                  products: recommendedProducts,
                  isLoading: productsState.isLoading,
                  hasError: productsState.hasError,
                  onViewAll: () => context.go('/shop'),
                  onProductTap: (product) =>
                      context.push('/shop/product/${product.id}'),
                  onTryOn: startTryOn,
                  onFavorite: (product) {
                    ref
                        .read(favoriteProductIdsProvider.notifier)
                        .toggle(product.id);
                  },
                ),
                const SizedBox(height: 38),
                PartnerMallsSection(onViewAll: () => context.go('/shop')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
