/// 실 백엔드(localhost:8000, mock provider 모드) 대상 HTTP 계층 통합 테스트.
///
/// 기본 `flutter test`에서는 스킵되고, 백엔드가 떠 있을 때만 이렇게 실행한다:
///   flutter test test/http_repositories_integration_test.dart \
///     --dart-define=INTEGRATION_BASE_URL=http://localhost:8000
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/token_storage.dart';
import 'package:frontend/models/consent.dart';
import 'package:frontend/models/fitting_result.dart';
import 'package:frontend/repositories/auth_repository.dart';
import 'package:frontend/repositories/consent_repository.dart';
import 'package:frontend/repositories/credit_repository.dart';
import 'package:frontend/repositories/http/http_product_repository.dart';
import 'package:frontend/repositories/http/http_try_on_repository.dart';
import 'package:frontend/repositories/shop_repository.dart';
import 'package:frontend/repositories/try_on_repository.dart';

const String baseUrl = String.fromEnvironment('INTEGRATION_BASE_URL');

/// 24bpp BMP를 직접 만들어 업로드용 이미지로 쓴다 (외부 이미지 패키지 불필요.
/// 백엔드는 PIL로 열 수 있는 모든 포맷을 받고, 짧은 변 512px 이상만 요구).
Uint8List buildBmp(int width, int height) {
  final rowSize = ((width * 3 + 3) ~/ 4) * 4;
  final pixelBytes = rowSize * height;
  final fileSize = 54 + pixelBytes;
  final bytes = Uint8List(fileSize);
  final data = ByteData.view(bytes.buffer);

  bytes[0] = 0x42; // 'B'
  bytes[1] = 0x4D; // 'M'
  data.setUint32(2, fileSize, Endian.little);
  data.setUint32(10, 54, Endian.little); // pixel data offset
  data.setUint32(14, 40, Endian.little); // BITMAPINFOHEADER
  data.setInt32(18, width, Endian.little);
  data.setInt32(22, height, Endian.little);
  data.setUint16(26, 1, Endian.little); // planes
  data.setUint16(28, 24, Endian.little); // bpp
  data.setUint32(34, pixelBytes, Endian.little);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = 54 + y * rowSize + x * 3;
      bytes[offset] = 120; // B
      bytes[offset + 1] = 150; // G
      bytes[offset + 2] = 175; // R
    }
  }
  return bytes;
}

void main() {
  final skip = baseUrl.isEmpty
      ? 'INTEGRATION_BASE_URL dart-define이 없으면 스킵 (백엔드 필요)'
      : false;

  late ApiClient client;

  setUpAll(() {
    client = ApiClient(baseUrl: baseUrl, tokens: InMemoryTokenStorage());
  });

  test('전체 퍼널: 로그인→/me→동의→상품→업로드→분석→추천→생성→결과→쇼퍼블→크레딧', () async {
    final auth = HttpAuthRepository(client);

    // 로그인 (시드 유저) + /me
    final user = await auth.login(
      email: 'test@otfit.app',
      password: 'test1234',
    );
    expect(user.email, 'test@otfit.app');
    final me = await auth.me();
    expect(me.id, user.id);
    expect(me.creditBalance, greaterThan(0));

    // 동의
    final consents = HttpConsentRepository(client);
    final consent = await consents.upsert(
      type: ConsentTypes.imageProcessing,
      granted: true,
    );
    expect(consent.granted, isTrue);
    expect(
      (await consents.list()).any(
        (item) => item.type == ConsentTypes.imageProcessing && item.granted,
      ),
      isTrue,
    );

    // 상품 목록 + 페이지네이션 + 캐시 조회
    final products = HttpProductRepository(client);
    final page = await products.fetchProducts(limit: 5);
    expect(page.items, hasLength(5));
    expect(page.nextCursor, isNotNull);
    final product = page.items.first;
    expect(product.price, greaterThan(0));
    expect(await products.getProductById(product.id), product);

    // 업로드 → 분석 → 추천
    final tryOn = HttpTryOnRepository(client);
    final photo = await tryOn.uploadPhoto(
      photo: SelectedUserPhoto(name: 'itest.bmp', bytes: buildBmp(600, 800)),
      consentImageProcessing: true,
    );
    expect(photo.status, 'uploaded');

    final analysis = await tryOn.analyzePhoto(photo.id);
    expect(analysis.isValid, isTrue);
    expect(analysis.styleSuggestions, isNotEmpty);
    expect(analysis.garmentRegions.first.bbox, hasLength(4));

    final recommendation = await tryOn.getRecommendations(
      photoId: photo.id,
      mode: GenerationModes.stylist,
    );
    expect(recommendation.groups, isNotEmpty);
    expect(recommendation.groups.first.products, isNotEmpty);

    // 생성 (A_direct) → 폴링 → 결과 → 선택
    var job = await tryOn.createGeneration(
      photoId: photo.id,
      mode: GenerationModes.direct,
      productId: recommendation.groups.first.products.first.id,
    );
    expect(job.status, GenerationStatus.queued);
    expect(job.creditsCharged, 1);

    // 실 생성(gpt-image-2)은 2분 안팎 걸릴 수 있어 최대 4분 폴링
    for (var attempt = 0; attempt < 80 && !job.isTerminal; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 3));
      job = await tryOn.getGenerationJob(job.jobId);
    }
    expect(job.status, GenerationStatus.done);
    expect(job.progress, 1.0);

    final results = await tryOn.getGenerationResults(job.jobId);
    expect(results.results, isNotEmpty);
    final generated = results.results.first;
    expect(generated.identityPreserved, isTrue);
    expect(generated.disclaimer, contains('스타일링 시각화'));
    await tryOn.selectGenerationResult(
      jobId: job.jobId,
      resultId: generated.id,
    );

    // 쇼퍼블 + 이벤트
    final shop = HttpShopRepository(client);
    final shopInfo = await shop.getShopForResult(generated.id);
    expect(shopInfo.appliedProduct.id, generated.productId);
    expect(shopInfo.similarProducts, isNotEmpty);
    await shop.recordEvent(
      type: EventTypes.productClick,
      sessionId: 'itest',
      payload: <String, dynamic>{'product_id': generated.productId},
    );

    // 크레딧 (생성 1회 차감 확인)
    final credits = HttpCreditRepository(client);
    expect(await credits.getBalance(), me.creditBalance - 1);

    // 정리
    await tryOn.deletePhoto(photo.id);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 6)));

  test('에러 매핑: 잘못된 로그인 → ApiException(UNAUTHORIZED)', () async {
    final fresh = ApiClient(baseUrl: baseUrl, tokens: InMemoryTokenStorage());
    final auth = HttpAuthRepository(fresh);
    try {
      await auth.login(email: 'test@otfit.app', password: 'wrong-password');
      fail('should have thrown');
    } on ApiException catch (exception) {
      expect(exception.error.code, ApiErrorCodes.unauthorized);
      expect(exception.statusCode, 401);
    }
  }, skip: skip);
}
