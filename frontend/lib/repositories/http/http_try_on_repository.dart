import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../models/fitting_result.dart';
import '../../models/recommendation.dart';
import '../try_on_repository.dart';

/// 계약 §3(사진) + §5(생성 비동기 플로우) 구현.
class HttpTryOnRepository extends TryOnRepository {
  HttpTryOnRepository(this._client);

  final ApiClient _client;

  @override
  Future<Photo> uploadPhoto({
    required SelectedUserPhoto photo,
    required bool consentImageProcessing,
  }) {
    return guardApi(() async {
      final form = FormData.fromMap(<String, dynamic>{
        'file': MultipartFile.fromBytes(photo.bytes, filename: photo.name),
        'consent_image_processing': consentImageProcessing.toString(),
      });
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/photos',
        data: form,
      );
      return Photo.fromJson(response.data ?? const <String, dynamic>{});
    });
  }

  @override
  Future<PhotoAnalysis> analyzePhoto(String photoId) {
    return guardApi(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/photos/$photoId/analyze',
      );
      return PhotoAnalysis.fromJson(response.data ?? const <String, dynamic>{});
    });
  }

  @override
  Future<void> deletePhoto(String photoId) {
    return guardApi(() async {
      await _client.dio.delete<void>('/photos/$photoId');
    });
  }

  @override
  Future<RecommendationResponse> getRecommendations({
    required String photoId,
    required String mode,
    String? styleId,
  }) {
    return guardApi(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/photos/$photoId/recommendations',
        data: <String, dynamic>{'mode': mode, 'style_id': ?styleId},
      );
      return RecommendationResponse.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    });
  }

  @override
  Future<GenerationJob> createGeneration({
    required String photoId,
    required String mode,
    required String productId,
    List<String>? productIds,
    Map<String, dynamic> options = const <String, dynamic>{},
  }) {
    return guardApi(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/generations',
        data: <String, dynamic>{
          'photo_id': photoId,
          'mode': mode,
          'product_id': productId,
          'product_ids': ?productIds,
          'options': options,
        },
      );
      return GenerationJob.fromJson(response.data ?? const <String, dynamic>{});
    });
  }

  @override
  Future<GenerationJob> getGenerationJob(String jobId) {
    return guardApi(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/generations/$jobId',
      );
      return GenerationJob.fromJson(response.data ?? const <String, dynamic>{});
    });
  }

  @override
  Future<GenerationResultsResponse> getGenerationResults(String jobId) {
    return guardApi(() async {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/generations/$jobId/results',
      );
      return GenerationResultsResponse.fromJson(
        response.data ?? const <String, dynamic>{},
      );
    });
  }

  @override
  Future<void> selectGenerationResult({
    required String jobId,
    required String resultId,
  }) {
    return guardApi(() async {
      await _client.dio.post<Map<String, dynamic>>(
        '/generations/$jobId/results/$resultId/select',
      );
    });
  }

  @override
  Future<({String url, bool watermarked})> exportResult({
    required String resultId,
    String? ratio,
    bool hiRes = false,
    bool removeWatermark = false,
  }) {
    return guardApi(() async {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/results/$resultId/export',
        data: <String, dynamic>{
          'ratio': ?ratio,
          'hi_res': hiRes,
          'remove_watermark': removeWatermark,
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      return (
        url: (data['export_url'] ?? '').toString(),
        watermarked: data['watermark'] == true,
      );
    });
  }

  @override
  Future<Uint8List> exportResultBytes({
    required String resultId,
    String? ratio,
  }) {
    return guardApi(() async {
      final response = await _client.dio.get<List<int>>(
        '/results/$resultId/export/file',
        queryParameters: <String, dynamic>{'ratio': ?ratio},
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const <int>[]);
    });
  }
}
