import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state_card.dart';
import '../../core/widgets/garment_preview_card.dart';
import '../../core/widgets/gradient_primary_button.dart';
import '../../core/widgets/user_photo_card.dart';
import '../../models/product.dart';
import '../../providers/app_providers.dart';

class TryOnScreen extends ConsumerStatefulWidget {
  const TryOnScreen({super.key});

  @override
  ConsumerState<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends ConsumerState<TryOnScreen> {
  bool _isOpeningProcess = false;

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
          content: const Text(
            'AI 피팅을 위해 선택한 사진을 처리하는 데 동의해 주세요. 현재 MVP에서는 모든 처리가 기기 내 mock 데이터로만 동작합니다.',
          ),
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

  @override
  Widget build(BuildContext context) {
    final photo = ref.watch(selectedUserPhotoProvider);
    final product = ref.watch(selectedProductProvider);
    final selectedColor = ref.watch(selectedColorProvider);
    final selectedSize = ref.watch(selectedSizeProvider);
    final canStart = photo != null && product != null;

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
                    '사진과 옷을 확인해 주세요',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '현재 선택을 유지한 채 언제든 사진이나 상품을 바꿀 수 있어요.',
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
                      final garmentCard = product == null
                          ? EmptyStateCard(
                              icon: Icons.checkroom_outlined,
                              title: '입어볼 옷을 골라주세요',
                              description: '쇼핑에서 원하는 상품을 선택해 주세요.',
                              actionLabel: '상품 둘러보기',
                              onAction: () => context.go('/shop'),
                            )
                          : GarmentPreviewCard(
                              product: product,
                              selectedColor: selectedColor,
                              selectedSize: selectedSize,
                              isSelected: true,
                              onTap: () =>
                                  context.push('/shop/product/${product.id}'),
                            );

                      if (!wide) {
                        return Column(
                          children: [
                            photoCard,
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: _TransformMark(vertical: true),
                            ),
                            garmentCard,
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
                          Expanded(child: garmentCard),
                        ],
                      );
                    },
                  ),
                  if (product != null) ...[
                    const SizedBox(height: 26),
                    _OptionSelector(
                      product: product,
                      selectedColor: selectedColor,
                      selectedSize: selectedSize,
                      onColor: (color) => ref
                          .read(selectedColorProvider.notifier)
                          .selectColor(color),
                      onSize: (size) => ref
                          .read(selectedSizeProvider.notifier)
                          .selectSize(size),
                    ),
                  ],
                  const SizedBox(height: 26),
                  GradientPrimaryButton(
                    label: '이 옷 입혀보기',
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
                          label: const Text('다른 옷 선택'),
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

class _OptionSelector extends StatelessWidget {
  const _OptionSelector({
    required this.product,
    required this.selectedColor,
    required this.selectedSize,
    required this.onColor,
    required this.onSize,
  });

  final Product product;
  final String? selectedColor;
  final String? selectedSize;
  final ValueChanged<String> onColor;
  final ValueChanged<String> onSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colorOptions = _Options(
            title: '컬러',
            values: product.availableColors,
            selected: selectedColor,
            onSelected: onColor,
          );
          final sizeOptions = _Options(
            title: '사이즈',
            values: product.availableSizes,
            selected: selectedSize,
            onSelected: onSize,
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [colorOptions, const SizedBox(height: 18), sizeOptions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: colorOptions),
              const SizedBox(width: 28),
              Expanded(child: sizeOptions),
            ],
          );
        },
      ),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> values;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (value) => ChoiceChip(
                  label: Text(value),
                  selected: value == selected,
                  onSelected: (_) => onSelected(value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
