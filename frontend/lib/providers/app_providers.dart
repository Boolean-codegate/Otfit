import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/token_storage.dart';
import '../mock/mock_products.dart';
import '../models/fitting_result.dart';
import '../models/product.dart';
import '../repositories/auth_repository.dart';
import '../repositories/consent_repository.dart';
import '../repositories/credit_repository.dart';
import '../repositories/http/http_product_repository.dart';
import '../repositories/http/http_try_on_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/shop_repository.dart';
import '../repositories/try_on_repository.dart';

export '../models/fitting_result.dart' show SelectedUserPhoto;

/// 백엔드 MVP 카테고리(top/jacket/shirt/dress) 기준 필터.
const List<String> productCategoryFilters = <String>[
  '전체',
  '상의',
  '재킷',
  '셔츠',
  '원피스',
];

/// mock:// 이 아니면 실 백엔드로 붙는 공용 API 클라이언트.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    tokens: SecureTokenStorage(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AppConfig.usesMockApi
      ? MockAuthRepository()
      : HttpAuthRepository(ref.watch(apiClientProvider));
});

final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  return AppConfig.usesMockApi
      ? MockConsentRepository()
      : HttpConsentRepository(ref.watch(apiClientProvider));
});

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return AppConfig.usesMockApi
      ? MockShopRepository()
      : HttpShopRepository(ref.watch(apiClientProvider));
});

final creditRepositoryProvider = Provider<CreditRepository>((ref) {
  return AppConfig.usesMockApi
      ? MockCreditRepository()
      : HttpCreditRepository(ref.watch(apiClientProvider));
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return AppConfig.usesMockApi
      ? MockProductRepository()
      : HttpProductRepository(ref.watch(apiClientProvider));
});

final tryOnRepositoryProvider = Provider<TryOnRepository>((ref) {
  return AppConfig.usesMockApi
      ? MockTryOnRepository()
      : HttpTryOnRepository(ref.watch(apiClientProvider));
});

/// 현재 세션 사용자 (HTTP 모드: GET /me, mock: 고정 유저).
final currentUserProvider = FutureProvider<User>((ref) {
  return ref.watch(authRepositoryProvider).me();
});

final productsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).getProducts();
});

final productByIdProvider = FutureProvider.family<Product?, String>((ref, id) {
  return ref.watch(productRepositoryProvider).getProductById(id);
});

final onboardingCompletedProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);

class OnboardingController extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() => state = true;

  void setCompleted(bool value) => state = value;

  void reset() => state = false;
}

final imageProcessingConsentProvider =
    NotifierProvider<ImageProcessingConsentController, bool>(
      ImageProcessingConsentController.new,
    );

class ImageProcessingConsentController extends Notifier<bool> {
  @override
  bool build() => false;

  void grant() => state = true;

  void revoke() => state = false;

  void setGranted(bool value) => state = value;
}

final uploadedPhotoProvider = NotifierProvider<UploadedPhotoController, Photo?>(
  UploadedPhotoController.new,
);

class UploadedPhotoController extends Notifier<Photo?> {
  @override
  Photo? build() => null;

  void setPhoto(Photo photo) => state = photo;

  void clear() => state = null;
}

final selectedUserPhotoProvider =
    NotifierProvider<SelectedUserPhotoController, SelectedUserPhoto?>(
      SelectedUserPhotoController.new,
    );

/// Short alias retained for feature code that refers to a selected photo.
final selectedPhotoProvider = selectedUserPhotoProvider;

class SelectedUserPhotoController extends Notifier<SelectedUserPhoto?> {
  @override
  SelectedUserPhoto? build() => null;

  void setPhoto(SelectedUserPhoto photo) {
    _discardUploadedPhoto();
    state = photo;
  }

  void selectPhoto(SelectedUserPhoto photo) => setPhoto(photo);

  void clear() {
    _discardUploadedPhoto();
    state = null;
  }

  void _discardUploadedPhoto() {
    final uploaded = ref.read(uploadedPhotoProvider);
    ref.read(uploadedPhotoProvider.notifier).clear();
    ref.read(lastPhotoAnalysisProvider.notifier).clear();
    if (uploaded != null) unawaited(_deleteSilently(uploaded.id));
  }

  Future<void> _deleteSilently(String photoId) async {
    try {
      await ref.read(tryOnRepositoryProvider).deletePhoto(photoId);
    } on Object {
      // The local selection is cleared immediately even if a future backend
      // delete request fails. A real repository can enqueue a retry here.
    }
  }
}

final selectedProductProvider =
    NotifierProvider<SelectedProductController, Product?>(
      SelectedProductController.new,
    );

