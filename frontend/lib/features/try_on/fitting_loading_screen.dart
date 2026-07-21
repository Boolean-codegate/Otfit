import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/fitting_result.dart';
import '../../providers/app_providers.dart';

class FittingLoadingScreen extends ConsumerStatefulWidget {
  const FittingLoadingScreen({super.key});

  @override
  ConsumerState<FittingLoadingScreen> createState() =>
      _FittingLoadingScreenState();
}

class _FittingLoadingScreenState extends ConsumerState<FittingLoadingScreen> {
  bool _started = false;

  /// 기다리는 동안 순환 노출되는 안내 — 소요 시간(2~5분)을 반복해서 알려준다.
  static const _hints = [
    '⏳ 생성에는 보통 2~5분 정도 걸려요',
    '✨ 얼굴·체형·배경은 그대로, 옷만 자연스럽게 바뀌어요',
    '☕ 잠깐 스트레칭하고 오셔도 좋아요 — 2~5분이면 완성!',
    '📂 완성된 결과는 마이 → 내 피팅 기록에 저장돼요',
    '💜 완성되면 피드에 비포 → 애프터로 자랑해보세요',
  ];
  int _hintIndex = 0;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    _hintTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() => _hintIndex = (_hintIndex + 1) % _hints.length);
      }
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_started || !mounted) return;
    _started = true;
    final result = await ref.read(tryOnProgressProvider.notifier).startTryOn();
    if (!mounted) return;
    if (result != null) {
      context.go('/result');
      return;
    }
    final message = ref.read(tryOnProgressProvider).message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.isEmpty ? '피팅을 완료하지 못했어요.' : message)),
    );
    context.go('/try-on');
  }

  Future<void> _requestExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.hourglass_top_rounded),
        title: const Text('피팅을 중단할까요?'),
        content: const Text('진행 중인 작업을 중단하면 현재 결과는 저장되지 않아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('계속 기다리기'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('중단하기'),
          ),
        ],
      ),
    );
    if (shouldExit != true || !mounted) return;
    ref.read(tryOnProgressProvider.notifier).cancel();
    context.go('/try-on');
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(tryOnProgressProvider);
    final step = progress.step;
    final currentStep = step == null ? 0 : TryOnStep.values.indexOf(step) + 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              const Positioned.fill(child: _AnimatedBackground()),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.surface.withValues(alpha: 0.65),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 30,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _ScanningMark(),
                          const SizedBox(height: 26),
                          Text(
                            'AI 피팅을 만들고 있어요',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 260),
                            child: Text(
                              progress.message.isEmpty
                                  ? 'AI 피팅을 준비하고 있어요'
                                  : progress.message,
                              key: ValueKey(progress.message),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: AppColors.secondaryText,
                                    height: 1.5,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress.progress == 0
                                  ? null
                                  : progress.progress,
                              minHeight: 8,
                              backgroundColor: AppColors.lightPurple,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primaryPurple,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              3,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 9,
                                height: 9,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: index < currentStep
                                      ? AppColors.primaryPurple
                                      : AppColors.divider,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          // 순환 안내 문구 (2~5분 소요 안내 포함)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.lightPurple,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 350),
                              child: Text(
                                _hints[_hintIndex],
                                key: ValueKey(_hintIndex),
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.primaryPurple,
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _requestExit,
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('피팅 중단'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedBackground extends StatefulWidget {
  const _AnimatedBackground();

  @override
  State<_AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<_AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1 + _controller.value * 0.5, -1),
            end: Alignment(1, 1 - _controller.value * 0.5),
            colors: const [
              AppColors.lightPurple,
              AppColors.background,
              AppColors.surface,
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanningMark extends StatefulWidget {
  const _ScanningMark();

  @override
  State<_ScanningMark> createState() => _ScanningMarkState();
}

class _ScanningMarkState extends State<_ScanningMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
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
      dimension: 112,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: _controller.value * math.pi * 2,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      AppColors.gradientStart,
                      AppColors.gradientEnd,
                      AppColors.lightPurple,
                      AppColors.gradientStart,
                    ],
                  ),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/otfit_symbol.png',
                  width: 54,
                  height: 54,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.auto_awesome_rounded,
                    size: 42,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
