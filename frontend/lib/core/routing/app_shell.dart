import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: keyboardVisible
          ? null
          : SafeArea(
              top: false,
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 18,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            _ShellDestination(
                              label: '홈',
                              icon: Icons.home_outlined,
                              selectedIcon: Icons.home_rounded,
                              selected: navigationShell.currentIndex == 0,
                              onTap: () => _onDestinationSelected(0),
                            ),
                            _ShellDestination(
                              label: '피드',
                              icon: Icons.dynamic_feed_outlined,
                              selectedIcon: Icons.dynamic_feed_rounded,
                              selected: navigationShell.currentIndex == 1,
                              onTap: () => _onDestinationSelected(1),
                            ),
                            _ShellDestination(
                              label: '입혀보기',
                              icon: Icons.auto_awesome_outlined,
                              selectedIcon: Icons.auto_awesome_rounded,
                              selected: navigationShell.currentIndex == 2,
                              emphasized: true,
                              onTap: () => _onDestinationSelected(2),
                            ),
                            _ShellDestination(
                              label: '쇼핑',
                              icon: Icons.shopping_bag_outlined,
                              selectedIcon: Icons.shopping_bag_rounded,
                              selected: navigationShell.currentIndex == 3,
                              onTap: () => _onDestinationSelected(3),
                            ),
                            _ShellDestination(
                              label: '마이',
                              icon: Icons.person_outline_rounded,
                              selectedIcon: Icons.person_rounded,
                              selected: navigationShell.currentIndex == 4,
                              onTap: () => _onDestinationSelected(4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ShellDestination extends StatelessWidget {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        label: '$label 탭',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: selected ? AppColors.lightPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: emphasized && selected ? 34 : 30,
                    height: emphasized && selected ? 30 : 28,
                    decoration: selected
                        ? const BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                          )
                        : null,
                    child: Icon(
                      selected ? selectedIcon : icon,
                      size: 20,
                      color: selected ? Colors.white : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected
                          ? AppColors.primaryPurple
                          : AppColors.secondaryText,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