class SelectedProductController extends Notifier<Product?> {
  @override
  Product? build() => null;

  void selectProduct(Product product) {
    state = product;
    ref
        .read(selectedColorProvider.notifier)
        .selectColor(
          product.availableColors.isEmpty
              ? null
              : product.availableColors.first,
        );
    ref
        .read(selectedSizeProvider.notifier)
        .selectSize(
          product.availableSizes.isEmpty ? null : product.availableSizes.first,
        );
  }

  void setProduct(Product product) => selectProduct(product);

  void clear() {
    state = null;
    ref.read(selectedColorProvider.notifier).clear();
    ref.read(selectedSizeProvider.notifier).clear();
  }
}

final selectedColorProvider =
    NotifierProvider<SelectedColorController, String?>(
      SelectedColorController.new,
    );

class SelectedColorController extends Notifier<String?> {
  @override
  String? build() => null;

  void selectColor(String? color) => state = color;

  void setColor(String? color) => state = color;

  void clear() => state = null;
}

final selectedSizeProvider = NotifierProvider<SelectedSizeController, String?>(
  SelectedSizeController.new,
);

class SelectedSizeController extends Notifier<String?> {
  @override
  String? build() => null;

  void selectSize(String? size) => state = size;

  void setSize(String? size) => state = size;

  void clear() => state = null;
}

final favoriteProductIdsProvider =
    NotifierProvider<FavoriteProductIdsController, Set<String>>(
      FavoriteProductIdsController.new,
    );

class FavoriteProductIdsController extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{
    for (final product in mockProducts)
      if (product.isFavorite) product.id,
  };

  void toggle(String productId) {
    final next = Set<String>.of(state);
    next.contains(productId) ? next.remove(productId) : next.add(productId);
    state = Set<String>.unmodifiable(next);
  }

  void toggleProduct(Product product) => toggle(product.id);

  void setFavorite(String productId, {required bool isFavorite}) {
    final next = Set<String>.of(state);
    isFavorite ? next.add(productId) : next.remove(productId);
    state = Set<String>.unmodifiable(next);
  }

  void clear() => state = <String>{};
}

final isFavoriteProvider = Provider.family<bool, String>((ref, productId) {
  return ref.watch(favoriteProductIdsProvider).contains(productId);
});

final favoriteProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final favoriteIds = ref.watch(favoriteProductIdsProvider);
  return ref
      .watch(productsProvider)
      .whenData(
        (products) => products
            .where((product) => favoriteIds.contains(product.id))
            .toList(growable: false),
      );
});

final productSearchQueryProvider =
    NotifierProvider<ProductSearchQueryController, String>(
      ProductSearchQueryController.new,
    );

class ProductSearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;

  void clear() => state = '';
}

final selectedCategoryProvider =
    NotifierProvider<SelectedCategoryController, String>(
      SelectedCategoryController.new,
    );

class SelectedCategoryController extends Notifier<String> {
  @override
  String build() => '전체';

  void selectCategory(String category) => state = category;

  void setCategory(String category) => state = category;

  void reset() => state = '전체';
}

final filteredProductsProvider = Provider<AsyncValue<List<Product>>>((ref) {
  final query = ref.watch(productSearchQueryProvider).trim().toLowerCase();
  final category = ProductCategories.apiValueFor(
    ref.watch(selectedCategoryProvider),
  );
  return ref.watch(productsProvider).whenData((products) {
    return products
        .where((product) {
          final matchesCategory =
              category == null || product.category == category;
          final matchesSearch =
              query.isEmpty ||
              <String>[
                product.title,
                product.brand,
                product.mallName,
              ].any((value) => value.toLowerCase().contains(query));
          return matchesCategory && matchesSearch;
        })
        .toList(growable: false);
  });
});

final selectedOptionsValidProvider = Provider<bool>((ref) {
  final product = ref.watch(selectedProductProvider);
  if (product == null) return false;
  final hasColor =
      product.availableColors.isEmpty ||
      ref.watch(selectedColorProvider) != null;
  final hasSize =
      product.availableSizes.isEmpty || ref.watch(selectedSizeProvider) != null;
  return hasColor && hasSize;
});

final fittingResultsProvider =
    NotifierProvider<FittingResultsController, List<FittingResult>>(
      FittingResultsController.new,
    );

