import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/post.dart';
import '../../../providers/app_providers.dart';

/// 홈 히어로 — OTFIT 아이덴티티(비포 → 애프터 변신)를 첫 화면에서 바로 시연한다.
/// 오른쪽 쇼케이스는 피드에 실제 게시된 변신들이 자동으로 비포↔애프터 전환된다.
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
                    '비포에서,\n애프터로.',
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppColors.surface,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '사진 한 장이면 어떤 옷이든 입어볼 수 있어요.\n얼굴도 배경도 그대로, 옷만 바뀌어요.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.surface.withValues(alpha: 0.85),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: onSelectPhoto,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.surface,
                            foregroundColor: AppColors.primaryPurple,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          icon: const Icon(Icons.add_photo_alternate_rounded),
                          label: const Text('내 변신 시작하기'),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.go('/feed'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.surface,
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('변신 구경하기'),
                      ),
                    ],
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(flex: 3, child: copy),
                              const SizedBox(width: 28),
                              const Expanded(
                                flex: 2,
                                child: _BeforeAfterShowcase(height: 340),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              copy,
                              const SizedBox(height: 22),
                              const _BeforeAfterShowcase(height: 320),
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

/// 피드의 실제 비포/애프터 게시물을 자동 전환하며 보여주는 쇼케이스.
/// 게시물이 없으면 브랜드 심볼 카드로 대체.
class _BeforeAfterShowcase extends ConsumerStatefulWidget {
  const _BeforeAfterShowcase({required this.height});

  final double height;

  @override
  ConsumerState<_BeforeAfterShowcase> createState() =>
      _BeforeAfterShowcaseState();
}

class _BeforeAfterShowcaseState extends ConsumerState<_BeforeAfterShowcase> {
  Timer? _timer;
  int _postIndex = 0;
  bool _showAfter = false;

  @override
  void initState() {
    super.initState();
    // 비포(2.2초) → 애프터(2.2초) → 다음 변신
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() {
        if (_showAfter) {
          _postIndex += 1;
          _showAfter = false;
        } else {
          _showAfter = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _image(String url, Key key) => url.startsWith('assets/')
      ? Image.asset(url, key: key, fit: BoxFit.cover)
      : Image.network(
          url,
          key: key,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              const ColoredBox(color: AppColors.surfaceMuted),
        );

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(feedProvider).value ?? const <Post>[];
    final showcases = posts
        .where((post) => post.beforeUrl != null && post.beforeUrl!.isNotEmpty)
        .take(6)
        .toList(growable: false);

    Widget content;
    String? nickname;
    if (showcases.isEmpty) {
      content = _FallbackOrb(height: widget.height);
      return content;
    }

    final post = showcases[_postIndex % showcases.length];
    nickname = post.author.nickname;
    final url = _showAfter ? post.afterUrl : post.beforeUrl!;
    content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOut,
      child: _image(url, ValueKey('$_postIndex-$_showAfter')),
    );

    return Center(
      child: SizedBox(
        height: widget.height,
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.surface.withValues(alpha: 0.75),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                content,
                // 상태 뱃지
                Positioned(
                  top: 10,
                  left: 10,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: _showAfter ? AppColors.primaryGradient : null,
                      color: _showAfter ? null : Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _showAfter ? 'AFTER ✨' : 'BEFORE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                // 실제 유저 변신임을 알려주는 캡션
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 10),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Text(
                      '@$nickname 님의 실제 피팅',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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

/// 쇼케이스로 보여줄 게시물이 아직 없을 때의 브랜드 카드.
class _FallbackOrb extends StatelessWidget {
  const _FallbackOrb({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: height * 0.7,
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
    );
  }
}
