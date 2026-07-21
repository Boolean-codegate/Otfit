import '../mock/mock_products.dart';
import '../models/fitting_result.dart';
import '../models/product.dart';
import '../models/recommendation.dart';

abstract final class GenerationModes {
  static const String direct = 'A_direct';
  static const String stylist = 'B_stylist';
  static const String similar = 'C_similar';
  static const String variation = 'D_variation';

  static const List<String> values = <String>[
    direct,
    stylist,
    similar,
    variation,
  ];
}

abstract class TryOnRepository {
  /// Mirrors multipart POST /photos.
  Future<Photo> uploadPhoto({
    required SelectedUserPhoto photo,
    required bool consentImageProcessing,
  });

  /// Mirrors POST /photos/{id}/analyze.
  Future<PhotoAnalysis> analyzePhoto(String photoId);

  /// Mirrors DELETE /photos/{id}.
  Future<void> deletePhoto(String photoId);

  /// Mirrors POST /photos/{id}/recommendations.
  Future<RecommendationResponse> getRecommendations({
    required String photoId,
    required String mode,
    String? styleId,
  });

  /// Mirrors POST /generations.
  /// [productIds]: 멀티 아이템(옷/하의/액세서리, 최대 3) — 첫 항목이 대표 상품.
  Future<GenerationJob> createGeneration({
    required String photoId,
    required String mode,
    required String productId,
    List<String>? productIds,
    Map<String, dynamic> options = const <String, dynamic>{},
  });

  /// Mirrors GET /generations/{job_id}. A real implementation should poll this
  /// endpoint at the interval chosen by the caller (the contract suggests 2s).
  Future<GenerationJob> getGenerationJob(String jobId);

  /// Mirrors GET /generations/{job_id}/results.
  Future<GenerationResultsResponse> getGenerationResults(String jobId);

  /// Mirrors POST /generations/{job_id}/results/{result_id}/select.
  Future<void> selectGenerationResult({
    required String jobId,
    required String resultId,
  });

  /// Mirrors POST /results/{id}/export — 다운로드 가능한 URL을 반환.
  Future<({String url, bool watermarked})> exportResult({
    required String resultId,
    String? ratio,
    bool hiRes = false,
    bool removeWatermark = false,
  });
}

class MockTryOnRepository extends TryOnRepository {
  MockTryOnRepository({this.latency = const Duration(milliseconds: 120)});

  static const String resultDisclaimer = '스타일링 시각화이며 실제 핏/사이즈를 보증하지 않습니다';

  final Duration latency;
  final Map<String, Photo> _photos = <String, Photo>{};
  final Map<String, GenerationJob> _jobs = <String, GenerationJob>{};
  final Map<String, int> _pollCounts = <String, int>{};
  final Map<String, String> _jobProductIds = <String, String>{};
  final Map<String, GenerationResultsResponse> _results =
      <String, GenerationResultsResponse>{};
  int _photoSequence = 0;
  int _jobSequence = 0;

  @override
  Future<Photo> uploadPhoto({
    required SelectedUserPhoto photo,
    required bool consentImageProcessing,
  }) async {
    await _wait();
    if (!consentImageProcessing) {
      throw const ApiException(
        ApiError(
          code: ApiErrorCodes.validationError,
          message: '이미지 처리 동의가 필요해요.',
          detail: <String, dynamic>{'field': 'consent_image_processing'},
        ),
        statusCode: 400,
      );
    }
    if (photo.bytes.isEmpty) {
      throw const ApiException(
        ApiError(
          code: ApiErrorCodes.invalidPhoto,
          message: '선택한 사진을 읽을 수 없어요.',
        ),
        statusCode: 422,
      );
    }

    final id = 'p_mock_${++_photoSequence}';
    final uploaded = Photo(
      id: id,
      storageUrl: 'https://mock.otfit.local/photos/$id.jpg',
      width: 1080,
      height: 1440,
      status: 'uploaded',
      uploadedAt: DateTime.now().toUtc(),
    );
    _photos[id] = uploaded;
    return uploaded;
  }

  @override
  Future<PhotoAnalysis> analyzePhoto(String photoId) async {
    await _wait();
    _requirePhoto(photoId);
    return PhotoAnalysis(
      photoId: photoId,
      isValid: true,
      personCount: 1,
      pose: 'front',
      garmentRegions: const <GarmentRegion>[
        GarmentRegion(type: 'top', bbox: <double>[270, 310, 540, 610]),
      ],
      occlusionScore: 0.08,
      backgroundTags: const <String>['indoor', 'daylight'],
      lighting: const PhotoLighting(brightness: 0.78, direction: 'front'),
      colorPalette: const <String>['#F2E8D5', '#3A6EA5'],
      styleSuggestions: const <StyleSuggestion>[
        StyleSuggestion(id: 'st_1', label: '미니멀 데일리룩'),
        StyleSuggestion(id: 'st_2', label: '모던 시티룩'),
      ],
    );
  }

  @override
  Future<void> deletePhoto(String photoId) async {
    await _wait();
    _photos.remove(photoId);
  }