class FittingResultsController extends Notifier<List<FittingResult>> {
  @override
  List<FittingResult> build() {
    final now = DateTime.now();
    final photo = SelectedUserPhoto(
      name: 'sample_user.jpg',
      bytes: Uint8List(0),
      path: 'assets/images/mock/user_photo.png',
      selectedAt: now,
    );
    const indices = <int>[6, 4, 0];
    return List<FittingResult>.unmodifiable(
      List<FittingResult>.generate(indices.length, (index) {
        final product = mockProducts[indices[index]];
        return FittingResult(
          id: 'history_mock_${index + 1}',
          product: product,
          userPhoto: photo,
          resultImageAsset: 'assets/images/mock/try_on_result_01.png',
          selectedColor: product.availableColors.first,
          selectedSize: product.availableSizes.first,
          createdAt: now.subtract(Duration(days: index * 3 + 1)),
          disclaimer: MockTryOnRepository.resultDisclaimer,
        );
      }),
    );
  }

  void add(FittingResult result) {
    state = List<FittingResult>.unmodifiable(<FittingResult>[
      result,
      ...state.where((item) => item.id != result.id),
    ]);
  }

  void remove(String resultId) {
    state = List<FittingResult>.unmodifiable(
      state.where((result) => result.id != resultId),
    );
  }

  void clear() => state = const <FittingResult>[];
}

final latestFittingResultProvider = Provider<FittingResult?>((ref) {
  final results = ref.watch(fittingResultsProvider);
  return results.isEmpty ? null : results.first;
});

final currentFittingResultProvider =
    NotifierProvider<CurrentFittingResultController, FittingResult?>(
      CurrentFittingResultController.new,
    );

class CurrentFittingResultController extends Notifier<FittingResult?> {
  @override
  FittingResult? build() => null;

  void setResult(FittingResult result) => state = result;

  void clear() => state = null;
}

final tryOnProgressProvider =
    NotifierProvider<TryOnController, TryOnProcessState>(TryOnController.new);

/// Compatibility alias used by loading widgets.
final fittingProgressProvider = tryOnProgressProvider;

class TryOnController extends Notifier<TryOnProcessState> {
  int _runToken = 0;

  @override
  TryOnProcessState build() => TryOnProcessState.idle;

