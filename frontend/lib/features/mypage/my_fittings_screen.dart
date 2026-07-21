import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_content.dart';
import '../../models/mypage.dart';
import '../../providers/app_providers.dart';

/// 내 피팅 기록 (계약 §11 GET /me/fittings) — 서버 저장분이라 새로고침해도 유지.
class MyFittingsScreen extends ConsumerWidget {
  const MyFittingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fittings = ref.watch(myFittingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('내 피팅 기록')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(myFittingsProvider.future),
          child: ResponsiveContent(
            child: fittings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorRetry(
                message: '$error',
                onRetry: () => ref.invalidate(myFittingsProvider),
              ),
              data: (items) => items.isEmpty
                  ? _EmptyState(
                      icon: Icons.auto_awesome_motion_outlined,
                      message: '아직 피팅 기록이 없어요.\n첫 AI 피팅을 시작해보세요!',
                      actionLabel: '입혀보러 가기',
                      onAction: () => context.go('/try-on'),
                    )
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) =>
                          _FittingTile(fitting: items[index]),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FittingTile extends StatelessWidget {
  const _FittingTile({required this.fitting});

  final MyFitting fitting;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final product = fitting.product;
    final date =
        '${fitting.createdAt.year}.${fitting.createdAt.month.toString().padLeft(2, '0')}.${fitting.createdAt.day.toString().padLeft(2, '0')}';

    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: () => context.push('/profile/fittings/detail', extra: fitting),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.network(
                fitting.resultUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.surfaceMuted,
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product?.title ?? '피팅 결과',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    product == null ? date : '${product.price}원 · $date',
                    style: textTheme.labelSmall
                        ?.copyWith(color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 52, color: AppColors.disabled),
        const SizedBox(height: 14),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        Center(
          child: FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ),
      ],
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.disabled),
        const SizedBox(height: 12),
        Text('불러오지 못했어요\n$message', textAlign: TextAlign.center),
        const SizedBox(height: 14),
        Center(
          child: OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ),
      ],
    );
  }
}
