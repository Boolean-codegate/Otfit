import 'package:flutter/foundation.dart';

import 'product.dart';

abstract final class ApiErrorCodes {
  static const String unauthorized = 'UNAUTHORIZED';
  static const String validationError = 'VALIDATION_ERROR';
  static const String invalidPhoto = 'INVALID_PHOTO';
  static const String insufficientCredits = 'INSUFFICIENT_CREDITS';
  static const String notFound = 'NOT_FOUND';
  static const String generationFailed = 'GENERATION_FAILED';
  static const String rateLimited = 'RATE_LIMITED';
}

@immutable
class ApiError {
  const ApiError({
    required this.code,
    required this.message,
    this.detail = const <String, dynamic>{},
  });

  final String code;
  final String message;
  final Map<String, dynamic> detail;

  factory ApiError.fromJson(Map<String, dynamic> json) {
    final nested = json['error'];
    final source = nested is Map ? Map<String, dynamic>.from(nested) : json;
    final rawDetail = source['detail'];
    return ApiError(
      code: (source['code'] ?? ApiErrorCodes.validationError).toString(),
      message: (source['message'] ?? '요청을 처리하지 못했어요.').toString(),
      detail: rawDetail is Map
          ? Map<String, dynamic>.from(rawDetail)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'message': message,
    'detail': detail,
  };

  Map<String, dynamic> toEnvelopeJson() => <String, dynamic>{'error': toJson()};
}

class ApiException implements Exception {
  const ApiException(this.error, {this.statusCode});

  final ApiError error;
  final int? statusCode;

