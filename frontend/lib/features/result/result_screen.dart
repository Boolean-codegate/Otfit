import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_primary_button.dart';
import '../../core/widgets/price_text.dart';
import '../../core/widgets/product_image.dart';
import '../../models/fitting_result.dart';
import '../../providers/app_providers.dart';

class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _showAfter = true;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _retry() {
    ref.read(tryOnProgressProvider.notifier).reset();
    context.go('/try-on');
  }

  /// 결과 이미지를 내보내기(export) 후 브라우저로 다운로드/열기.
  Future<void> _downloadResult(FittingResult result) async {
    final resultId = result.generationResult?.id;
    if (resultId == null) {
      _showMessage('데모 결과는 다운로드를 지원하지 않아요.');
      return;
    }
    try {
      _showMessage('이미지를 준비하고 있어요…');
      final export = await ref
          .read(tryOnRepositoryProvider)
          .exportResult(resultId: resultId, ratio: '4:5');
      if (!mounted) return;
      if (export.url.startsWith('http')) {
        await launchUrl(
          Uri.parse(export.url),
          mode: LaunchMode.externalApplication,
        );
        _showMessage(export.watermarked
            ? '새 탭에서 이미지를 저장하세요. (무료 플랜은 워터마크 포함)'
            : '새 탭에서 이미지를 저장하세요.');
      } else {
        _showMessage('다운로드 URL을 만들지 못했어요.');
      }
    } on Object catch (error) {
      if (mounted) _showMessage('다운로드 실패: $error');
    }
  }

  /// 피팅 결과를 SNS 피드에 게시 (계약 §10 POST /posts).
  /// OTFIT 아이덴티티: 비포→애프터 변신을 기본으로 함께 공개한다.
  Future<void> _publishToFeed(FittingResult result) async {
    final controller = TextEditingController();
    final beforePhoto = ref.read(uploadedPhotoProvider);
    var includeBefore = beforePhoto != null; // 기본 ON — 변신 강조
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('변신 게시하기',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLength: 300,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '이 룩 어때요? 살까 말까 물어보세요 🙋',
                ),
              ),
              if (beforePhoto != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: includeBefore,
                  onChanged: (value) =>
                      setSheetState(() => includeBefore = value),
                  title: const Text('비포 사진 함께 공개'),
                  subtitle: const Text('비포 → 애프터 변신이 피드에서 전환돼요 ✨'),
                ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text('게시하기'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(feedProvider.notifier).publish(
            resultId: result.generationResult?.id,
            productId:
                result.generationResult == null ? result.product.id : null,
            caption: controller.text.trim(),
            includeBefore: includeBefore,
          );
      if (!mounted) return;
      _showMessage('변신을 게시했어요! 투표 반응을 확인해보세요.');
      context.go('/feed');
    } on Object catch (error) {
      if (mounted) _showMessage('게시 실패: $error');
    }
  }

  void _openPurchase(FittingResult result) {
    final url = result.product.productUrl;
    if (url.startsWith('http')) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      return;
    }
    _showMessage('이 옷은 아직 구매 링크가 준비되지 않았어요.');
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(currentFittingResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 피팅 완료'),
        actions: [
          IconButton(
            tooltip: '다시 시도',
            onPressed: result == null ? null : _retry,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: result == null
          ? null
          : _ResultBottomActions(
              onSave: () => _downloadResult(result),
              onShare: () => _publishToFeed(result),
              onOther: () => context.go('/shop'),
              onPurchase: () => _openPurchase(result),
            ),
      body: SafeArea(
        top: false,
        bottom: result == null,
        child: result == null
            ? _NoResult(onStart: () => context.go('/try-on'))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 800;
                        final comparison = _ComparisonPanel(
                          result: result,
                          showAfter: _showAfter,
                          onChanged: (value) =>
                              setState(() => _showAfter = value),
                        );
                        final details = _ResultDetails(result: result);
                        if (!wide) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              comparison,
                              const SizedBox(height: 22),
                              details,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 12, child: comparison),
                            const SizedBox(width: 36),
                            Expanded(flex: 9, child: details),
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

class _ComparisonPanel extends StatelessWidget {
  const _ComparisonPanel({
    required this.result,
    required this.showAfter,
    required this.onChanged,
  });

  final FittingResult result;
  final bool showAfter;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: false,
                label: Text('Before'),
                icon: Icon(Icons.person_outline_rounded),
              ),
              ButtonSegment<bool>(
                value: true,
                label: Text('After'),
                icon: Icon(Icons.auto_awesome_rounded),
              ),
            ],
            selected: {showAfter},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ),
        const SizedBox(height: 16),
        AspectRatio(
          aspectRatio: 4 / 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOut,
              child: showAfter
                  ? _ResultImage(
                      key: const ValueKey('after'),
                      assetPath: result.resultImageAsset,
                      productName: result.product.name,
                    )
                  : _BeforeImage(
                      key: const ValueKey('before'),
                      bytes: result.userPhoto.bytes,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppColors.secondaryText,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                result.disclaimer,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.secondaryText),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BeforeImage extends StatelessWidget {
  const _BeforeImage({super.key, required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '피팅 전 원본 사용자 사진',
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const _ResultPlaceholder(before: true),
      ),
    );
  }
}

class _ResultImage extends StatelessWidget {
  const _ResultImage({
    super.key,
    required this.assetPath,
    required this.productName,
  });

  final String assetPath;
  final String productName;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ProductImage(
          assetPath: assetPath,
          semanticLabel: '$productName AI 피팅 결과 이미지',
          placeholderLabel: 'AI FIT',
          borderRadius: BorderRadius.zero,
          icon: Icons.auto_awesome_rounded,
          fallback: const MockFittingIllustration(),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 15),
                SizedBox(width: 5),
                Text(
                  'AI FIT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultPlaceholder extends StatelessWidget {
  const _ResultPlaceholder({required this.before});

  final bool before;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.softGradient),
      child: Center(
        child: Icon(
          before ? Icons.person_outline_rounded : Icons.auto_awesome_rounded,
          size: 76,
          color: AppColors.primaryPurple,
        ),
      ),
    );
  }
}