  @override
  Future<RecommendationResponse> getRecommendations({
    required String photoId,
    required String mode,
    String? styleId,
  }) async {
    await _wait();
    _requirePhoto(photoId);
    if (mode != GenerationModes.stylist) {
      return RecommendationResponse(
        photoId: photoId,
        mode: mode,
        products: mockProducts.take(12).toList(growable: false),
      );
    }
    const suggestions = <({String id, String label, String category})>[
      (id: 'st_1', label: '미니멀 데일리룩', category: ProductCategories.top),
      (id: 'st_2', label: '모던 시티룩', category: ProductCategories.jacket),
    ];
    return RecommendationResponse(
      photoId: photoId,
      mode: mode,
      groups: <RecommendationGroup>[
        for (final suggestion in suggestions)
          if (styleId == null || styleId == suggestion.id)
            RecommendationGroup(
              styleId: suggestion.id,
              label: suggestion.label,
              products: mockProducts
                  .where((product) => product.category == suggestion.category)
                  .take(4)
                  .toList(growable: false),
            ),
      ],
    );
  }

  @override
  Future<GenerationJob> createGeneration({
    required String photoId,
    required String mode,
    required String productId,
    List<String>? productIds,
    Map<String, dynamic> options = const <String, dynamic>{},
  }) async {
    await _wait();
    _requirePhoto(photoId);
    if (!GenerationModes.values.contains(mode)) {
      throw ApiException(
        ApiError(
          code: ApiErrorCodes.validationError,
          message: '지원하지 않는 생성 모드예요.',
          detail: <String, dynamic>{'mode': mode},
        ),
        statusCode: 400,
      );
    }
    if (mockProductById(productId) == null) {
      throw ApiException(
        ApiError(
          code: ApiErrorCodes.notFound,
          message: '상품을 찾을 수 없어요.',
          detail: <String, dynamic>{'product_id': productId},
        ),
        statusCode: 404,
      );
    }

    final jobId = 'job_mock_${++_jobSequence}';
    final job = GenerationJob(
      jobId: jobId,
      status: GenerationStatus.queued,
      creditsCharged: 1,
      stepLabel: '피팅을 준비하고 있어요',
    );
    _jobs[jobId] = job;
    _pollCounts[jobId] = 0;
    _jobProductIds[jobId] = productId;
    return job;
  }

  @override
  Future<GenerationJob> getGenerationJob(String jobId) async {
    await _wait();
    final existing = _jobs[jobId];
    if (existing == null) throw _notFound('job_id', jobId);

    final pollCount = (_pollCounts[jobId] ?? 0) + 1;
    _pollCounts[jobId] = pollCount;
    final next = switch (pollCount) {
      1 => existing.copyWith(
        status: GenerationStatus.analyzing,
        progress: 0.25,
        stepLabel: '사진을 분석하고 있어요',
      ),
      2 => existing.copyWith(
        status: GenerationStatus.generating,
        progress: 0.62,
        stepLabel: '옷의 형태와 질감을 적용하고 있어요',
      ),
      3 => existing.copyWith(
        status: GenerationStatus.qualityCheck,
        progress: 0.9,
        stepLabel: '자연스럽게 마무리하고 있어요',
      ),
      _ => existing.copyWith(
        status: GenerationStatus.done,
        progress: 1,
        stepLabel: 'AI 피팅이 완료되었어요',
      ),
    };
    _jobs[jobId] = next;

    if (next.status == GenerationStatus.done) {
      _results.putIfAbsent(jobId, () => _createResults(jobId));
    }
    return next;
  }

  @override
  Future<GenerationResultsResponse> getGenerationResults(String jobId) async {
    await _wait();
    final job = _jobs[jobId];
    if (job == null) throw _notFound('job_id', jobId);
    if (job.status != GenerationStatus.done) {
      throw const ApiException(
        ApiError(
          code: ApiErrorCodes.validationError,
          message: '아직 피팅 결과가 준비되지 않았어요.',
        ),
        statusCode: 409,
      );
    }
    return _results.putIfAbsent(jobId, () => _createResults(jobId));
  }

  @override
  Future<void> selectGenerationResult({
    required String jobId,
    required String resultId,
  }) async {
    await _wait();
    final response = _results[jobId];
    if (response == null) throw _notFound('job_id', jobId);
    if (!response.results.any((result) => result.id == resultId)) {
      throw _notFound('result_id', resultId);
    }
    _results[jobId] = GenerationResultsResponse(
      jobId: jobId,
      results: response.results
          .map((result) => result.copyWith(isSelected: result.id == resultId))
          .toList(growable: false),
    );
  }

  GenerationResultsResponse _createResults(String jobId) {
    final productId = _jobProductIds[jobId];
    if (productId == null) throw _notFound('job_id', jobId);
    return GenerationResultsResponse(
      jobId: jobId,
      results: <GenerationResult>[
        GenerationResult(
          id: 'res_${jobId}_1',
          productId: productId,
          resultUrl: 'https://mock.otfit.local/results/$jobId.jpg',
          styleLabel: 'casual',
          qualityScore: 0.92,
          identityPreserved: true,
          isSelected: false,
          disclaimer: resultDisclaimer,
          localResultAsset: 'assets/images/mock/try_on_result_01.png',
        ),
      ],
    );
  }

  void _requirePhoto(String photoId) {
    if (!_photos.containsKey(photoId)) throw _notFound('photo_id', photoId);
  }

  @override
  Future<({String url, bool watermarked})> exportResult({
    required String resultId,
    String? ratio,
    bool hiRes = false,
    bool removeWatermark = false,
  }) async {
    await _wait();
    return (url: 'assets/images/mock/try_on_result_01.png', watermarked: true);
  }

  ApiException _notFound(String field, String id) => ApiException(
    ApiError(
      code: ApiErrorCodes.notFound,
      message: '요청한 데이터를 찾을 수 없어요.',
      detail: <String, dynamic>{field: id},
    ),
    statusCode: 404,
  );

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }
}
