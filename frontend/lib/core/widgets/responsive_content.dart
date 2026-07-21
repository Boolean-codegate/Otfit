import 'package:flutter/material.dart';

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1160,
    this.padding,
    this.useSafeArea = false,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final resolvedPadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: width >= 1200
              ? 40
              : width >= 600
              ? 28
              : 20,
        );
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: resolvedPadding, child: child),
      ),
    );
    return useSafeArea ? SafeArea(child: content) : content;
  }
}