class MockFittingIllustration extends StatelessWidget {
  const MockFittingIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'AI로 생성한 가상 피팅 샘플 일러스트',
      child: const CustomPaint(
        painter: _MockFittingPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _MockFittingPainter extends CustomPainter {
  const _MockFittingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()..shader = AppColors.softGradient.createShader(bounds),
    );

    final glowPaint = Paint()
      ..color = AppColors.primaryPurple.withValues(alpha: 0.09);
    canvas
      ..drawCircle(
        Offset(size.width * 0.2, size.height * 0.2),
        size.width * 0.34,
        glowPaint,
      )
      ..drawCircle(
        Offset(size.width * 0.88, size.height * 0.72),
        size.width * 0.43,
        glowPaint,
      );

    final centerX = size.width / 2;
    final skin = Paint()..color = const Color(0xFFF1C8AA);
    final hair = Paint()..color = AppColors.primaryNavy;
    final trousers = Paint()..color = const Color(0xFF283451);
    final shoe = Paint()..color = const Color(0xFF161B2D);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, size.height * 0.16),
        width: size.width * 0.18,
        height: size.height * 0.13,
      ),
      skin,
    );
    final hairPath = Path()
      ..moveTo(centerX - size.width * 0.095, size.height * 0.165)
      ..quadraticBezierTo(
        centerX - size.width * 0.07,
        size.height * 0.075,
        centerX,
        size.height * 0.09,
      )
      ..quadraticBezierTo(
        centerX + size.width * 0.105,
        size.height * 0.085,
        centerX + size.width * 0.09,
        size.height * 0.185,
      )
      ..quadraticBezierTo(
        centerX + size.width * 0.025,
        size.height * 0.12,
        centerX - size.width * 0.095,
        size.height * 0.165,
      )
      ..close();
    canvas.drawPath(hairPath, hair);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, size.height * 0.235),
          width: size.width * 0.07,
          height: size.height * 0.07,
        ),
        const Radius.circular(10),
      ),
      skin,
    );

    final jacketBounds = Rect.fromLTRB(
      size.width * 0.25,
      size.height * 0.245,
      size.width * 0.75,
      size.height * 0.59,
    );
    final jacketPaint = Paint()
      ..shader = AppColors.primaryGradient.createShader(jacketBounds);
    final jacket = Path()
      ..moveTo(centerX - size.width * 0.09, size.height * 0.245)
      ..lineTo(size.width * 0.31, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height * 0.42,
        size.width * 0.27,
        size.height * 0.58,
      )
      ..lineTo(centerX - size.width * 0.035, size.height * 0.61)
      ..lineTo(centerX, size.height * 0.31)
      ..lineTo(centerX + size.width * 0.035, size.height * 0.61)
      ..lineTo(size.width * 0.73, size.height * 0.58)
      ..quadraticBezierTo(
        size.width * 0.76,
        size.height * 0.42,
        size.width * 0.69,
        size.height * 0.28,
      )
      ..lineTo(centerX + size.width * 0.09, size.height * 0.245)
      ..quadraticBezierTo(
        centerX,
        size.height * 0.3,
        centerX - size.width * 0.09,
        size.height * 0.245,
      )
      ..close();
    canvas.drawPath(jacket, jacketPaint);

    final innerShirt = Path()
      ..moveTo(centerX - size.width * 0.075, size.height * 0.27)
      ..lineTo(centerX, size.height * 0.34)
      ..lineTo(centerX + size.width * 0.075, size.height * 0.27)
      ..lineTo(centerX + size.width * 0.035, size.height * 0.54)
      ..lineTo(centerX - size.width * 0.035, size.height * 0.54)
      ..close();
    canvas.drawPath(innerShirt, Paint()..color = AppColors.surface);

    final leftArm = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        size.width * 0.205,
        size.height * 0.29,
        size.width * 0.32,
        size.height * 0.64,
      ),
      Radius.circular(size.width * 0.07),
    );
    final rightArm = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        size.width * 0.68,
        size.height * 0.29,
        size.width * 0.795,
        size.height * 0.64,
      ),
      Radius.circular(size.width * 0.07),
    );
    canvas
      ..drawRRect(leftArm, jacketPaint)
      ..drawRRect(rightArm, jacketPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          size.width * 0.32,
          size.height * 0.56,
          size.width * 0.49,
          size.height * 0.9,
        ),
        Radius.circular(size.width * 0.045),
      ),
      trousers,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          size.width * 0.51,
          size.height * 0.56,
          size.width * 0.68,
          size.height * 0.9,
        ),
        Radius.circular(size.width * 0.045),
      ),
      trousers,
    );
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            size.width * 0.28,
            size.height * 0.875,
            size.width * 0.49,
            size.height * 0.93,
          ),
          const Radius.circular(20),
        ),
        shoe,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            size.width * 0.51,
            size.height * 0.875,
            size.width * 0.72,
            size.height * 0.93,
          ),
          const Radius.circular(20),
        ),
        shoe,
      );

    final scanY = size.height * 0.46;
    canvas.drawRect(
      Rect.fromLTWH(0, scanY - 2, size.width, 4),
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.primaryPurple,
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, scanY - 2, size.width, 4)),
    );

    final sparkle = Paint()..color = AppColors.primaryPurple;
    for (final point in <Offset>[
      Offset(size.width * 0.18, size.height * 0.24),
      Offset(size.width * 0.83, size.height * 0.38),
      Offset(size.width * 0.78, size.height * 0.16),
    ]) {
      canvas
        ..drawCircle(point, size.width * 0.012, sparkle)
        ..drawCircle(
          point,
          size.width * 0.028,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = AppColors.primaryPurple.withValues(alpha: 0.34),
        );
    }
  }

  @override
  bool shouldRepaint(covariant _MockFittingPainter oldDelegate) => false;
}

