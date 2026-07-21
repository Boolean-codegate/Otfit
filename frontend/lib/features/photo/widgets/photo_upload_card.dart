import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';

class PhotoUploadCard extends StatelessWidget {
  const PhotoUploadCard({
    super.key,
    required this.onPickGallery,
    required this.onTakePhoto,
    required this.cameraAvailable,
    this.isPicking = false,
  });

  final VoidCallback onPickGallery;
  final VoidCallback onTakePhoto;
  final bool cameraAvailable;
  final bool isPicking;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: 'AI 피팅 사진 업로드 영역',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primaryPurple.withValues(alpha: 0.28),
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: const BoxDecoration(
                gradient: AppColors.softGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                size: 36,
                color: AppColors.primaryPurple,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '피팅에 사용할 사진을 선택하세요',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.mainText,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'JPG, PNG 등 기기에서 지원하는 이미지를 사용할 수 있어요.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.secondaryText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  GradientPrimaryButton(
                    label: '갤러리에서 사진 선택',
                    icon: Icons.photo_library_outlined,
                    onPressed: onPickGallery,
                    isLoading: isPicking,
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: '카메라로 촬영',
                    icon: Icons.photo_camera_outlined,
                    onPressed: onTakePhoto,
                    isEnabled: cameraAvailable && !isPicking,
                  ),
                  if (!cameraAvailable) ...[
                    const SizedBox(height: 9),
                    Text(
                      '카메라 촬영은 모바일 앱에서 이용할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
