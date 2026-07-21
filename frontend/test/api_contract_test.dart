import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/mock/mock_products.dart';
import 'package:frontend/models/fitting_result.dart';
import 'package:frontend/models/product.dart';
import 'package:frontend/providers/app_providers.dart';

void main() {
  test('Product uses the canonical API contract shape', () {
    final product = Product.fromJson(const <String, dynamic>{
      'id': 'prod_1',
      'title': '린넨 오버셔츠',
      'brand': 'ACME',
      'category': 'top',
      'price': 39000,
      'currency': 'KRW',
      'stock_status': 'in_stock',
      'product_url': 'https://shop.example/1',
      'image_url': 'https://images.example/prod_1.jpg',
      'attributes': <String, dynamic>{
        'color': 'ivory',
        'pattern': 'solid',
        'length': 'regular',
        'material': 'linen',
      },
    });

    expect(product.name, '린넨 오버셔츠');
    expect(product.categoryLabel, '상의');
    expect(product.toJson().keys, <String>[
      'id',
      'title',
      'brand',
      'category',
      'price',
      'currency',
      'stock_status',
      'product_url',
      'image_url',
      'attributes',
    ]);
  });

  test(
    'mock generation follows the API job flow and produces a result',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(selectedUserPhotoProvider.notifier)
          .setPhoto(
            SelectedUserPhoto(
              name: 'person.jpg',
              bytes: Uint8List.fromList(<int>[1, 2, 3]),
            ),
          );
      container
          .read(selectedProductProvider.notifier)
          .selectProduct(mockProducts.first);
      container.read(imageProcessingConsentProvider.notifier).grant();

      final result = await container
          .read(tryOnProgressProvider.notifier)
          .startTryOn(stageDuration: Duration.zero);

      expect(result, isNotNull);
      expect(result!.product.id, mockProducts.first.id);
      expect(result.disclaimer, contains('실제 핏/사이즈'));
      expect(
        container.read(tryOnProgressProvider).generationStatus,
        GenerationStatus.done,
      );
      expect(container.read(uploadedPhotoProvider)?.id, startsWith('p_mock_'));
      expect(container.read(currentFittingResultProvider)?.id, result.id);
      expect(result.generationResult?.isSelected, isTrue);
      expect(container.read(fittingResultsProvider).first.id, result.id);
    },
  );
}
