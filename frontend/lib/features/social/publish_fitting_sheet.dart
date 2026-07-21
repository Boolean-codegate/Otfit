import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/mypage.dart';
import '../../models/post.dart';
import '../../providers/app_providers.dart';

/// 변신 게시 시트 — 게시물은 '내 피팅 결과(내 사진)'만 올릴 수 있다.
/// 애프터 = AI 변신 결과, 비포 = 내 원본 사진(스위치로 선택 공개).
/// 내 피드·마이 탭 어디서든 재사용.
Future<void> showPublishFittingSheet(
  BuildContext context,
  WidgetRef ref, {
  String? feedUserId,
}) async {
  final fittings = await ref.read(myFittingsProvider.future);
  if (!context.mounted) return;
  if (fittings.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('게시할 변신 결과가 없어요. 먼저 입혀보기로 변신해 보세요!'),
        action: SnackBarAction(
          label: '입혀보기',
          onPressed: () => context.go('/try-on'),
        ),
      ),
    );
    return;
  }
  // 게시된 결과를 고르면 '새 게시'가 아니라 기존 게시물 '수정' — 캡션/비포 프리필용
  List<Post> myPosts = const <Post>[];
  try {
    myPosts = await ref.read(userPostsProvider('me').future);
  } on Object {
    // 프리필 실패는 치명적이지 않다 (수정 시 캡션만 비어 보임)
  }
  if (!context.mounted) return;
  Post? postFor(MyFitting fitting) {
    if (fitting.postId == null) return null;
    for (final post in myPosts) {
      if (post.id == fitting.postId) return post;
    }
    return null;
  }

  // 아직 게시하지 않은 결과를 우선 선택
  MyFitting selected = fittings.firstWhere(
    (fitting) => fitting.postId == null,
    orElse: () => fittings.first,
  );
  var includeBefore = true;
  final captionController = TextEditingController();
  void prefillFrom(MyFitting fitting) {
    final post = postFor(fitting);
    if (post != null) {
      captionController.text = post.caption;
      includeBefore = post.beforeUrl != null;
    }
  }

  prefillFrom(selected);
  final published = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final hasBefore = selected.sourcePhotoUrl != null &&
            selected.sourcePhotoUrl!.isNotEmpty;
        final isEditing = selected.postId != null;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isEditing ? '게시물 수정하기' : '변신 게시하기',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                isEditing
                    ? '이미 게시된 결과예요 — 캡션과 비포 공개를 수정해요'
                    : '내 피팅 결과만 게시할 수 있어요',
                style: Theme.of(sheetContext)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: fittings.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final fitting = fittings[index];
                    final isSelected = selected.resultId == fitting.resultId;
                    return GestureDetector(
                      onTap: () {
                        prefillFrom(fitting);
                        setSheetState(() => selected = fitting);
                      },
                      child: Container(
                        width: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryPurple
                                : AppColors.divider,
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            fitting.resultUrl.startsWith('assets/')
                                ? Image.asset(fitting.resultUrl,
                                    fit: BoxFit.cover)
                                : Image.network(
                                    fitting.resultUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                        Icons.auto_awesome_rounded),
                                  ),
                            if (fitting.postId != null)
                              Positioned(
                                top: 5,
                                left: 5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '게시됨',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: includeBefore &&
                    selected.sourcePhotoUrl != null &&
                    selected.sourcePhotoUrl!.isNotEmpty,
                onChanged: hasBefore
                    ? (value) => setSheetState(() => includeBefore = value)
                    : null,
                title: const Text('비포 사진 함께 공개'),
                subtitle: Text(
                  hasBefore ? '비포 → 애프터 변신을 보여줘요 ✨' : '이 결과에는 비포 사진이 없어요',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
              ),
              TextField(
                controller: captionController,
                maxLength: 300,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: '이 옷 어때요? 살까 말까 물어보세요 🙋',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: Text(isEditing ? '수정하기' : '게시하기'),
              ),
            ],
          ),
        );
      },
    ),
  );
  if (published != true || !context.mounted) return;
  final isEditing = selected.postId != null;
  final hasBefore =
      selected.sourcePhotoUrl != null && selected.sourcePhotoUrl!.isNotEmpty;
  try {
    if (isEditing) {
      // 게시된 결과는 중복 게시 대신 기존 게시물 수정
      await ref.read(postRepositoryProvider).updatePost(
            postId: selected.postId!,
            caption: captionController.text.trim(),
            includeBefore: includeBefore && hasBefore,
            removeBefore: !includeBefore && hasBefore,
          );
    } else {
      // URL을 보내지 않는다 — 서버가 result_id에서 애프터/비포 키를 직접 결정
      await ref.read(postRepositoryProvider).createPost(
            resultId: selected.resultId,
            productId: selected.product?.id,
            caption: captionController.text.trim(),
            includeBefore: includeBefore && hasBefore,
          );
    }
    ref.invalidate(feedProvider);
    ref.invalidate(myFittingsProvider);
    ref.invalidate(userPostsProvider('me'));
    ref.invalidate(userProfileProvider('me'));
    if (feedUserId != null) {
      ref.invalidate(userPostsProvider(feedUserId));
      ref.invalidate(userProfileProvider(feedUserId));
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? '게시물을 수정했어요!' : '게시했어요!')));
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? '수정 실패: $error' : '게시 실패: $error')));
    }
  }
}
