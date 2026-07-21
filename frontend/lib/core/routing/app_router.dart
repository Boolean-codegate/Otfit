import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/photo/photo_selection_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/result/result_screen.dart';
import '../../features/shop/product_detail_screen.dart';
import '../../features/shop/shop_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/try_on/fitting_loading_screen.dart';
import '../../features/try_on/try_on_screen.dart';
import 'app_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          _fadePage(state: state, child: const SplashScreen()),
    ),
    GoRoute(
      path: '/onboarding',
      pageBuilder: (context, state) =>
          _fadePage(state: state, child: const OnboardingScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) =>
          _fadePage(state: state, child: const LoginScreen()),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (context, state) =>
                  _fadePage(state: state, child: const HomeScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/try-on',
              pageBuilder: (context, state) =>
                  _fadePage(state: state, child: const TryOnScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/shop',
              pageBuilder: (context, state) =>
                  _fadePage(state: state, child: const ShopScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              pageBuilder: (context, state) =>
                  _fadePage(state: state, child: const ProfileScreen()),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/photo',
      pageBuilder: (context, state) =>
          _slidePage(state: state, child: const PhotoSelectionScreen()),
    ),
    GoRoute(
      path: '/shop/product/:productId',
      pageBuilder: (context, state) => _slidePage(
        state: state,
        child: ProductDetailScreen(
          productId: state.pathParameters['productId'] ?? '',
        ),
      ),
    ),
    GoRoute(
      path: '/try-on/process',
      pageBuilder: (context, state) =>
          _fadePage(state: state, child: const FittingLoadingScreen()),
    ),
    GoRoute(
      path: '/result',
      pageBuilder: (context, state) =>
          _fadePage(state: state, child: const ResultScreen()),
    ),
  ],
  errorPageBuilder: (context, state) => MaterialPage<void>(
    key: state.pageKey,
    child: _RouteErrorScreen(message: state.error?.toString()),
  ),
);

CustomTransitionPage<void> _fadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
  );
}

CustomTransitionPage<void> _slidePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        SlideTransition(
          position:
              Tween<Offset>(
                begin: const Offset(0.035, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: FadeTransition(opacity: animation, child: child),
        ),
  );
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.explore_off_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  '페이지를 찾을 수 없어요',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('홈으로 이동'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
