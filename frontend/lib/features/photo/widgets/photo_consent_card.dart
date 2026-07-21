import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class PhotoConsentCard extends StatelessWidget {
  const PhotoConsentCard({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: '필수 이미지 처리 동의',
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: enabled ? () => onChanged(!value) : null,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 18, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: value
                    ? AppColors.primaryPurple.withValues(alpha: 0.35)
                    : AppColors.divider,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: value,
                  onChanged: enabled
                      ? (nextValue) => onChanged(nextValue ?? false)
                      : null,
                  semanticLabel: 'AI 피팅 이미지 처리에 동의',
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'AI 피팅을 위한 이미지 처리 동의 '),
                              TextSpan(
                                text: '(필수)',
                                style: textTheme.labelLarge?.copyWith(
                                  color: AppColors.primaryPurple,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          style: textTheme.labelLarge?.copyWith(
                            color: AppColors.mainText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '선택한 사진을 등록하고 자세·조명 품질을 확인한 뒤 AI 피팅에 사용하는 데 동의합니다.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryText,
                            height: 1.45,
                          ),
                        ),
                      ],
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
