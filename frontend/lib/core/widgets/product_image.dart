import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.assetPath,
    required this.semanticLabel,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.placeholderLabel,
    this.icon = Icons.checkroom_rounded,
    this.fallback,
  });

  final String assetPath;
  final String semanticLabel;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final String? placeholderLabel;
  final IconData icon;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final fallbackWidget =
        fallback ?? _ProductImageFallback(icon: icon, label: placeholderLabel);

    final isNetworkImage =
        assetPath.startsWith('https://') || assetPath.startsWith('http://');

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: borderRadius,
          child: ColoredBox(
            color: AppColors.lightPurple,
            child: assetPath.trim().isEmpty
                ? fallbackWidget
                : isNetworkImage
                ? Image.network(
                    assetPath,
                    fit: fit,
                    width: double.infinity,
                    height: double.infinity,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) =>
                        fallbackWidget,
                  )
                : Image.asset(
                    assetPath,
                    fit: fit,
                    width: double.infinity,
                    height: double.infinity,
                    gaplessPlayback: true,
                    errorBuilder: (context, error, stackTrace) =>
                        fallbackWidget,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback({required this.icon, this.label});

  final IconData icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.lightPurple,
            AppColors.primaryBlue.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: AppColors.primaryPurple),
              if (label != null && label!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primaryNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
