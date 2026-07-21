import 'package:flutter/foundation.dart';

/// Wire values defined by `api_contract.md` for `GET /products`.
abstract final class ProductCategories {
  static const String top = 'top';
  static const String outer = 'outer';
  static const String dress = 'dress';
  static const String bottom = 'bottom';

  static const List<String> values = <String>[top, outer, dress, bottom];

  static String labelFor(String category) {
    return switch (category) {
      top => '상의',
      outer => '아우터',
      dress => '원피스',
      bottom => '하의',
      _ => category,
    };
  }

  /// Converts either a Korean UI filter or an API wire value to the API value.
  static String? apiValueFor(String filter) {
    return switch (filter.trim().toLowerCase()) {
      '' || '전체' || 'all' => null,
      '상의' || top => top,
      '아우터' || outer => outer,
      '원피스' || dress => dress,
      '하의' || bottom => bottom,
      final value => value,
    };
  }
}

@immutable
class Product {
  const Product({
    required this.id,
    required this.title,
    required this.brand,
    required this.category,
    required this.price,
    this.currency = 'KRW',
    this.stockStatus = 'in_stock',
    this.productUrl = '',
    this.imageUrl = '',
    this.attributes = const <String, dynamic>{},
    this.mallName = 'OTFIT SELECT',
    this.originalPrice,
    this.discountPercent = 0,
    this.imageAsset = '',
    this.thumbnailAssets = const <String>[],
    this.availableColors = const <String>[],
    this.availableSizes = const <String>[],
    this.description = '',
    this.isFavorite = false,
  }) : assert(price >= 0),
       assert(originalPrice == null || originalPrice >= price),
       assert(discountPercent >= 0 && discountPercent <= 100),
       assert(
         category == ProductCategories.top ||
             category == ProductCategories.outer ||
             category == ProductCategories.dress ||
             category == ProductCategories.bottom,
       );

  /// Canonical API fields.
  final String id;
  final String title;
  final String brand;
  final String category;
  final int price;
  final String currency;
  final String stockStatus;
  final String productUrl;
  final String imageUrl;
  final Map<String, dynamic> attributes;

  /// Local presentation extensions. These are deliberately excluded from
  /// [toJson] so the backend contract stays stable.
  final String mallName;
  final int? originalPrice;
  final int discountPercent;
  final String imageAsset;
  final List<String> thumbnailAssets;
  final List<String> availableColors;
  final List<String> availableSizes;
  final String description;
  final bool isFavorite;

  /// Backwards-compatible UI alias for the API's `title` field.
  String get name => title;

  String get categoryLabel => ProductCategories.labelFor(category);

  bool get isInStock => stockStatus == 'in_stock';

  int get effectiveDiscountPercent {
    if (discountPercent > 0) return discountPercent;
    final original = originalPrice;
    if (original == null || original <= price || original == 0) return 0;
    return (((original - price) / original) * 100).round();
  }

  String get displayImage => imageAsset.isNotEmpty ? imageAsset : imageUrl;

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawAttributes = json['attributes'];
    final attributes = rawAttributes is Map
        ? Map<String, dynamic>.from(rawAttributes)
        : const <String, dynamic>{};
    final localColors = _stringList(json['available_colors']);
    final attributeColor = attributes['color']?.toString();

    return Product(
      id: _requiredString(json, 'id'),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      brand: _requiredString(json, 'brand'),
      category: _requiredString(json, 'category'),
      price: _intValue(json['price']),
      currency: (json['currency'] ?? 'KRW').toString(),
      stockStatus: (json['stock_status'] ?? 'in_stock').toString(),
      productUrl: (json['product_url'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      attributes: attributes,
      mallName: (json['mall_name'] ?? 'OTFIT SELECT').toString(),
      originalPrice: json['original_price'] == null
          ? null
          : _intValue(json['original_price']),
      discountPercent: _intValue(json['discount_percent']),
      imageAsset: (json['image_asset'] ?? '').toString(),
      thumbnailAssets: _stringList(json['thumbnail_assets']),
      availableColors: localColors.isNotEmpty
          ? localColors
          : attributeColor == null
          ? const <String>[]
          : <String>[attributeColor],
      availableSizes: _stringList(json['available_sizes']),
      description: (json['description'] ?? '').toString(),
      isFavorite: json['is_favorite'] == true,
    );
  }

  /// Serializes the exact Product shape from `api_contract.md`.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'brand': brand,
      'category': category,
      'price': price,
      'currency': currency,
      'stock_status': stockStatus,
      'product_url': productUrl,
      'image_url': imageUrl,
      'attributes': attributes,
    };
  }

  /// Useful for local persistence or fixtures; not an API request body.
  Map<String, dynamic> toLocalJson() {
    return <String, dynamic>{
      ...toJson(),
      'mall_name': mallName,
      'original_price': originalPrice,
      'discount_percent': discountPercent,
      'image_asset': imageAsset,
      'thumbnail_assets': thumbnailAssets,
      'available_colors': availableColors,
      'available_sizes': availableSizes,
      'description': description,
      'is_favorite': isFavorite,
    };
  }

  Product copyWith({
    String? id,
    String? title,
    String? name,
    String? brand,
    String? category,
    int? price,
    String? currency,
    String? stockStatus,
    String? productUrl,
    String? imageUrl,
    Map<String, dynamic>? attributes,
    String? mallName,
    Object? originalPrice = _unset,
    int? discountPercent,
    String? imageAsset,
    List<String>? thumbnailAssets,
    List<String>? availableColors,
    List<String>? availableSizes,
    String? description,
    bool? isFavorite,
  }) {
    return Product(
      id: id ?? this.id,
      title: title ?? name ?? this.title,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      stockStatus: stockStatus ?? this.stockStatus,
      productUrl: productUrl ?? this.productUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      attributes: attributes ?? this.attributes,
      mallName: mallName ?? this.mallName,
      originalPrice: identical(originalPrice, _unset)
          ? this.originalPrice
          : originalPrice as int?,
      discountPercent: discountPercent ?? this.discountPercent,
      imageAsset: imageAsset ?? this.imageAsset,
      thumbnailAssets: thumbnailAssets ?? this.thumbnailAssets,
      availableColors: availableColors ?? this.availableColors,
      availableSizes: availableSizes ?? this.availableSizes,
      description: description ?? this.description,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  @override
  bool operator ==(Object other) => other is Product && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Product(id: $id, title: $title, brand: $brand)';

  static const Object _unset = Object();
}

@immutable
class ProductPage {
  const ProductPage({required this.items, this.nextCursor});

  final List<Product> items;
  final String? nextCursor;

  factory ProductPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ProductPage(
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => Product.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const <Product>[],
      nextCursor: json['next_cursor']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'items': items.map((product) => product.toJson()).toList(growable: false),
    'next_cursor': nextCursor,
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString() ?? '';
  if (value.isEmpty) {
    throw FormatException('Missing required Product field: $key');
  }
  return value;
}

int _intValue(Object? value) {
  return switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
}

List<String> _stringList(Object? value) {
  return value is List
      ? value.map((item) => item.toString()).toList(growable: false)
      : const <String>[];
}
