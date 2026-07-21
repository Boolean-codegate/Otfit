import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/product.dart';
import '../../providers/app_providers.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(productByIdProvider(productId))
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => _ProductLoadError(
            onRetry: () => ref.invalidate(productByIdProvider(productId)),
          ),
          data: (product) => product == null
              ? _ProductLoadError(onRetry: () => context.go('/shop'))
              : _ProductDetailContent(product: product),
        );
  }
}

class _ProductDetailContent extends ConsumerStatefulWidget {
  const _ProductDetailContent({required this.product});

  final Product product;

  @override
  ConsumerState<_ProductDetailContent> createState() =>
      _ProductDetailContentState();
}

class _ProductDetailContentState extends ConsumerState<_ProductDetailContent> {
  late final Product _product;
  late String _color;
  late String _size;
  int _thumbnailIndex = 0;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _color = _product.availableColors.isEmpty
        ? '기본 색상'
        : _product.availableColors.first;
    _size = _product.availableSizes.isEmpty
        ? '기본 사이즈'
        : _product.availableSizes.first;
  }

  void _startTryOn() {
    ref.read(selectedProductProvider.notifier).selectProduct(_product);
    ref.read(selectedColorProvider.notifier).selectColor(_color);
    ref.read(selectedSizeProvider.notifier).selectSize(_size);

    if (ref.read(selectedUserPhotoProvider) == null) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.add_photo_alternate_outlined),
          title: const Text('먼저 내 사진을 등록해 주세요'),
          content: const Text(
            '선택한 상품은 그대로 보관할게요. 사진을 고르면 바로 AI 피팅 준비 단계로 이어집니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.push('/photo');
              },
              child: const Text('사진 선택하기'),
            ),
          ],
        ),
      );
      return;
    }
    context.go('/try-on');
  }

  void _openPurchase() {
    final url = _product.productUrl;
    if (url.startsWith('http')) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이 옷은 아직 구매 링크가 준비되지 않았어요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(
      favoriteProductIdsProvider.select((ids) => ids.contains(_product.id)),
    );
    final availableThumbnailPaths = <String>{
      _product.displayImage,
      ..._product.thumbnailAssets,
    }.where((path) => path.isNotEmpty).toList(growable: false);
    final thumbnailPaths = availableThumbnailPaths.isEmpty
        ? const <String>['']
        : availableThumbnailPaths;

    return Scaffold(
      appBar: AppBar(
        title: const Text('상품 상세'),
        actions: [
          IconButton(
            tooltip: isFavorite ? '찜 해제' : '찜하기',
            onPressed: () => ref
                .read(favoriteProductIdsProvider.notifier)
                .toggle(_product.id),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                isFavorite ? Icons.favorite_rounded : Icons.favorite_border,
                key: ValueKey(isFavorite),
                color: isFavorite ? AppColors.error : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: _DetailActionBar(
        onPurchase: _openPurchase,
        onTryOn: _startTryOn,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final imageSection = _ImageGallery(
                    product: _product,
                    paths: thumbnailPaths,
                    selectedIndex: _thumbnailIndex,
                    onSelect: (index) =>
                        setState(() => _thumbnailIndex = index),
                  );
                  final infoSection = _ProductInformation(
                    product: _product,
                    selectedColor: _color,
                    selectedSize: _size,
                    onColorChanged: (value) => setState(() => _color = value),
                    onSizeChanged: (value) => setState(() => _size = value),
                  );

                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        imageSection,
                        const SizedBox(height: 28),
                        infoSection,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: imageSection),
                      const SizedBox(width: 48),
                      Expanded(flex: 10, child: infoSection),
                    ],
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

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({
    required this.product,
    required this.paths,
    required this.selectedIndex,
    required this.onSelect,
  });

  final Product product;
  final List<String> paths;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: _ProductAsset(
            path: paths[selectedIndex],
            semanticsLabel: '${product.brand} ${product.name} 상품 이미지',
            radius: 20,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: paths.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => InkWell(
              onTap: () => onSelect(index),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 58,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selectedIndex == index
                        ? AppColors.primaryPurple
                        : AppColors.divider,
                    width: selectedIndex == index ? 2 : 1,
                  ),
                ),
                child: _ProductAsset(
                  path: paths[index],
                  semanticsLabel: '${index + 1}번째 상품 썸네일',
                  radius: 10,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductInformation extends StatelessWidget {
  const _ProductInformation({
    required this.product,
    required this.selectedColor,
    required this.selectedSize,
    required this.onColorChanged,
    required this.onSizeChanged,
  });

  final Product product;
  final String selectedColor;
  final String selectedSize;
  final ValueChanged<String> onColorChanged;
  final ValueChanged<String> onSizeChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lightPurple,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                product.mallName,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.primaryPurple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.verified_outlined,
              size: 17,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(width: 4),
            Text('연결 쇼핑몰', style: textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          product.brand,
          style: textTheme.titleSmall?.copyWith(
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(product.name, style: textTheme.headlineSmall),
        const SizedBox(height: 16),
        _PriceBlock(product: product),
        const SizedBox(height: 30),
        _OptionTitle(label: '색상', selected: selectedColor),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: product.availableColors
              .map(
                (color) => ChoiceChip(
                  selected: color == selectedColor,
                  onSelected: (_) => onColorChanged(color),
                  avatar: CircleAvatar(
                    radius: 8,
                    backgroundColor: _swatchFor(color),
                  ),
                  label: Text(color),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
        _OptionTitle(label: '사이즈', selected: selectedSize),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: product.availableSizes
              .map(
                (size) => ChoiceChip(
                  selected: size == selectedSize,
                  onSelected: (_) => onSizeChanged(size),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 34),
                    child: Text(size, textAlign: TextAlign.center),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 22),
        Text('상품 설명', style: textTheme.titleMedium),
        const SizedBox(height: 10),
        Text(
          product.description,
          style: textTheme.bodyMedium?.copyWith(height: 1.65),
        ),
        const SizedBox(height: 26),
        const _DeliveryRow(
          icon: Icons.local_shipping_outlined,
          title: '배송 정보',
          description: '평균 2~3일 이내 출고 · 무료 배송',
        ),
        const SizedBox(height: 12),
        const _DeliveryRow(
          icon: Icons.replay_rounded,
          title: '교환 및 반품',
          description: '수령 후 7일 이내 쇼핑몰 정책에 따라 가능',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '상품·재고·배송 정보는 연결 쇼핑몰 기준이며, 현재 화면은 서비스 체험을 위한 예시입니다.',
            style: textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _OptionTitle extends StatelessWidget {
  const _OptionTitle({required this.label, required this.selected});

  final String label;
  final String selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(width: 8),
        Text(
          selected,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.primaryPurple,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (product.originalPrice != null)
          Text(
            '${_formatPrice(product.originalPrice!)}원',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.secondaryText,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (product.discountPercent > 0) ...[
              Text(
                '${product.discountPercent}%',
                style: textTheme.titleLarge?.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              '${_formatPrice(product.price)}원',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.lightPurple,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, size: 20, color: AppColors.primaryPurple),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 3),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailActionBar extends StatelessWidget {
  const _DetailActionBar({required this.onPurchase, required this.onTryOn});

  final VoidCallback onPurchase;
  final VoidCallback onTryOn;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onPurchase,
                      child: const Text('구매하러 가기'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: FilledButton.icon(
                        onPressed: onTryOn,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('내 사진에 입혀보기'),
                      ),
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

class _ProductAsset extends StatelessWidget {
  const _ProductAsset({
    required this.path,
    required this.semanticsLabel,
    required this.radius,
  });

  final String path;
  final String semanticsLabel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.lightPurple, AppColors.background],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.checkroom_rounded,
          size: 54,
          color: AppColors.primaryPurple,
        ),
      ),
    );
    return Semantics(
      image: true,
      label: semanticsLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: path.startsWith('http://') || path.startsWith('https://')
            ? Image.network(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              )
            : Image.asset(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _ProductLoadError extends StatelessWidget {
  const _ProductLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상품 상세')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 56,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(height: 16),
                Text(
                  '상품 정보를 찾을 수 없어요',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '목록으로 돌아가 다른 상품을 선택해 주세요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: onRetry, child: const Text('다시 보기')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatPrice(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

Color _swatchFor(String value) => switch (value.toLowerCase()) {
  'black' || '블랙' => const Color(0xFF202124),
  'navy' || '네이비' => const Color(0xFF172A4A),
  'blue' || '블루' => const Color(0xFF6286C7),
  'ivory' || '아이보리' => const Color(0xFFF1EBDD),
  'beige' || '베이지' => const Color(0xFFC8B89F),
  'brown' || '브라운' => const Color(0xFF7A5948),
  'gray' || 'grey' || '그레이' => const Color(0xFF9297A1),
  'pink' || '핑크' => const Color(0xFFE5A7B5),
  'green' || '그린' => const Color(0xFF6D8C78),
  'white' || '화이트' => Colors.white,
  _ => const Color(0xFFD8D2EA),
};
