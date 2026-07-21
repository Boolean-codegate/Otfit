import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

/// 데스크톱(웹)에서도 마우스 드래그/트랙패드로 가로 리스트를 스크롤할 수 있게 한다.
/// (Flutter 기본값은 터치만 드래그 허용 → PC에서 가로 캐러셀이 안 끌림)
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class OtfitApp extends StatelessWidget {
  const OtfitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OTFIT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const _AppScrollBehavior(),
      routerConfig: appRouter,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.35,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
