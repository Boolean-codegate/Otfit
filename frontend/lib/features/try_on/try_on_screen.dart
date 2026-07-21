import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state_card.dart';
import '../../core/widgets/gradient_primary_button.dart';
import '../../core/widgets/user_photo_card.dart';
import '../../models/product.dart';
import '../../providers/app_providers.dart';

/// AI 피팅 준비 — 옷/하의/액세서리를 슬롯에 담아 조합 피팅.
/// 1개만 골라도 되고, 최대 3개(각 슬롯 1개)까지 한 번에 입어볼 수 있다.
class TryOnScreen extends ConsumerStatefulWidget {
  const TryOnScreen({super.key});

  @override
  ConsumerState<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends ConsumerState<TryOnScreen> {
  bool _isOpeningProcess = false;

  @override
  void initState() {
    super.initState();
    // 상품 상세 '입혀보기'로 들어온 경우 해당 상품을 슬롯에 배치
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selected = ref.read(selectedProductProvider);
      if (selected != null) {
        ref.read(outfitProvider.notifier).select(selected);
      }
    });
  }

  Future<void> _start() async {
    if (_isOpeningProcess || ref.read(tryOnProgressProvider).isLoading) return;
    setState(() => _isOpeningProcess = true);

    final hasConsent = ref.read(imageProcessingConsentProvider);
    if (!hasConsent) {
      final agreed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.privacy_tip_outlined),
          title: const Text('이미지 처리 동의'),
          content: const Text('AI 피팅을 위해 선택한 사진을 처리하는 데 동의해 주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('동의하고 계속'),
            ),
          ],
        ),
      );
      if (agreed != true || !mounted) {
        if (mounted) setState(() => _isOpeningProcess = false);
        return;
      }
      ref.read(imageProcessingConsentProvider.notifier).grant();
    }
    if (!mounted) return;
    await context.push('/try-on/process');
    if (mounted) setState(() => _isOpeningProcess = false);
  }

  /// 슬롯별 상품 고르기 시트 — 즉시 열리고, 로딩/에러도 시트 안에서 보여준다.
  Future<void> _pickForSlot(String slot) async {
    final allowed = switch (slot) {
      OutfitController.slotPants => const {ProductCategories.pants},
      OutfitController.slotShoes => const {ProductCategories.shoes},
      OutfitController.slotAccessory => const {ProductCategories.accessory},
      _ => const {
          ProductCategories.top,
          ProductCategories.jacket,
          ProductCategories.shirt,
          ProductCategories.dress,
        },
    };
    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Text(
                  '${_slotLabel(slot)} 고르기',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final products = ref.watch(productsProvider);
                    return products.when(
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (error, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('상품을 불러오지 못했어요'),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: () =>
                                  ref.invalidate(productsProvider),
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                      data: (items) {
                        final candidates = items
                            .where((product) =>
                                allowed.contains(product.category))
                            .toList(growable: false);
                        if (candidates.isEmpty) {
                          return const Center(
                              child: Text('아직 이 카테고리에 상품이 없어요.'));
                        }
                        return GridView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 160,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: candidates.length,
                          itemBuilder: (context, index) {
                            final product = candidates[index];
                            return GestureDetector(
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(product),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      child: _productImage(product),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    product.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      ref.read(outfitProvider.notifier).select(picked);
    }
  }

  static String _slotLabel(String slot) => switch (slot) {
        OutfitController.slotPants => '하의',
        OutfitController.slotShoes => '신발',
        OutfitController.slotAccessory => '액세서리',
        _ => '옷',
      };

  static Widget _productImage(Product product) =>
      product.displayImage.startsWith('assets/')
          ? Image.asset(product.displayImage, fit: BoxFit.cover)
          : Image.network(
              product.displayImage,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const ColoredBox(
                color: AppColors.surfaceMuted,
                child: Icon(Icons.checkroom_rounded),
              ),
            );

  @override
  Widget build(BuildContext context) {
    // 상품 상세에서 새 상품을 고르고 돌아와도 슬롯에 반영되도록 감시
    ref.listen(selectedProductProvider, (previous, next) {
      if (next != null && previous?.id != next.id) {
        ref.read(outfitProvider.notifier).select(next);
      }
    });
    final photo = ref.watch(selectedUserPhotoProvider);
    final outfit = ref.watch(outfitProvider);
    final items = ref.watch(outfitItemsProvider);
    final canStart = photo != null && items.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 피팅 준비')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '사진과 아이템을 확인해 주세요',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '옷·하의·액세서리 중 원하는 것만 담으면 돼요 — 1개만 골라도 충분해요!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 720;
                      final photoCard = photo == null
                          ? EmptyStateCard(
                              icon: Icons.add_photo_alternate_outlined,
                              title: '내 사진이 필요해요',
                              description: '정면에서 촬영한 사진을 먼저 등록해 주세요.',
                              actionLabel: '사진 선택',
                              onAction: () => context.push('/photo'),
                            )
                          : UserPhotoCard(
                              image: Image.memory(
                                photo.bytes,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: AppColors.background,
                                  child: Icon(
                                    Icons.person_outline_rounded,
                                    size: 58,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                              title: '선택한 내 사진',
                              subtitle: photo.name,
                              isSelected: true,
                              onChange: () => context.push('/photo'),
                            );
                      final slotsCard = _OutfitSlots(
                        outfit: outfit,
                        onPick: _pickForSlot,
                        onClear: (slot) =>
                            ref.read(outfitProvider.notifier).clearSlot(slot),
                      );

                      if (!wide) {
                        return Column(
                          children: [
                            photoCard,
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: _TransformMark(vertical: true),
                            ),
                            slotsCard,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: photoCard),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 22),
                            child: _TransformMark(),
                          ),
                          Expanded(child: slotsCard),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  GradientPrimaryButton(
                    label: items.isEmpty
                        ? '아이템을 골라주세요'
                        : '피팅 시작하기 (${items.length}개 아이템)',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: canStart ? _start : null,
                    isEnabled: canStart && !_isOpeningProcess,
                    isLoading: _isOpeningProcess,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => context.push('/photo'),
                          icon: const Icon(Icons.photo_outlined),
                          label: const Text('사진 변경'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => context.go('/shop'),
                          icon: const Icon(Icons.checkroom_outlined),
                          label: const Text('쇼핑에서 더 보기'),
                        ),
                      ),
                    ],
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

/// 옷/하의/액세서리 3개 슬롯 — 탭해서 담고, X로 뺀다.
class _OutfitSlots extends StatelessWidget {
  const _OutfitSlots({
    required this.outfit,
    required this.onPick,
    required this.onClear,
  });

  final Map<String, Product?> outfit;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onClear;

  static const _slotMeta = [
    (OutfitController.slotClothes, '옷', Icons.checkroom_rounded),
    (OutfitController.slotPants, '하의', Icons.straighten_rounded),
    (OutfitController.slotShoes, '신발', Icons.ice_skating_rounded),
    (OutfitController.slotAccessory, '액세서리', Icons.watch_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('입어볼 아이템', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 3),
          Text(
            '원하는 슬롯만 채우면 돼요',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (slot, label, icon) in _slotMeta) ...[
                if (slot != OutfitController.slotClothes)
                  const SizedBox(width: 10),
                Expanded(
                  child: _SlotTile(
                    label: label,
                    icon: icon,
                    product: outfit[slot],
                    onTap: () => onPick(slot),
                    onClear: () => onClear(slot),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.label,
    required this.icon,
    required this.product,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final IconData icon;
  final Product? product;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final filled = product != null;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 0.72,
        child: Container(
          decoration: BoxDecoration(
            color: filled ? null : AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: filled ? AppColors.primaryPurple : AppColors.divider,
              width: filled ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: filled
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    _TryOnScreenState._productImage(product!),
                    // 라벨 배지
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    // 제거 버튼
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: onClear,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 14, 6, 5),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                        child: Text(
                          product!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: AppColors.disabled, size: 26),
                    const SizedBox(height: 6),
                    Text(label,
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(
                      '+ 담기',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _TransformMark extends StatelessWidget {
  const _TransformMark({this.vertical = false});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AI로 합성',
      child: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
        ),
        child: Icon(
          vertical ? Icons.arrow_downward_rounded : Icons.arrow_forward_rounded,
          color: Colors.white,
        ),
      ),
    );
  }
}
