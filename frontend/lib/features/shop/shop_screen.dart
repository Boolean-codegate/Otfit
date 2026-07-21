import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/product_image.dart';
import '../../models/product.dart';
import '../../providers/app_providers.dart';

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _searchController = TextEditingController();
  String? _mall;
  String? _priceRange;
  String? _color;
  String _sort = '인기순';

  static const _categories = ['전체', '상의', '아우터', '원피스', '하의'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _applyLocalFilters(List<Product> products) {
    var filtered = products.where((product) {
      if (_mall != null && product.mallName != _mall) return false;
      if (_color != null && !product.availableColors.contains(_color)) {
        return false;
      }
      return switch (_priceRange) {
        '5만원 이하' => product.price <= 50000,
        '5~10만원' => product.price > 50000 && product.price <= 100000,
        '10만원 이상' => product.price > 100000,
        _ => true,
      };
    }).toList();

    if (_sort == '낮은 가격순') {
      filtered.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sort == '높은 할인순') {
      filtered.sort((a, b) => b.discountPercent.compareTo(a.discountPercent));
    }
    return filtered;
  }

  Future<void> _showFilterSheet({required String type}) async {
    // 쇼핑몰별 필터는 상품에 몰 구분이 아직 없어 미구현 — UI는 유지하고 안내만
    if (type == '쇼핑몰') {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('쇼핑몰별 필터는 추후 제공될 예정이에요. 지금은 파트너몰 상품을 모아 보여드려요.'),
          ),
        );
      return;
    }
    final options = switch (type) {
      '가격대' => <String?>[null, '5만원 이하', '5~10만원', '10만원 이상'],
      '색상' => <String?>[null, '블랙', '화이트', '아이보리', '네이비', '블루'],
      _ => <String?>['인기순', '낮은 가격순', '높은 할인순'],
    };
    final selected = switch (type) {
      '쇼핑몰' => _mall,
      '가격대' => _priceRange,
      '색상' => _color,
      _ => _sort,
    };

    final result = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(type, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ...options.map(
                (option) => RadioGroup<String?>(
                  groupValue: selected,
                  onChanged: (value) => Navigator.of(sheetContext).pop(value),
                  child: RadioListTile<String?>(
                    value: option,
                    title: Text(option ?? '전체'),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      switch (type) {
        case '쇼핑몰':
          _mall = result;
        case '가격대':
          _priceRange = result;
        case '색상':
          _color = result;
        default:
          _sort = result ?? '인기순';
      }
    });
  }

  void _openProduct(Product product) {
    context.push('/shop/product/${product.id}');
  }

  void _startTryOn(Product product) {
    ref.read(selectedProductProvider.notifier).selectProduct(product);
    ref
        .read(selectedColorProvider.notifier)
        .selectColor(
          product.availableColors.isEmpty
              ? null
              : product.availableColors.first,
        );
    ref
        .read(selectedSizeProvider.notifier)
        .selectSize(
          product.availableSizes.isEmpty ? null : product.availableSizes.first,
        );
    if (ref.read(selectedUserPhotoProvider) == null) {
      context.push('/photo');
    } else {
      context.go('/try-on');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final productsAsync = ref.watch(filteredProductsProvider);
    final favoriteIds = ref.watch(favoriteProductIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('쇼핑'),
        actions: [
          IconButton(
            tooltip: '찜한 상품',
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('찜한 상품 ${favoriteIds.length}개가 있어요.')),
            ),
            icon: Badge(
              isLabelVisible: favoriteIds.isNotEmpty,
              label: Text('${favoriteIds.length}'),
              child: const Icon(Icons.favorite_border_rounded),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => ref
                          .read(productSearchQueryProvider.notifier)
                          .setQuery(value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '브랜드 또는 상품을 검색해보세요',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: '검색어 지우기',
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(productSearchQueryProvider.notifier)
                                      .clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 62,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return Center(
                          child: _CategoryButton(
                            label: category,
                            selected: category == selectedCategory,
                            onTap: () => ref
                                .read(selectedCategoryProvider.notifier)
                                .selectCategory(category),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterButton(
                          label: _mall ?? '쇼핑몰',
                          active: _mall != null,
                          onTap: () => _showFilterSheet(type: '쇼핑몰'),
                        ),
                        _FilterButton(
                          label: _priceRange ?? '가격대',
                          active: _priceRange != null,
                          onTap: () => _showFilterSheet(type: '가격대'),
                        ),
                        _FilterButton(
                          label: _color ?? '색상',
                          active: _color != null,
                          onTap: () => _showFilterSheet(type: '색상'),
                        ),
                        _FilterButton(
                          label: _sort,
                          active: _sort != '인기순',
                          onTap: () => _showFilterSheet(type: '정렬'),
                        ),
                      ],
                    ),
                  ),
                ),
                productsAsync.when(
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyProducts(
                      icon: Icons.cloud_off_outlined,
                      title: '상품을 불러오지 못했어요',
                      description: '잠시 후 다시 시도해 주세요.',
                      actionLabel: '다시 불러오기',
                      onAction: () => ref.invalidate(productsProvider),
                    ),
                  ),
                  data: (products) {
                    final filtered = _applyLocalFilters(products);
                    if (filtered.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyProducts(
                          icon: Icons.search_off_rounded,
                          title: '조건에 맞는 상품이 없어요',
                          description: '검색어나 필터를 조금 넓혀보세요.',
                          actionLabel: '필터 초기화',
                          onAction: () {
                            _searchController.clear();
                            ref
                                .read(productSearchQueryProvider.notifier)
                                .clear();
                            ref.read(selectedCategoryProvider.notifier).reset();
                            setState(() {
                              _mall = null;
                              _priceRange = null;
                              _color = null;
                              _sort = '인기순';
                            });
                          },
                        ),
                      );
                    }

                    return SliverMainAxisGroup(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          sliver: SliverToBoxAdapter(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Align(
                                key: ValueKey(
                                  '$selectedCategory|$_mall|$_priceRange|'
                                  '$_color|$_sort|${_searchController.text}',
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${filtered.length}개의 스타일',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: AppColors.secondaryText,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          sliver: SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.crossAxisExtent;
                              final columns = switch (width) {
                                < 520 => 2,
                                < 760 => 3,
                                < 980 => 4,
                                _ => 5,
                              };
                              const spacing = 14.0;
                              final cardWidth =
                                  (width - spacing * (columns - 1)) / columns;
                              final textScale = MediaQuery.textScalerOf(
                                context,
                              ).scale(1);
                              final textScaleExtra = (textScale - 1)
                                  .clamp(0.0, 0.35)
                                  .toDouble();
                              return SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: spacing,
                                      mainAxisSpacing: 20,
                                      mainAxisExtent:
                                          cardWidth * 1.25 +
                                          148 +
                                          textScaleExtra * 150,
                                    ),
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final product = filtered[index];
                                  return _ShopProductCard(
                                    product: product,
                                    isFavorite: favoriteIds.contains(
                                      product.id,
                                    ),
                                    onTap: () => _openProduct(product),
                                    onFavorite: () => ref
                                        .read(
                                          favoriteProductIdsProvider.notifier,
                                        )
                                        .toggle(product.id),
                                    onTryOn: () => _startTryOn(product),
                                  );
                                }, childCount: filtered.length),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          foregroundColor: active
              ? AppColors.primaryPurple
              : AppColors.mainText,
          backgroundColor: active ? AppColors.lightPurple : AppColors.surface,
        ),
        iconAlignment: IconAlignment.end,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label 카테고리',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: selected ? null : AppColors.surface,
          gradient: selected ? AppColors.primaryGradient : null,
          borderRadius: BorderRadius.circular(14),
          border: selected ? null : Border.all(color: AppColors.divider),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? Colors.white : AppColors.mainText,
                      fontWeight: FontWeight.w700,
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

class _ShopProductCard extends StatefulWidget {
  const _ShopProductCard({
    required this.product,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    required this.onTryOn,
  });

  final Product product;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final VoidCallback onTryOn;

  @override
  State<_ShopProductCard> createState() => _ShopProductCardState();
}

class _ShopProductCardState extends State<_ShopProductCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: const Duration(milliseconds: 100),
      child: Semantics(
        button: true,
        label: '${product.brand} ${product.name}, ${product.price}원',
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ProductImage(
                        assetPath: product.displayImage,
                        semanticLabel: '${product.name} 상품 이미지',
                        placeholderLabel: product.brand,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(16),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: widget.isFavorite ? '찜 해제' : '찜하기',
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 44,
                          ),
                          onPressed: widget.onFavorite,
                          icon: Icon(
                            widget.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: widget.isFavorite
                                ? AppColors.error
                                : AppColors.mainText,
                          ),
                        ),
                      ),
                    ),
                    if (product.discountPercent > 0)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryNavy,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${product.discountPercent}%',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${product.mallName} · ${product.brand}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mainText,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_formatPrice(product.price)}원',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton.tonalIcon(
                  onPressed: widget.onTryOn,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                  label: const Text('입혀보기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.secondaryText),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

String _formatPrice(int value) {
  final digits = value.toString();
  final result = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) result.write(',');
    result.write(digits[index]);
  }
  return result.toString();
}
