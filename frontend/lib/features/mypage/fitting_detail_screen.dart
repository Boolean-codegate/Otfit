import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/price_text.dart';
import '../../core/widgets/product_image.dart';
import '../../core/widgets/responsive_content.dart';
import '../../models/mypage.dart';
import '../../providers/app_providers.dart';

/// 피팅 결과 상세 — 기록 카드/목록에서 진입. 게시·상품 연결 액션 제공.
class FittingDetailScreen extends ConsumerWidget {
  const FittingDetailScreen({super.key, required this.fitting});

  final MyFitting fitting;

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 준비하고 있어요…')),
      );
      final export = await ref
          .read(tryOnRepositoryProvider)
          .exportResult(resultId: fitting.resultId, ratio: '4:5');
      if (!context.mounted) return;
      if (export.url.startsWith('http')) {
        await launchUrl(
          Uri.parse(export.url),
          mode: LaunchMode.externalApplication,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('데모 결과는 다운로드를 지원하지 않아요.')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('다운로드 실패: $error')));
      }
    }
  }

  Future<void> _publish(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final caption = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('피드에 게시', style: Theme.of(sheetContext).textTheme.titleLarge),
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
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(controller.text.trim()),
              child: const Text('게시하기'),
            ),
          ],
        ),
      ),
    );
    if (caption == null || !context.mounted) return;
    try {
      await ref
          .read(feedProvider.notifier)
          .publish(resultId: fitting.resultId, caption: caption);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('피드에 게시했어요! 투표 반응을 확인해보세요.')),
      );
      context.go('/feed');
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('게시 실패: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final product = fitting.product;
    final date =
        '${fitting.createdAt.year}.${fitting.createdAt.month.toString().padLeft(2, '0')}.${fitting.createdAt.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('피팅 결과'),
        actions: [
          IconButton(
            tooltip: '사진 저장',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _download(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: fitting.resultUrl.startsWith('assets/')
                        ? Image.asset(fitting.resultUrl, fit: BoxFit.cover)
                        : Image.network(
                            fitting.resultUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: AppColors.surfaceMuted,
                              child: Icon(Icons.broken_image_outlined, size: 48),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (fitting.styleLabel != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.lightPurple,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          fitting.styleLabel!,
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      date,
                      style: textTheme.labelMedium
                          ?.copyWith(color: AppColors.secondaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (product != null)
                  Material(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.divider),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push('/shop/product/${product.id}'),
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.brand,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: AppColors.primaryPurple,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    product.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  PriceText(price: product.price),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.disabled),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _publish(context, ref),
                        icon: const Icon(Icons.dynamic_feed_rounded),
                        label: const Text('피드에 게시'),
                      ),
                    ),
                    if (product != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              context.push('/shop/product/${product.id}'),
                          icon: const Icon(Icons.shopping_bag_outlined),
                          label: const Text('상품 보러가기'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