  Future<FittingResult?> startTryOn({Duration? stageDuration}) async {
    if (state.isLoading) return null;

    final photo = ref.read(selectedUserPhotoProvider);
    final product = ref.read(selectedProductProvider);
    final color = ref.read(selectedColorProvider);
    final size = ref.read(selectedSizeProvider);
    if (photo == null) {
      fail('먼저 피팅에 사용할 사진을 선택해 주세요.', code: 'PHOTO_REQUIRED');
      return null;
    }
    if (product == null) {
      fail('먼저 입어볼 상품을 선택해 주세요.', code: 'PRODUCT_REQUIRED');
      return null;
    }

    final token = ++_runToken;
    final repository = ref.read(tryOnRepositoryProvider);
    final pollInterval =
        stageDuration ??
        (AppConfig.usesMockApi
            ? const Duration(milliseconds: 850)
            : const Duration(seconds: 2));
    try {
      ref.read(currentFittingResultProvider.notifier).clear();
      state = const TryOnProcessState(
        status: TryOnStatus.processing,
        generationStatus: GenerationStatus.queued,
        message: 'AI 피팅을 준비하고 있어요',
      );
      var uploaded = ref.read(uploadedPhotoProvider);
      uploaded ??= await repository.uploadPhoto(
        photo: photo,
        consentImageProcessing: ref.read(imageProcessingConsentProvider),
      );
      ref.read(uploadedPhotoProvider.notifier).setPhoto(uploaded);
      if (!_isCurrent(token)) return null;

      final analysis = await repository.analyzePhoto(uploaded.id);
      if (!_isCurrent(token)) return null;
      ref.read(lastPhotoAnalysisProvider.notifier).setAnalysis(analysis);
      if (!analysis.isValid) {
        fail(
          '사진을 확인해 주세요: ${analysis.rejectReason ?? 'INVALID_PHOTO'}',
          code: ApiErrorCodes.invalidPhoto,
        );
        return null;
      }

      var job = await repository.createGeneration(
        photoId: uploaded.id,
        mode: GenerationModes.direct,
        productId: product.id,
        options: <String, dynamic>{
          'styles': <String>['casual'],
        },
      );
      if (!_isCurrent(token)) return null;

      // 실 API(gpt-image-2 경로)는 생성에 2~3분 걸릴 수 있어 폴링 한도를 넉넉히 잡는다
      final maxPollAttempts = AppConfig.usesMockApi ? 30 : 120;
      var pollAttempts = 0;
      while (!job.isTerminal && pollAttempts < maxPollAttempts) {
        await Future<void>.delayed(pollInterval);
        if (!_isCurrent(token)) return null;
        job = await repository.getGenerationJob(job.jobId);
        pollAttempts++;
        if (!_isCurrent(token)) return null;
        if (job.status == GenerationStatus.failed) {
          throw ApiException(
            job.error ??
                const ApiError(
                  code: ApiErrorCodes.generationFailed,
                  message: 'AI 피팅을 완료하지 못했어요.',
                ),
          );
        }

        final step = _stepFor(job.status);
        if (step != null) {
          state = TryOnProcessState(
            status: TryOnStatus.processing,
            step: step,
            generationStatus: job.status,
            progress: job.progress > 0 ? job.progress : step.progress,
            message: step.message,
            jobId: job.jobId,
          );
        }
      }

      if (job.status != GenerationStatus.done) {
        throw const ApiException(
          ApiError(
            code: ApiErrorCodes.generationFailed,
            message: '피팅 결과가 아직 준비되지 않았어요.',
          ),
        );
      }
      final response = await repository.getGenerationResults(job.jobId);
      if (!_isCurrent(token)) return null;
      if (response.results.isEmpty) {
        throw const ApiException(
          ApiError(
            code: ApiErrorCodes.generationFailed,
            message: '품질 기준을 통과한 결과가 없어요. 다시 시도해 주세요.',
          ),
        );
      }

      final generated = response.results.first;
      await repository.selectGenerationResult(
        jobId: job.jobId,
        resultId: generated.id,
      );
      if (!_isCurrent(token)) return null;
      final selectedGenerated = generated.copyWith(isSelected: true);
      final result = FittingResult(
        id: selectedGenerated.id,
        product: product,
        userPhoto: photo,
        resultImageAsset: selectedGenerated.imageAsset,
        selectedColor:
            color ??
            (product.availableColors.isEmpty
                ? '기본 색상'
                : product.availableColors.first),
        selectedSize:
            size ??
            (product.availableSizes.isEmpty
                ? '기본 사이즈'
                : product.availableSizes.first),
        createdAt: DateTime.now(),
        disclaimer: selectedGenerated.disclaimer,
        generationResult: selectedGenerated,
      );
      ref.read(fittingResultsProvider.notifier).add(result);
      ref.read(currentFittingResultProvider.notifier).setResult(result);
      state = TryOnProcessState(
        status: TryOnStatus.completed,
        generationStatus: GenerationStatus.done,
        progress: 1,
        message: 'AI 피팅이 완료되었어요',
        jobId: job.jobId,
      );
      return result;
    } on ApiException catch (exception) {
      if (_isCurrent(token)) {
        state = TryOnProcessState(
          status: TryOnStatus.failed,
          generationStatus: GenerationStatus.failed,
          message: exception.error.message,
          error: exception.error,
        );
      }
      return null;
    } catch (error) {
      if (_isCurrent(token)) {
        fail('잠시 후 다시 시도해 주세요.', detail: error.toString());
      }
      return null;
    }
  }

  void setStep(TryOnStep step) {
    state = TryOnProcessState(
      status: TryOnStatus.processing,
      step: step,
      generationStatus: step.generationStatus,
      progress: step.progress,
      message: step.message,
      jobId: state.jobId,
    );
  }

  TryOnStep? _stepFor(GenerationStatus status) => switch (status) {
    GenerationStatus.analyzing => TryOnStep.analyzing,
    GenerationStatus.searching ||
    GenerationStatus.generating => TryOnStep.applying,
    GenerationStatus.qualityCheck => TryOnStep.finishing,
    _ => null,
  };

  void fail(
    String message, {
    String code = ApiErrorCodes.generationFailed,
    String? detail,
  }) {
    state = TryOnProcessState(
      status: TryOnStatus.failed,
      generationStatus: GenerationStatus.failed,
      message: message,
      error: ApiError(
        code: code,
        message: message,
        detail: detail == null
            ? const <String, dynamic>{}
            : <String, dynamic>{'debug': detail},
      ),
    );
  }

  void cancel() {
    _runToken++;
    state = TryOnProcessState.idle;
  }

  void reset() {
    _runToken++;
    state = TryOnProcessState.idle;
  }

  bool _isCurrent(int token) => token == _runToken;
}

final lastPhotoAnalysisProvider =
    NotifierProvider<LastPhotoAnalysisController, PhotoAnalysis?>(
      LastPhotoAnalysisController.new,
    );

class LastPhotoAnalysisController extends Notifier<PhotoAnalysis?> {
  @override
  PhotoAnalysis? build() => null;

  void setAnalysis(PhotoAnalysis analysis) => state = analysis;

  void clear() => state = null;
}
