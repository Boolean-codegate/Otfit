import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/before_after_image.dart';
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
                        IconButton(
                          tooltip: '계정 검색',
                          icon: const Icon(Icons.search_rounded),
                          onPressed: () =>
                              context.push('/users/search-people'),
                        ),
                        const SizedBox(width: 4),
                        _SortChip(
                          label: '팔로우',
                          selected: sort == 'following',
                          onTap: () => ref
                              .read(feedSortProvider.notifier)
                              .setSort('following'),
                        ),
                        const SizedBox(width: 6),
                        _SortChip(
                          label: '인기',
                          selected: sort == 'hot',
                          onTap: () => ref
                              .read(feedSortProvider.notifier)
                              .setSort('hot'),
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
                      ? SliverFillRemaining(
                          child: Center(
                            child: Text(
                              sort == 'following'
                                  ? '아직 팔로우한 사람의 게시물이 없어요.\n계정을 검색해 팔로우해보세요!'
                                  : '아직 게시물이 없어요.\n피팅 결과를 처음으로 공유해보세요!',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                          // PC에선 카드 3~4열 그리드, 모바일은 1열 (카드 높이가
                          // 제각각이라 행 단위로 묶어 상단 정렬)
                          sliver: SliverLayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.crossAxisExtent;
                              final columns = width >= 1040
                                  ? 4
                                  : width >= 720
                                      ? 3
                                      : width >= 500
                                          ? 2
                                          : 1;
                              final rowCount =
                                  (posts.length + columns - 1) ~/ columns;
                              return SliverList.separated(
                                itemCount: rowCount,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, rowIndex) {
                                  final start = rowIndex * columns;
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (var i = 0; i < columns; i++) ...[
                                        if (i > 0)
                                          const SizedBox(width: 16),
                                        Expanded(
                                          child: start + i < posts.length
                                              ? _PostCard(
                                                  post: posts[start + i])
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              );
                            },
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
                InkWell(
                  onTap: () => context.push('/users/${post.author.id}'),
                  borderRadius: BorderRadius.circular(20),
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
                    ],
                  ),
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
          // 결과 이미지 — 비포→애프터 전환이 OTFIT의 핵심
          BeforeAfterImage(
            afterUrl: post.afterUrl,
            beforeUrl: post.beforeUrl,
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
          // 투표 + 댓글
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
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
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CommentsSheet(postId: post.id),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.mode_comment_outlined,
                            size: 16, color: AppColors.secondaryText),
                        const SizedBox(width: 6),
                        Text(
                          post.commentCount == 0
                              ? '첫 댓글을 남겨보세요'
                              : '댓글 ${post.commentCount}개 보기',
                          style: textTheme.labelMedium
                              ?.copyWith(color: AppColors.secondaryText),
                        ),
                      ],
                    ),
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

/// 댓글 시트 (계약 §10 GET/POST /posts/{id}/comments)
class CommentsSheet extends ConsumerStatefulWidget {
  const CommentsSheet({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<CommentsSheet> createState() => CommentsSheetState();
}

class CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _controller = TextEditingController();
  late Future<List<PostComment>> _future;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _future = ref.read(postRepositoryProvider).fetchComments(widget.postId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(feedProvider.notifier)
          .addComment(postId: widget.postId, content: content);
      _controller.clear();
      setState(() {
        _future =
            ref.read(postRepositoryProvider).fetchComments(widget.postId);
      });
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('댓글 작성 실패: $error')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().toUtc().difference(time);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('댓글', style: textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: FutureBuilder<List<PostComment>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('댓글을 불러오지 못했어요\n${snapshot.error}'));
                  }
                  final comments = snapshot.data ?? const <PostComment>[];
                  if (comments.isEmpty) {
                    return const Center(
                        child: Text('아직 댓글이 없어요.\n첫 댓글을 남겨보세요!'));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.lightPurple,
                              child: Text(
                                comment.author.nickname.characters.first,
                                style: const TextStyle(
                                  color: AppColors.primaryPurple,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment.author.nickname,
                                        style: textTheme.labelMedium?.copyWith(
                                            fontWeight: FontWeight.w800),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _timeAgo(comment.createdAt),
                                        style: textTheme.labelSmall?.copyWith(
                                            color: AppColors.disabled),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(comment.content,
                                      style: textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        hintText: '댓글을 입력하세요',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _submit,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
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
