import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/mypage.dart';
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
  // 아직 게시하지 않은 결과를 우선 선택
  MyFitting selected = fittings.firstWhere(
    (fitting) => fitting.postId == null,
    orElse: () => fittings.first,
  );
  var includeBefore = true;
  final captionController = TextEditingController();
  final published = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final hasBefore = selected.sourcePhotoUrl != null &&
            selected.sourcePhotoUrl!.isNotEmpty;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('변신 게시하기',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '내 피팅 결과만 게시할 수 있어요',
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
                      onTap: () => setSheetState(() => selected = fitting),
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
                child: const Text('게시하기'),
              ),
            ],
          ),
        );
      },
    ),
  );
  if (published != true || !context.mounted) return;
  try {
    await ref.read(postRepositoryProvider).createPost(
          resultId: selected.resultId,
          productId: selected.product?.id,
          caption: captionController.text.trim(),
          afterUrl: selected.resultUrl,
          beforeUrl: includeBefore ? selected.sourcePhotoUrl : null,
        );
    ref.invalidate(feedProvider);
    ref.invalidate(myFittingsProvider);
    ref.invalidate(userPostsProvider('me'));
    ref.invalidate(userProfileProvider('me'));
    if (feedUserId != null) {
      ref.invalidate(userPostsProvider(feedUserId));
      ref.invalidate(userProfileProvider(feedUserId));
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('게시했어요!')));
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('게시 실패: $error')));
    }
  }
}