class _ResultDetails extends StatelessWidget {
  const _ResultDetails({required this.result});

  final FittingResult result;

  @override
  Widget build(BuildContext context) {
    final product = result.product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                child: AspectRatio(
                  aspectRatio: 4 / 5,
                  child: ProductImage(
                    assetPath: product.displayImage,
                    semanticLabel: '${product.name} 상품 이미지',
                    placeholderLabel: product.brand,
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.brand,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryPurple,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 9),
                    PriceText(price: product.price, compact: true),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _OptionPill(label: '컬러 ${result.selectedColor}'),
                        _OptionPill(label: '사이즈 ${result.selectedSize}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.softGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 20,
                    color: AppColors.primaryPurple,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '피팅 품질 확인 완료',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                '인물 특징을 유지하면서 선택한 의상의 색감과 형태를 자연스럽게 시각화했어요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.55,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionPill extends StatelessWidget {
  const _OptionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _ResultBottomActions extends StatelessWidget {
  const _ResultBottomActions({
    required this.onSave,
    required this.onShare,
    required this.onOther,
    required this.onPurchase,
  });

  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onOther;
  final VoidCallback onPurchase;

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
            constraints: const BoxConstraints(maxWidth: 920),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 620;
                  if (compact) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onSave,
                                icon: const Icon(Icons.download_outlined),
                                label: const Text('사진 저장'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: onShare,
                                icon: const Icon(Icons.dynamic_feed_rounded),
                                label: const Text('피드에 게시'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: onOther,
                                child: const Text('다른 옷 입어보기'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: GradientPrimaryButton(
                                label: '이 상품 구매하기',
                                onPressed: onPurchase,
                                height: 50,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      IconButton.outlined(
                        tooltip: '사진 저장',
                        onPressed: onSave,
                        icon: const Icon(Icons.download_outlined),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: '피드에 게시',
                        onPressed: onShare,
                        icon: const Icon(Icons.dynamic_feed_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onOther,
                          child: const Text('다른 옷 입어보기'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: GradientPrimaryButton(
                          label: '이 상품 구매하기',
                          onPressed: onPurchase,
                        ),
                      ),
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

class _NoResult extends StatelessWidget {
  const _NoResult({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 64,
                color: AppColors.primaryPurple,
              ),
              const SizedBox(height: 18),
              Text(
                '아직 완성된 피팅 결과가 없어요',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '사진과 옷을 선택해 첫 AI 피팅을 시작해 보세요.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              GradientPrimaryButton(label: 'AI 피팅 시작하기', onPressed: onStart),
            ],
          ),
        ),
      ),
    );
  }
}
