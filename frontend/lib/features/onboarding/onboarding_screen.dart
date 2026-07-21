import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/app_providers.dart';
import '../../core/widgets/widgets.dart';
import 'widgets/onboarding_illustration.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      title: '사진 한 장으로 시작하는\n새로운 스타일',
      description: '마음에 드는 옷을 내 사진에 바로 입혀보세요.',
    ),
    _OnboardingPageData(
      title: '쇼핑몰의 옷을\n바로 피팅',
      description: '제휴 쇼핑몰 상품을 고르고 실제 내 모습에 적용해보세요.',
    ),
    _OnboardingPageData(
      title: '마음에 들면\n바로 구매',
      description: '가상 피팅부터 상품 구매까지 한 번에 연결됩니다.',
    ),
  ];

  late final PageController _pageController;
  int _currentPage = 0;

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    if (_isLastPage) {
      ref.read(onboardingCompletedProvider.notifier).complete();
      final user = await ref.read(authSessionProvider.future);
      if (mounted) context.go(user == null ? '/login' : '/home');
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) =>
                    _OnboardingPage(data: _pages[index], pageIndex: index),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 720;
                      final indicators = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            width: index == _currentPage ? 28 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: index == _currentPage
                                  ? colors.primary
                                  : colors.outlineVariant,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      );
                      final button = GradientPrimaryButton(
                        label: _isLastPage ? 'OTFIT 시작하기' : '다음',
                        onPressed: _handleNext,
                        width: isWide ? 240 : double.infinity,
                      );

                      if (isWide) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [indicators, button],
                        );
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          indicators,
                          const SizedBox(height: 22),
                          button,
                        ],
                      );
                    },
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

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.pageIndex});

  final _OnboardingPageData data;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSideBySide = constraints.maxWidth >= 760;
        final horizontalPadding = constraints.maxWidth >= 1200 ? 44.0 : 24.0;

        final illustration = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: OnboardingIllustration(pageIndex: pageIndex),
        );
        final copy = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: useSideBySide
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Text(
                data.title,
                textAlign: useSideBySide ? TextAlign.left : TextAlign.center,
                style: textTheme.headlineMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                data.description,
                textAlign: useSideBySide ? TextAlign.left : TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
            ],
          ),
        );

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            22,
            horizontalPadding,
            8,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 30).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: useSideBySide
                    ? Row(
                        children: [
                          Expanded(child: illustration),
                          const SizedBox(width: 64),
                          Expanded(child: copy),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          illustration,
                          const SizedBox(height: 32),
                          copy,
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({required this.title, required this.description});

  final String title;
  final String description;
}
