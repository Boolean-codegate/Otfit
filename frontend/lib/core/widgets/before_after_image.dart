import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// OTFIT 아이덴티티: 비포→애프터 변신을 전면에 내세우는 이미지 뷰어.
/// - before가 있으면: 탭/버튼으로 즉시 전환 + 상태 뱃지 + 전환 애니메이션
/// - before가 없으면: 일반 이미지
class BeforeAfterImage extends StatefulWidget {
  const BeforeAfterImage({
    super.key,
    required this.afterUrl,
    this.beforeUrl,
    this.aspectRatio = 3 / 4,
    this.borderRadius,
  });

  final String afterUrl;
  final String? beforeUrl;
  final double aspectRatio;
  final BorderRadius? borderRadius;

  @override
  State<BeforeAfterImage> createState() => _BeforeAfterImageState();
}

class _BeforeAfterImageState extends State<BeforeAfterImage> {
  bool _showAfter = true;

  Widget _image(String url) => url.startsWith('assets/')
      ? Image.asset(url, fit: BoxFit.cover)
      : Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: AppColors.surfaceMuted,
            child: Icon(Icons.broken_image_outlined, size: 40),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final hasBefore =
        widget.beforeUrl != null && widget.beforeUrl!.isNotEmpty;
    final content = AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: !hasBefore
          ? _image(widget.afterUrl)
          : GestureDetector(
              onTap: () => setState(() => _showAfter = !_showAfter),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOut,
                    child: KeyedSubtree(
                      key: ValueKey(_showAfter),
                      child:
                          _image(_showAfter ? widget.afterUrl : widget.beforeUrl!),
                    ),
                  ),
                  // 상태 뱃지 (좌상단)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient:
                            _showAfter ? AppColors.primaryGradient : null,
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
                  // 전환 버튼 (우하단) — 비포/애프터가 있음을 항상 노출
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () =>
                            setState(() => _showAfter = !_showAfter),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.compare_arrows_rounded,
                                  size: 15, color: AppColors.primaryPurple),
                              const SizedBox(width: 5),
                              Text(
                                _showAfter ? '비포 보기' : '애프터 보기',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryPurple,
                                ),
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
    );
    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }
    return content;
  }
}
