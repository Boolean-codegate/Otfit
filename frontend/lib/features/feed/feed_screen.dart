import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_content.dart';
import '../../models/post.dart';
import '../../providers/app_providers.dart';

/// SNS 피드 (계약 §10) — web-login-demo/home.html을 Flutter로 이식.
/// 플랫폼 스토리바 + 인기/최신 정렬 + 게시물 카드(살까/말까 투표, 상품 연결).
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final sort = ref.watch(feedSortProvider);
    final platforms = ref.watch(feedPlatformsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(feedProvider.notifier).refresh(),
          child: ResponsiveContent(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                    child: Row(
                      children: [
                        Text(
                          '피드',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        _SortChip(
                          label: '인기',
                          selected: sort == 'hot',
                          onTap: () => ref
                              .read(feedSortProvider.notifier)
                              .setSort('hot'),
                        ),
                        const SizedBox(width: 6),
                        _SortChip(
                          label: '최신',
                          selected: sort == 'new',
                          onTap: () => ref
                              .read(feedSortProvider.notifier)
                              .setSort('new'),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: platforms.maybeWhen(
                    data: (items) => items.isEmpty
                        ? const SizedBox.shrink()
                        : SizedBox(
                            height: 84,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              scrollDirection: Axis.horizontal,
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 14),
                              itemBuilder: (context, index) =>
                                  _PlatformStory(platform: items[index]),
                            ),
                          ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ),
                feed.when(
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 44),
                            const SizedBox(height: 10),
                            Text('피드를 불러오지 못했어요\n$error',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 14),
                            OutlinedButton(
                              onPressed: () =>
                                  ref.read(feedProvider.notifier).refresh(),
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  data: (posts) => posts.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text('아직 게시물이 없어요.\n피팅 결과를 처음으로 공유해보세요!'),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                          sliver: SliverList.separated(
                            itemCount: posts.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) =>
                                _PostCard(post: posts[index]),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryPurple : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppColors.primaryPurple : AppColors.divider,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlatformStory extends StatelessWidget {
  const _PlatformStory({required this.platform});

  final FeedPlatform platform;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
          ),
          alignment: Alignment.center,
          child: Text(
            platform.name.characters.first,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 64,
          child: Text(
            platform.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});

  final Post post;

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().toUtc().difference(time);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  Future<void> _vote(BuildContext context, WidgetRef ref, String choice) async {
    try {
      final reward = await ref
          .read(feedProvider.notifier)
          .vote(postId: post.id, choice: choice);
      if (reward > 0 && context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text('투표 완료! 크레딧 +$reward 적립 ✨')),
          );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('투표 실패: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final product = post.product;

    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 작성자
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.lightPurple,
                  child: Text(
                    post.author.nickname.characters.first,
                    style: const TextStyle(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  post.author.nickname,
                  style: textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  _timeAgo(post.createdAt),
                  style: textTheme.labelSmall
                      ?.copyWith(color: AppColors.disabled),
                ),
              ],
            ),
          ),
          // 결과 이미지
          AspectRatio(
            aspectRatio: 3 / 4,
            child: post.afterUrl.startsWith('assets/')
                ? Image.asset(post.afterUrl, fit: BoxFit.cover)
                : Image.network(
                    post.afterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: AppColors.surfaceMuted,
                      child: Icon(Icons.broken_image_outlined, size: 44),
                    ),
                  ),
          ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Text(post.caption, style: textTheme.bodyMedium),
            ),
          // 연결 상품
          if (product != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: InkWell(
                onTap: () => context.go('/shop/product/${product.id}'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: product.displayImage.startsWith('assets/')
                              ? Image.asset(
                                  product.displayImage,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  product.displayImage,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.checkroom_rounded,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelLarge,
                            ),
                            Text(
                              '${product.price}원',
                              style: textTheme.labelMedium?.copyWith(
                                color: AppColors.primaryPurple,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
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
          // 투표
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: _VoteButton(
                    label: '살래요 👍 ${post.buyVotes}',
                    selected: post.myVote == 'buy',
                    onTap: () => _vote(context, ref, 'buy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _VoteButton(
                    label: '글쎄요 🤔 ${post.skipVotes}',
                    selected: post.myVote == 'skip',
                    onTap: () => _vote(context, ref, 'skip'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.lightPurple : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primaryPurple : AppColors.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected
                  ? AppColors.primaryPurple
                  : AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}
