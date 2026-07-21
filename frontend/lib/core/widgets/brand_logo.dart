import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Displays the supplied OTFIT logo asset and falls back to a text wordmark.
///
/// The fallback is intentionally simple so a missing development asset never
/// prevents the app from rendering.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.height = 34,
    this.width,
    this.semanticLabel = 'OTFIT 로고',
  });

  static const assetPath = 'assets/images/otfit_logo.png';

  final double height;
  final double? width;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        semanticLabel: semanticLabel,
        errorBuilder: (context, error, stackTrace) =>
            _WordmarkFallback(semanticLabel: semanticLabel),
      ),
    );
  }
}

class _WordmarkFallback extends StatelessWidget {
  const _WordmarkFallback({required this.semanticLabel});

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: FittedBox(
          alignment: Alignment.centerLeft,
          fit: BoxFit.scaleDown,
          child: Text(
            'OTFIT',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primaryNavy,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}
