import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'gradient_primary_button.dart';

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.add_photo_alternate_outlined,
    this.actionLabel,
    this.onAction,
    this.action,
    this.padding = const EdgeInsets.all(24),
  });

  final String title;
  final String? description;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final resolvedAction =
        action ??
        (actionLabel == null
            ? null
            : GradientPrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
                width: null,
                height: 50,
              ));

    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: AppColors.lightPurple,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 64,
                  child: Icon(icon, color: AppColors.primaryPurple, size: 30),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.mainText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (description != null && description!.trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryText,
                    height: 1.5,
                  ),
                ),
              ],
              if (resolvedAction != null) ...[
                const SizedBox(height: 20),
                resolvedAction,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
