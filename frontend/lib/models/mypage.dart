import 'package:flutter/foundation.dart';

import 'product.dart';

/// 계약 §11 GET /me/fittings 항목.
@immutable
class MyFitting {
  const MyFitting({
    required this.resultId,
    required this.jobId,
    required this.resultUrl,
    this.styleLabel,
    this.product,
    required this.createdAt,
  });

  final String resultId;
  final String jobId;
  final String resultUrl;
  final String? styleLabel;
  final Product? product;
  final DateTime createdAt;

  factory MyFitting.fromJson(Map<String, dynamic> json) => MyFitting(
        resultId: (json['result_id'] ?? '').toString(),
        jobId: (json['job_id'] ?? '').toString(),
        resultUrl: (json['result_url'] ?? '').toString(),
        styleLabel: json['style_label']?.toString(),
        product: json['product'] is Map
            ? Product.fromJson(Map<String, dynamic>.from(json['product'] as Map))
            : null,
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '')?.toUtc() ??
                DateTime.now().toUtc(),
      );
}
