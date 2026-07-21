import 'package:flutter/foundation.dart';

/// 계약 §2 Consent 객체: { id, type, granted, granted_at }
abstract final class ConsentTypes {
  static const String imageProcessing = 'image_processing';
  static const String marketing = 'marketing';
  static const String reuse = 'reuse';
}

@immutable
class Consent {
  const Consent({
    required this.id,
    required this.type,
    required this.granted,
    this.grantedAt,
  });

  final String id;
  final String type;
  final bool granted;
  final DateTime? grantedAt;

  factory Consent.fromJson(Map<String, dynamic> json) => Consent(
    id: (json['id'] ?? '').toString(),
    type: (json['type'] ?? '').toString(),
    granted: json['granted'] == true,
    grantedAt: json['granted_at'] == null
        ? null
        : DateTime.tryParse(json['granted_at'].toString())?.toUtc(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'type': type,
    'granted': granted,
    'granted_at': grantedAt?.toIso8601String(),
  };
}
