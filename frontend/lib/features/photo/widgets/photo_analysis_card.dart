import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class PhotoAnalysisCard extends StatelessWidget {
  const PhotoAnalysisCard({
    super.key,
    required this.hasConsent,
    required this.isAnalyzing,
    required this.isValid,
    this.rejectReason,
    this.personCount = 1,
    this.pose = 'front',
    this.brightness = 0.72,
  });

  final bool hasConsent;
  final bool isAnalyzing;
  final bool? isValid;
  final String? rejectReason;
  final int personCount;
  final String pose;
  final double brightness;

  @override
  Widget build(BuildContext context) {
    final stateKey = !hasConsent
        ? 'consent'
        : isAnalyzing
        ? 'analyzing'
        : isValid == true
        ? 'valid'
        : isValid == false
        ? 'invalid'
        : 'ready';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: Container(
        key: ValueKey(stateKey),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: _buildContent(context),
      ),
    );
  }

  Color get _backgroundColor {
    if (isValid == false) return AppColors.error.withValues(alpha: 0.06);
    if (isValid == true) return AppColors.success.withValues(alpha: 0.07);
    return AppColors.lightPurple.withValues(alpha: 0.62);
  }

  Color get _borderColor {
    if (isValid == false) return AppColors.error.withValues(alpha: 0.25);
    if (isValid == true) return AppColors.success.withValues(alpha: 0.22);
    return AppColors.primaryPurple.withValues(alpha: 0.16);
  }

  Widget _buildContent(BuildContext context) {
    if (!hasConsent) {
      return const _StatusMessage(
        icon: Icons.lock_outline_rounded,
        iconColor: AppColors.primaryPurple,
        title: '이미지 처리 동의 후 품질을 확인해요',
        description: '동의하면 사진 등록 후 자세와 조명 상태를 순서대로 확인합니다.',
      );
    }

    if (isAnalyzing) {
      return _AnalyzingMessage();
    }

    if (isValid == false) {
      return _StatusMessage(
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.error,
        title: '다른 사진을 선택해주세요',
        description: _rejectDescription(rejectReason),
      );
    }

    if (isValid == true) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StatusMessage(
            icon: Icons.verified_rounded,
            iconColor: AppColors.success,
            title: '피팅에 적합한 사진이에요',
            description: '사진 품질 확인이 완료되었습니다.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AnalysisPill(
                icon: Icons.person_outline_rounded,
                label: '$personCount명 감지',
              ),
              _AnalysisPill(
                icon: Icons.accessibility_new_rounded,
                label: pose == 'front' ? '정면 자세' : '자세 확인 필요',
              ),
              _AnalysisPill(
                icon: Icons.light_mode_outlined,
                label: brightness >= 0.55 ? '밝은 조명' : '조명 확인 필요',
              ),
            ],
          ),
        ],
      );
    }

    return const _StatusMessage(
      icon: Icons.auto_awesome_outlined,
      iconColor: AppColors.primaryPurple,
      title: '사진 품질 확인 준비가 되었어요',
      description: '잠시 후 자세와 조명 상태를 확인합니다.',
    );
  }

  String _rejectDescription(String? reason) {
    return switch (reason) {
      'MULTIPLE_PERSONS' => '한 사람만 나온 사진을 선택해주세요.',
      'HEAVY_OCCLUSION' => '팔이나 몸을 가리지 않은 사진을 선택해주세요.',
      'UNSUPPORTED_POSE' => '정면을 바라보는 자세의 사진을 선택해주세요.',
      'LOW_RESOLUTION' => '더 선명하고 큰 사진을 선택해주세요.',
      _ => '정면에서 밝게 촬영한 사진으로 다시 시도해주세요.',
    };
  }
}

class _AnalyzingMessage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            color: AppColors.primaryPurple,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '사진을 등록하고 품질을 확인하고 있어요',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.mainText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '자세와 조명 상태를 차례로 살펴보는 중입니다.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 25),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  color: AppColors.mainText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryText,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalysisPill extends StatelessWidget {
  const _AnalysisPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.success),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.mainText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
