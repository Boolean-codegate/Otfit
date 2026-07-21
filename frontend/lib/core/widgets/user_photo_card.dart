import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class UserPhotoCard extends StatefulWidget {
  const UserPhotoCard({
    super.key,
    this.image,
    this.imageProvider,
    this.title = '내 사진',
    this.subtitle,
    this.semanticLabel = '선택한 사용자 사진',
    this.isSelected = false,
    this.aspectRatio = 3 / 4,
    this.onTap,
    this.onChange,
    this.onRemove,
  }) : assert(
         image == null || imageProvider == null,
         'Use either image or imageProvider, not both.',
       );

  final Widget? image;
  final ImageProvider<Object>? imageProvider;
  final String title;
  final String? subtitle;
  final String semanticLabel;
  final bool isSelected;
  final double aspectRatio;
  final VoidCallback? onTap;
  final VoidCallback? onChange;
  final VoidCallback? onRemove;

  @override
  State<UserPhotoCard> createState() => _UserPhotoCardState();
}

class _UserPhotoCardState extends State<UserPhotoCard> {
  bool _pressed = false;

  bool get _hasImage => widget.image != null || widget.imageProvider != null;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed || widget.isSelected ? 0.98 : 1.0;
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Semantics(
        button: widget.onTap != null,
        selected: widget.isSelected,
        label: _hasImage ? widget.semanticLabel : '등록된 사용자 사진 없음',
        child: Material(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: widget.isSelected
                  ? AppColors.primaryPurple
                  : AppColors.divider,
              width: widget.isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (value) {
              if (mounted) setState(() => _pressed = value);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: widget.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: _hasImage
                            ? _buildImage()
                            : const _UserPhotoPlaceholder(),
                      ),
                      if (_hasImage && widget.isSelected)
                        const Positioned(
                          top: 12,
                          left: 12,
                          child: _SelectedBadge(),
                        ),
                      if (_hasImage && widget.onRemove != null)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton.filledTonal(
                            onPressed: widget.onRemove,
                            tooltip: '사진 삭제',
                            icon: const Icon(Icons.close_rounded, size: 20),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              backgroundColor: AppColors.surface.withValues(
                                alpha: 0.9,
                              ),
                              foregroundColor: AppColors.mainText,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 8, 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: AppColors.mainText,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            if (widget.subtitle != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                widget.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.secondaryText),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.onChange != null)
                        TextButton(
                          onPressed: widget.onChange,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryPurple,
                            minimumSize: const Size(48, 48),
                          ),
                          child: Text(_hasImage ? '변경' : '등록'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final image =
        widget.image ??
        Image(
          image: widget.imageProvider!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const _UserPhotoPlaceholder(),
        );
    return Semantics(
      key: const ValueKey('user-photo'),
      image: true,
      label: widget.semanticLabel,
      child: ExcludeSemantics(child: SizedBox.expand(child: image)),
    );
  }
}

class _UserPhotoPlaceholder extends StatelessWidget {
  const _UserPhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('photo-placeholder'),
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_outline_rounded,
              size: 46,
              color: AppColors.primaryPurple,
            ),
            const SizedBox(height: 10),
            Text(
              '사진을 등록해 주세요',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, size: 16, color: AppColors.surface),
            SizedBox(width: 3),
            Text(
              '선택됨',
              style: TextStyle(
                color: AppColors.surface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
