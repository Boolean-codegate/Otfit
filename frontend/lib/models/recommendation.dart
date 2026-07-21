import 'package:flutter/foundation.dart';

import 'product.dart';

/// 계약 §4 POST /photos/{id}/recommendations 응답.
@immutable
class RecommendationGroup {
  const RecommendationGroup({
    required this.styleId,
    required this.label,
    required this.products,
  });

  final String styleId;
  final String label;
  final List<Product> products;

  factory RecommendationGroup.fromJson(Map<String, dynamic> json) =>
      RecommendationGroup(
        styleId: (json['style_id'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        products: _products(json['products']),
      );
}

@immutable
class RecommendationResponse {
  const RecommendationResponse({
    required this.photoId,
    required this.mode,
    this.groups = const <RecommendationGroup>[],
    this.products = const <Product>[],
  });

  final String photoId;
  final String mode;
  final List<RecommendationGroup> groups;

  /// MODE A 등 평면 리스트 응답 (계약 §4: "groups 없이 products 평면 리스트도 허용").
  final List<Product> products;

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) =>
      RecommendationResponse(
        photoId: (json['photo_id'] ?? '').toString(),
        mode: (json['mode'] ?? '').toString(),
        groups: json['groups'] is List
            ? (json['groups'] as List)
                  .whereType<Map>()
                  .map(
                    (item) => RecommendationGroup.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList(growable: false)
            : const <RecommendationGroup>[],
        products: _products(json['products']),
      );
}

List<Product> _products(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false)
    : const <Product>[];
