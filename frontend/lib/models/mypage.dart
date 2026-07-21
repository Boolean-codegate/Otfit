import 'package:flutter/foundation.dart';

import 'product.dart';

/// 계약 §11 GET /me/fittings 항목.
@immutable
class MyFitting {
  const MyFitting({
    required this.resultId,
    required this.jobId,
    required this.resultUrl,
    this.sourcePhotoUrl,
    this.styleLabel,
    this.product,
    required this.createdAt,
  });

  final String resultId;
  final String jobId;
  final String resultUrl;

  /// 비포(내 원본 사진) — 게시 시 '비포 함께 공개' 옵션에 사용.
  final String? sourcePhotoUrl;
  final String? styleLabel;
  final Product? product;
  final DateTime createdAt;

  factory MyFitting.fromJson(Map<String, dynamic> json) => MyFitting(
        resultId: (json['result_id'] ?? '').toString(),
        jobId: (json['job_id'] ?? '').toString(),
        resultUrl: (json['result_url'] ?? '').toString(),
        sourcePhotoUrl: json['source_photo_url']?.toString(),
        styleLabel: json['style_label']?.toString(),
        product: json['product'] is Map
            ? Product.fromJson(Map<String, dynamic>.from(json['product'] as Map))
            : null,
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '')?.toUtc() ??
                DateTime.now().toUtc(),
      );
}
