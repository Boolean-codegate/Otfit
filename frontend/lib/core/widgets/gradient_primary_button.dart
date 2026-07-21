import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GradientPrimaryButton extends StatelessWidget {
  const GradientPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.isLoading = false,
    this.isEnabled = true,
    this.width = double.infinity,
    this.height = 54,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? leading;
  final bool isLoading;
  final bool isEnabled;
  final double? width;
  final double height;
  final String? semanticLabel;

  bool get _canTap => isEnabled && !isLoading && onPressed != null;
  bool get _hasActiveStyle => isEnabled && onPressed != null;

  @override
  Widget build(BuildContext context) {
    final foreground = _hasActiveStyle
        ? AppColors.surface
        : AppColors.secondaryText;

    return Semantics(
      button: true,
      enabled: _canTap,
      label: semanticLabel ?? label,
      value: isLoading ? '처리 중' : null,
      child: SizedBox(
        width: width,
        height: height.clamp(48, double.infinity),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hasActiveStyle ? null : AppColors.disabled,
            gradient: _hasActiveStyle ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _hasActiveStyle
                ? [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: _canTap ? onPressed : null,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shadowColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              foregroundColor: foreground,
              disabledForegroundColor: foreground,
              minimumSize: Size(0, height.clamp(48, double.infinity)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: isLoading
                  ? const SizedBox.square(
                      key: ValueKey('loading'),
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.surface,
                      ),
                    )
                  : _ButtonContent(
                      key: const ValueKey('label'),
                      label: label,
                      icon: icon,
                      leading: leading,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    super.key,
    required this.label,
    this.icon,
    this.leading,
  });

  final String label;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final leadingWidget =
        leading ?? (icon == null ? null : Icon(icon, size: 20));
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingWidget != null) ...[leadingWidget, const SizedBox(width: 8)],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
