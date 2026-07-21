import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({super.key, required this.onSelectPhoto});

  final VoidCallback onSelectPhoto;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: 'AI 피팅 시작',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 620;
              final copy = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: AppColors.surface,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI VIRTUAL FITTING',
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.surface,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '내 사진으로\nAI 피팅 시작',
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppColors.surface,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '사진 한 장이면 충분해요.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.surface.withValues(alpha: 0.82),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: onSelectPhoto,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.primaryPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      icon: const Icon(Icons.add_photo_alternate_rounded),
                      label: const Text('사진 선택하기'),
                    ),
                  ),
                ],
              );

              return Stack(
                children: [
                  Positioned(
                    right: -56,
                    top: -62,
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.07),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 80,
                    bottom: -86,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(isWide ? 36 : 26),
                    child: isWide
                        ? Row(
                            children: [
                              Expanded(flex: 3, child: copy),
                              const SizedBox(width: 28),
                              const Expanded(flex: 2, child: _AiFashionOrb()),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              copy,
                              const SizedBox(height: 22),
                              const Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  width: 126,
                                  height: 86,
                                  child: _AiFashionOrb(),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AiFashionOrb extends StatelessWidget {
  const _AiFashionOrb();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'AI가 옷을 가상 피팅하는 일러스트',
      child: ExcludeSemantics(
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surface.withValues(alpha: 0.22),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.checkroom_rounded,
                    color: AppColors.surface.withValues(alpha: 0.96),
                    size: 70,
                  ),
                  const Positioned(
                    right: 20,
                    top: 22,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.surface,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
