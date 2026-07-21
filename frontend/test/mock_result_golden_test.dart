import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/result/result_screen.dart';

void main() {
  testWidgets('mock fitting result illustration stays stable', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const boundaryKey = ValueKey('mock-fitting-result');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox(
            width: 800,
            height: 1000,
            child: MockFittingIllustration(),
          ),
        ),
      ),
    );

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('../assets/images/mock/try_on_result_01.png'),
    );
  });
}