  @override
  String toString() => 'ApiException(${error.code}): ${error.message}';
}

@immutable
class User {
  const User({
    required this.id,
    required this.email,
    required this.nickname,
    required this.creditBalance,
    required this.isPremium,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String nickname;
  final int creditBalance;
  final bool isPremium;
  final DateTime createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: _requiredString(json, 'id'),
    email: _requiredString(json, 'email'),
    nickname: _requiredString(json, 'nickname'),
    creditBalance: _intValue(json['credit_balance']),
    isPremium: json['is_premium'] == true,
    createdAt: _dateValue(json['created_at']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'email': email,
    'nickname': nickname,
    'credit_balance': creditBalance,
    'is_premium': isPremium,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

/// In-memory image selected through image_picker. Bytes work on Android and Web
/// without exposing a platform-specific `dart:io` File.
@immutable
class SelectedUserPhoto {
  const SelectedUserPhoto({
    required this.name,
    required this.bytes,
    this.path,
    this.selectedAt,
  });

  final String name;
  final Uint8List bytes;
  final String? path;
  final DateTime? selectedAt;

  int get byteLength => bytes.lengthInBytes;
}

@immutable
class Photo {
  const Photo({
    required this.id,
    required this.storageUrl,
    required this.width,
    required this.height,
    required this.status,
    required this.uploadedAt,
  });

  final String id;
  final String storageUrl;
  final int width;
  final int height;
  final String status;
  final DateTime uploadedAt;

  factory Photo.fromJson(Map<String, dynamic> json) => Photo(
    id: _requiredString(json, 'id'),
    storageUrl: _requiredString(json, 'storage_url'),
    width: _intValue(json['width']),
    height: _intValue(json['height']),
    status: _requiredString(json, 'status'),
    uploadedAt: _dateValue(json['uploaded_at']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'storage_url': storageUrl,
    'width': width,
    'height': height,
    'status': status,
    'uploaded_at': uploadedAt.toUtc().toIso8601String(),
  };
}

@immutable
class GarmentRegion {
  const GarmentRegion({required this.type, required this.bbox});

  final String type;
  final List<double> bbox;

  factory GarmentRegion.fromJson(Map<String, dynamic> json) => GarmentRegion(
    type: _requiredString(json, 'type'),
    bbox: _doubleList(json['bbox']),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'bbox': bbox,
  };
}

@immutable
class PhotoLighting {
  const PhotoLighting({required this.brightness, required this.direction});

  final double brightness;
  final String direction;

  factory PhotoLighting.fromJson(Map<String, dynamic> json) => PhotoLighting(
    brightness: _doubleValue(json['brightness']),
    direction: (json['direction'] ?? 'front').toString(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'brightness': brightness,
    'direction': direction,
  };
}

@immutable
class StyleSuggestion {
  const StyleSuggestion({required this.id, required this.label});

  final String id;
  final String label;

  factory StyleSuggestion.fromJson(Map<String, dynamic> json) =>
      StyleSuggestion(
        id: _requiredString(json, 'id'),
        label: _requiredString(json, 'label'),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'label': label};
}

@immutable
class PhotoAnalysis {
  const PhotoAnalysis({
    required this.photoId,
    required this.isValid,
    this.rejectReason,
    required this.personCount,
    required this.pose,
    this.garmentRegions = const <GarmentRegion>[],
    required this.occlusionScore,
    this.backgroundTags = const <String>[],
    required this.lighting,
    this.colorPalette = const <String>[],
    this.styleSuggestions = const <StyleSuggestion>[],
  });

  final String photoId;
  final bool isValid;
  final String? rejectReason;
  final int personCount;
  final String pose;
  final List<GarmentRegion> garmentRegions;
  final double occlusionScore;
  final List<String> backgroundTags;
  final PhotoLighting lighting;
  final List<String> colorPalette;
  final List<StyleSuggestion> styleSuggestions;

  factory PhotoAnalysis.fromJson(Map<String, dynamic> json) => PhotoAnalysis(
    photoId: _requiredString(json, 'photo_id'),
    isValid: json['is_valid'] == true,
    rejectReason: json['reject_reason']?.toString(),
    personCount: _intValue(json['person_count']),
    pose: (json['pose'] ?? '').toString(),
    garmentRegions: _mapList(
      json['garment_regions'],
    ).map(GarmentRegion.fromJson).toList(growable: false),
    occlusionScore: _doubleValue(json['occlusion_score']),
    backgroundTags: _stringList(json['background_tags']),
    lighting: PhotoLighting.fromJson(_mapValue(json['lighting'])),
    colorPalette: _stringList(json['color_palette']),
    styleSuggestions: _mapList(
      json['style_suggestions'],
    ).map(StyleSuggestion.fromJson).toList(growable: false),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'photo_id': photoId,
    'is_valid': isValid,
    'reject_reason': rejectReason,
    'person_count': personCount,
    'pose': pose,
    'garment_regions': garmentRegions
        .map((region) => region.toJson())
        .toList(growable: false),
    'occlusion_score': occlusionScore,
    'background_tags': backgroundTags,
    'lighting': lighting.toJson(),
    'color_palette': colorPalette,
    'style_suggestions': styleSuggestions
        .map((suggestion) => suggestion.toJson())
        .toList(growable: false),
  };
}

enum GenerationStatus {
  queued('queued'),
  analyzing('analyzing'),
  searching('searching'),
  generating('generating'),
  qualityCheck('quality_check'),
  done('done'),
  failed('failed');

  const GenerationStatus(this.wireValue);

  final String wireValue;

  static GenerationStatus fromWire(Object? value) {
    final wireValue = value?.toString();
    return GenerationStatus.values.firstWhere(
      (status) => status.wireValue == wireValue,
      orElse: () =>
          throw FormatException('Unknown generation status: $wireValue'),
    );
  }
}

@immutable
class GenerationJob {
  const GenerationJob({
    required this.jobId,
    required this.status,
    this.creditsCharged,
    this.progress = 0,
    this.stepLabel = '',
    this.error,
  });

  final String jobId;
  final GenerationStatus status;
  final int? creditsCharged;
  final double progress;
  final String stepLabel;
  final ApiError? error;

  bool get isTerminal =>
      status == GenerationStatus.done || status == GenerationStatus.failed;

  factory GenerationJob.fromJson(Map<String, dynamic> json) => GenerationJob(
    jobId: _requiredString(json, 'job_id'),
    status: GenerationStatus.fromWire(json['status']),
    creditsCharged: json['credits_charged'] == null
        ? null
        : _intValue(json['credits_charged']),
    progress: _doubleValue(json['progress']),
    stepLabel: (json['step_label'] ?? '').toString(),
    error: json['error'] is Map
        ? ApiError.fromJson(_mapValue(json['error']))
        : null,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'job_id': jobId,
    'status': status.wireValue,
    if (creditsCharged != null) 'credits_charged': creditsCharged,
    'progress': progress,
    'step_label': stepLabel,
    'error': error?.toJson(),
  };

  GenerationJob copyWith({
    GenerationStatus? status,
    int? creditsCharged,
    double? progress,
    String? stepLabel,
    Object? error = _unset,
  }) {
    return GenerationJob(
      jobId: jobId,
      status: status ?? this.status,
      creditsCharged: creditsCharged ?? this.creditsCharged,
      progress: progress ?? this.progress,
      stepLabel: stepLabel ?? this.stepLabel,
      error: identical(error, _unset) ? this.error : error as ApiError?,
    );
  }
}

@immutable
class GenerationResult {
  const GenerationResult({
    required this.id,
    required this.productId,
    required this.resultUrl,
    required this.styleLabel,
    required this.qualityScore,
    required this.identityPreserved,
    required this.isSelected,
    required this.disclaimer,
    this.localResultAsset,
  });

  final String id;
  final String productId;
  final String resultUrl;
  final String styleLabel;
  final double qualityScore;
  final bool identityPreserved;
  final bool isSelected;
  final String disclaimer;

  /// Local-only offline fixture. It is excluded from [toJson].
  final String? localResultAsset;

  String get imageAsset => localResultAsset ?? resultUrl;

  factory GenerationResult.fromJson(Map<String, dynamic> json) =>
      GenerationResult(
        id: _requiredString(json, 'id'),
        productId: _requiredString(json, 'product_id'),
        resultUrl: _requiredString(json, 'result_url'),
        styleLabel: (json['style_label'] ?? '').toString(),
        qualityScore: _doubleValue(json['quality_score']),
        identityPreserved: json['identity_preserved'] == true,
        isSelected: json['is_selected'] == true,
        disclaimer: _requiredString(json, 'disclaimer'),
        localResultAsset: json['local_result_asset']?.toString(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'product_id': productId,
    'result_url': resultUrl,
    'style_label': styleLabel,
    'quality_score': qualityScore,
    'identity_preserved': identityPreserved,
    'is_selected': isSelected,
    'disclaimer': disclaimer,
  };

  GenerationResult copyWith({bool? isSelected}) => GenerationResult(
    id: id,
    productId: productId,
    resultUrl: resultUrl,
    styleLabel: styleLabel,
    qualityScore: qualityScore,
    identityPreserved: identityPreserved,
    isSelected: isSelected ?? this.isSelected,
    disclaimer: disclaimer,
    localResultAsset: localResultAsset,
  );
}

@immutable
class GenerationResultsResponse {
  const GenerationResultsResponse({required this.jobId, required this.results});

  final String jobId;
  final List<GenerationResult> results;

  factory GenerationResultsResponse.fromJson(Map<String, dynamic> json) =>
      GenerationResultsResponse(
        jobId: _requiredString(json, 'job_id'),
        results: _mapList(
          json['results'],
        ).map(GenerationResult.fromJson).toList(growable: false),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'job_id': jobId,
    'results': results.map((result) => result.toJson()).toList(growable: false),
  };
}

/// UI-ready result that combines contract DTOs with local selection state.
@immutable
class FittingResult {
  const FittingResult({
    required this.id,
    required this.product,
    required this.userPhoto,
    required this.resultImageAsset,
    required this.selectedColor,
    required this.selectedSize,
    required this.createdAt,
    required this.disclaimer,
    this.generationResult,
  });

  final String id;
  final Product product;
  final SelectedUserPhoto userPhoto;
  final String resultImageAsset;
  final String selectedColor;
  final String selectedSize;
  final DateTime createdAt;
  final String disclaimer;
  final GenerationResult? generationResult;

  String get imageAsset => resultImageAsset;
}

enum TryOnStatus { idle, processing, completed, failed }

/// The three user-facing stages map to the API job statuses:
/// analyzing -> generating -> quality_check.
enum TryOnStep {
  analyzing(
    generationStatus: GenerationStatus.analyzing,
    message: '사진을 분석하고 있어요',
    progress: 0.25,
  ),
  applying(
    generationStatus: GenerationStatus.generating,
    message: '옷의 형태와 질감을 적용하고 있어요',
    progress: 0.62,
  ),
  finishing(
    generationStatus: GenerationStatus.qualityCheck,
    message: '자연스럽게 마무리하고 있어요',
    progress: 0.9,
  );

  const TryOnStep({
    required this.generationStatus,
    required this.message,
    required this.progress,
  });

  final GenerationStatus generationStatus;
  final String message;
  final double progress;
}

@immutable
class TryOnProcessState {
  const TryOnProcessState({
    this.status = TryOnStatus.idle,
    this.step,
    this.generationStatus,
    this.progress = 0,
    this.message = '',
    this.jobId,
    this.error,
  });

  static const TryOnProcessState idle = TryOnProcessState();

  final TryOnStatus status;
  final TryOnStep? step;
  final GenerationStatus? generationStatus;
  final double progress;
  final String message;
  final String? jobId;
  final ApiError? error;

  bool get isLoading => status == TryOnStatus.processing;
  bool get isCompleted => status == TryOnStatus.completed;
  String? get errorMessage => error?.message;

  TryOnProcessState copyWith({
    TryOnStatus? status,
    Object? step = _unset,
    Object? generationStatus = _unset,
    double? progress,
    String? message,
    Object? jobId = _unset,
    Object? error = _unset,
  }) {
    return TryOnProcessState(
      status: status ?? this.status,
      step: identical(step, _unset) ? this.step : step as TryOnStep?,
      generationStatus: identical(generationStatus, _unset)
          ? this.generationStatus
          : generationStatus as GenerationStatus?,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      jobId: identical(jobId, _unset) ? this.jobId : jobId as String?,
      error: identical(error, _unset) ? this.error : error as ApiError?,
    );
  }
}

const Object _unset = Object();

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key]?.toString() ?? '';
  if (value.isEmpty) throw FormatException('Missing required field: $key');
  return value;
}

int _intValue(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text) ?? 0,
  _ => 0,
};

double _doubleValue(Object? value) => switch (value) {
  num number => number.toDouble(),
  String text => double.tryParse(text) ?? 0,
  _ => 0,
};

DateTime _dateValue(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) throw FormatException('Invalid ISO8601 time: $value');
  return parsed.toUtc();
}

Map<String, dynamic> _mapValue(Object? value) {
  return value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

List<String> _stringList(Object? value) => value is List
    ? value.map((item) => item.toString()).toList(growable: false)
    : const <String>[];

List<double> _doubleList(Object? value) => value is List
    ? value.map(_doubleValue).toList(growable: false)
    : const <double>[];
