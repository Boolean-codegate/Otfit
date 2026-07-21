import 'package:flutter/material.dart';

import 'selection_chip.dart';

class ShopBrandChip extends StatelessWidget {
  const ShopBrandChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.leading,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SelectablePill(
      label: label,
      selected: selected,
      onTap: onSelected == null ? null : () => onSelected!(!selected),
      leading: leading,
      semanticLabel: '$label 쇼핑몰',
    );
  }
}
