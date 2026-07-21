import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'brand_logo.dart';

class OTFITAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OTFITAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.showLogo = false,
    this.leading,
    this.actions,
    this.automaticallyImplyLeading = true,
    this.centerTitle = false,
    this.backgroundColor = AppColors.surface,
    this.bottom,
    this.height = 64,
  }) : assert(
         title == null || titleWidget == null,
         'Use either title or titleWidget, not both.',
       );

  final String? title;
  final Widget? titleWidget;
  final bool showLogo;
  final Widget? leading;
  final List<Widget>? actions;
  final bool automaticallyImplyLeading;
  final bool centerTitle;
  final Color backgroundColor;
  final PreferredSizeWidget? bottom;
  final double height;

  @override
  Size get preferredSize =>
      Size.fromHeight(height + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final resolvedTitle =
        titleWidget ??
        (showLogo
            ? const BrandLogo(height: 30, width: 94)
            : title == null
            ? null
            : Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.mainText,
                  fontWeight: FontWeight.w800,
                ),
              ));

    return AppBar(
      toolbarHeight: height,
      title: resolvedTitle,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      centerTitle: centerTitle,
      backgroundColor: backgroundColor,
      foregroundColor: AppColors.mainText,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: leading == null && !automaticallyImplyLeading ? 20 : null,
      bottom: bottom,
    );
  }
}
