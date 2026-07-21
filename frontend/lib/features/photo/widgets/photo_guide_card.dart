import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class PhotoGuideCard extends StatelessWidget {
  const PhotoGuideCard({super.key});

  static const _goodExamples = <String>[
    '정면을 바라보는 자세',
    '얼굴과 옷이 잘 보이는 밝은 조명',
    '팔과 몸을 가리지 않은 사진',
  ];

  static const _badExamples = <String>[
    '여러 사람이 함께 나온 사진',
    '지나치게 어두운 사진',
    '팔이나 몸이 심하게 가려진 사진',
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tips_and_updates_outlined,
                color: AppColors.primaryPurple,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '더 자연스러운 결과를 위한 촬영 가이드',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.mainText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 660;
              const good = _GuideGroup(
                title: '좋은 예',
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                items: _goodExamples,
              );
              const bad = _GuideGroup(
                title: '피해야 할 예',
                icon: Icons.cancel_rounded,
                color: AppColors.error,
                items: _badExamples,
              );

              if (isWide) {
                return const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: good),
                    SizedBox(width: 28),
                    Expanded(child: bad),
                  ],
                );
              }

              return const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [good, SizedBox(height: 22), bad],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GuideGroup extends StatelessWidget {
  const _GuideGroup({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.secondaryText,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
