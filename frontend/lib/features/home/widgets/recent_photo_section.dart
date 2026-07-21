import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/widgets/widgets.dart';

class RecentPhotoSection extends StatelessWidget {
  const RecentPhotoSection({
    super.key,
    required this.photoBytes,
    required this.onRegister,
    required this.onChange,
    required this.onRemove,
  });

  final Uint8List? photoBytes;
  final VoidCallback onRegister;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '최근 등록한 사진'),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          child: photoBytes == null
              ? EmptyStateCard(
                  key: const ValueKey('empty-photo'),
                  icon: Icons.add_photo_alternate_outlined,
                  title: '아직 등록한 사진이 없어요.',
                  description: '정면에서 찍은 밝은 사진으로 AI 피팅을 시작해보세요.',
                  actionLabel: '내 사진 등록하기',
                  onAction: onRegister,
                )
              : UserPhotoCard(
                  key: const ValueKey('selected-photo'),
                  image: Semantics(
                    image: true,
                    label: '최근 등록한 사용자 피팅 사진',
                    child: Image.memory(
                      photoBytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                    ),
                  ),
                  title: 'AI 피팅에 사용할 내 사진',
                  subtitle: '사진은 언제든 변경할 수 있어요.',
                  onTap: onChange,
                  onChange: onChange,
                  onRemove: onRemove,
                  isSelected: true,
                ),
        ),
      ],
    );
  }
}
