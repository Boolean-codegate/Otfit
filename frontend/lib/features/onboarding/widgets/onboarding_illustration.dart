import 'package:flutter/material.dart';

class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({super.key, required this.pageIndex});

  final int pageIndex;

  IconData get _mainIcon => switch (pageIndex) {
    0 => Icons.add_photo_alternate_rounded,
    1 => Icons.checkroom_rounded,
    _ => Icons.shopping_bag_rounded,
  };

  IconData get _accentIcon => switch (pageIndex) {
    0 => Icons.auto_awesome_rounded,
    1 => Icons.compare_arrows_rounded,
    _ => Icons.done_all_rounded,
  };

  String get _semanticsLabel => switch (pageIndex) {
    0 => '사진으로 시작하는 AI 스타일링 일러스트',
    1 => '쇼핑 상품을 가상으로 입어보는 일러스트',
    _ => '피팅한 상품을 구매하는 일러스트',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      image: true,
      label: _semanticsLabel,
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1.24,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primaryContainer,
                    colors.secondaryContainer.withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final height = constraints.maxHeight;
                  final cardWidth = width * 0.48;
                  final cardHeight = height * 0.68;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -width * 0.07,
                        top: -width * 0.05,
                        child: _SoftCircle(
                          size: width * 0.34,
                          color: colors.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      Positioned(
                        right: -width * 0.03,
                        bottom: -width * 0.12,
                        child: _SoftCircle(
                          size: width * 0.46,
                          color: colors.secondary.withValues(alpha: 0.15),
                        ),
                      ),
                      Positioned(
                        left: width * 0.15,
                        top: height * 0.18,
                        child: Transform.rotate(
                          angle: -0.09,
                          child: _FashionCard(
                            width: cardWidth,
                            height: cardHeight,
                            icon: _mainIcon,
                            colors: colors,
                          ),
                        ),
                      ),
                      Positioned(
                        right: width * 0.12,
                        top: height * 0.26,
                        child: Transform.rotate(
                          angle: 0.08,
                          child: Container(
                            width: width * 0.28,
                            height: height * 0.45,
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: colors.outlineVariant.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.shadow.withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              _accentIcon,
                              color: colors.primary,
                              size: width * 0.11,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: width * 0.09,
                        top: height * 0.11,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: colors.primary,
                          size: width * 0.09,
                        ),
                      ),
                    ],
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

class _FashionCard extends StatelessWidget {
  const _FashionCard({
    required this.width,
    required this.height,
    required this.icon,
    required this.colors,
  });

  final double width;
  final double height;
  final IconData icon;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(width * 0.12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.1),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Icon(icon, color: colors.primary, size: width * 0.3),
              ),
            ),
          ),
          SizedBox(height: height * 0.08),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.78,
              child: Container(
                height: 7,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
          SizedBox(height: height * 0.045),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                height: 7,
                decoration: BoxDecoration(
                  color: colors.onSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
