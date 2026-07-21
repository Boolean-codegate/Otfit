import 'package:flutter/material.dart';

import 'selection_chip.dart';

class CategoryFilterChip extends StatelessWidget {
  const CategoryFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SelectablePill(
      label: label,
      selected: selected,
      onTap: onSelected == null ? null : () => onSelected!(!selected),
      leading: icon == null ? null : Icon(icon),
      semanticLabel: '$label 카테고리',
    );
  }
}
