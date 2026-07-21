import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message = '잠시만 기다려 주세요',
    this.progress,
    this.step,
    this.totalSteps,
  });

  final Widget child;
  final bool isLoading;
  final String message;
  final double? progress;
  final int? step;
  final int? totalSteps;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading) ...[
          Positioned.fill(
            child: ModalBarrier(dismissible: false, color: AppColors.overlay),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: message,
                  value: progress == null
                      ? null
                      : '${(progress!.clamp(0, 1) * 100).round()}퍼센트',
                  child: ExcludeSemantics(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _AnimatedAiMark(),
                            const SizedBox(height: 20),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              child: Text(
                                message,
                                key: ValueKey(message),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppColors.mainText,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                            if (step != null && totalSteps != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '$step / $totalSteps 단계',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.secondaryText),
                              ),
                            ],
                            const SizedBox(height: 20),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress?.clamp(0, 1),
                                minHeight: 7,
                                backgroundColor: AppColors.lightPurple,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnimatedAiMark extends StatefulWidget {
  const _AnimatedAiMark();

  @override
  State<_AnimatedAiMark> createState() => _AnimatedAiMarkState();
}

class _AnimatedAiMarkState extends State<_AnimatedAiMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 74,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.rotate(
          angle: _controller.value * math.pi * 2,
          child: child,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                AppColors.gradientStart,
                AppColors.gradientEnd,
                AppColors.lightPurple,
                AppColors.gradientStart,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withValues(alpha: 0.24),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 56,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryPurple,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
