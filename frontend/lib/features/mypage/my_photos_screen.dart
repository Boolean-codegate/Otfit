import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive_content.dart';
import '../../models/fitting_result.dart' show Photo;
import '../../providers/app_providers.dart';

/// 저장한 사진 (계약 §11 GET /me/photos) — 보기/삭제.
class MyPhotosScreen extends ConsumerWidget {
  const MyPhotosScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, Photo photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('사진 삭제'),
        content: const Text('이 사진을 즉시 삭제할까요?\n(서버에서도 바로 삭제됩니다)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(tryOnRepositoryProvider).deletePhoto(photo.id);
      ref.invalidate(myPhotosProvider);
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('삭제 실패: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(myPhotosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('저장한 사진')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(myPhotosProvider.future),
          child: ResponsiveContent(
            child: photos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('불러오지 못했어요\n$error')),
              data: (items) => items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        const Icon(Icons.photo_outlined,
                            size: 52, color: AppColors.disabled),
                        const SizedBox(height: 14),
                        const Text('업로드한 사진이 없어요.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 18),
                        Center(
                          child: FilledButton(
                            onPressed: () => context.push('/photo'),
                            child: const Text('사진 올리러 가기'),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final photo = items[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                photo.storageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: AppColors.surfaceMuted,
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Material(
                                  color: Colors.black45,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    tooltip: '삭제',
                                    iconSize: 18,
                                    color: Colors.white,
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () =>
                                        _delete(context, ref, photo),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
