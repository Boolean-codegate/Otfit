import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/home/home_screen.dart';
import 'package:frontend/features/profile/profile_screen.dart';
import 'package:frontend/features/shop/shop_screen.dart';

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    required Size size,
    required Widget screen,
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Home remains overflow-free at 360px', (tester) async {
    await pumpScreen(
      tester,
      size: const Size(360, 800),
      screen: const HomeScreen(),
    );

    expect(find.textContaining('오늘은 어떤 스타일을'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shop grows its grid on a 1200px web viewport', (tester) async {
    await pumpScreen(
      tester,
      size: const Size(1280, 900),
      screen: const ShopScreen(),
    );

    expect(find.text('쇼핑'), findsOneWidget);
    expect(find.textContaining('에센셜 코튼'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Shop remains overflow-free at 360px and 1.35 text scale', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      size: const Size(360, 800),
      textScale: 1.35,
      screen: const ShopScreen(),
    );

    expect(find.textContaining('12개의 스타일'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile history supports 1.35 text scale', (tester) async {
    await pumpScreen(
      tester,
      size: const Size(360, 800),
      textScale: 1.35,
      screen: const ProfileScreen(),
    );

    // 프로필 카드는 세션 유저 닉네임을 표시 (mock 세션 = '오핏')
    expect(find.text('오핏'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
