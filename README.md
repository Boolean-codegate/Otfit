# Otfit Backend — AI 쇼퍼블 패션 리터칭 플랫폼

사진을 업로드하면 AI가 사진 분위기에 어울리는 **실제 판매 상품**을 추천해 **옷만 자연스럽게 교체**하고,
바로 구매로 연결되는 쇼퍼블 사진 보정 앱의 백엔드입니다. (FastAPI + PostgreSQL/pgvector + Celery)

> **API 계약의 유일한 소스는 [api_contract.md](api_contract.md)** 입니다. 요청/응답 shape, 상태 전이값,
> 에러 code는 이 문서와 1:1로 일치하며, 자동 생성 문서(`/docs`)로 대조할 수 있습니다.

## 스택

- Python 3.11 · FastAPI · SQLAlchemy 2.0(async) · Alembic
- PostgreSQL 16 + **pgvector** (상품 임베딩 코사인 랭킹, ivfflat)
- Celery + Redis (생성 파이프라인 비동기 처리, beat로 보관기간 만료 사진 자동 삭제)
- JWT(access+refresh) · bcrypt
- Provider 추상화: `PROVIDER_MODE=mock|live`
  - mock: **API 키 없이 전체 플로우가 끝까지 동작** (결정적 분석/임베딩/합성 이미지)
  - live(OpenAI): 분석·판단 = `gpt-5.6-sol`(Responses API, structured output) /
    픽셀 생성 = `gpt-image-1` edit 인페인팅 / 임베딩 = `text-embedding-3-small`(512차원)

## 빠른 시작 (mock 모드)

```bash
cp .env.example .env          # PROVIDER_MODE=mock 기본
docker-compose up -d --build  # api + worker + postgres(pgvector) + redis
docker-compose exec api alembic upgrade head
docker-compose exec api python -m seeds.seed
# → 상품 40개(임베딩 포함) + 테스트 유저 test@otfit.app / test1234 (크레딧 100)
```

Swagger: http://localhost:8000/docs · 헬스체크: `GET /health`

### curl로 전체 플로우 재현

```bash
BASE=http://localhost:8000
TOKEN=$(curl -s -X POST $BASE/auth/login -H 'Content-Type: application/json' \
  -d '{"email":"test@otfit.app","password":"test1234"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
AUTH="Authorization: Bearer $TOKEN"

# 1) 업로드 (multipart + 동의)
PHOTO_ID=$(curl -s -X POST $BASE/photos -H "$AUTH" -F "file=@me.jpg" \
  -F "consent_image_processing=true" | python3 -c 'import sys,json;print(json.load(sys.stdin)["id"])')

# 2) 분석 → 3) 추천 (MODE B 스타일 그룹)
curl -s -X POST $BASE/photos/$PHOTO_ID/analyze -H "$AUTH"
curl -s -X POST $BASE/photos/$PHOTO_ID/recommendations -H "$AUTH" \
  -H 'Content-Type: application/json' -d '{"mode":"B_stylist"}'

# 4) 생성 job (202 즉시 반환, 크레딧 1 차감)
JOB_ID=$(curl -s -X POST $BASE/generations -H "$AUTH" -H 'Content-Type: application/json' \
  -d "{\"photo_id\":\"$PHOTO_ID\",\"mode\":\"B_stylist\",\"options\":{\"styles\":[\"casual\",\"minimal\"]}}" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["job_id"])')

# 5) 폴링 (2초 간격) → done이면 결과 조회 → 쇼퍼블 링크
curl -s $BASE/generations/$JOB_ID -H "$AUTH"
curl -s $BASE/generations/$JOB_ID/results -H "$AUTH"
curl -s $BASE/results/<result_id>/shop -H "$AUTH"
```

### 테스트

```bash
docker-compose exec api pytest
# 회원가입→업로드→분석→추천→생성→결과→쇼퍼블→크레딧 통합 검증 (별도 otfit_test DB 사용)
```

## live(OpenAI) 전환

`.env`에서:

```
PROVIDER_MODE=live
OPENAI_API_KEY=sk-...
```

- 마스크는 Vision이 준 `garment_regions`로 합성 (의상 영역만 투명=편집, 얼굴/배경 보존)
- **정체성 보존 안전장치**: 타이트 마스크 → 품질검사(Sol 판정 + 얼굴 영역 픽셀 유사도
  `FACE_SIMILARITY_THRESHOLD`) → 미달 시 재생성(`GENERATION_MAX_RETRIES`) → 전부 실패하면
  결과 미노출 + 크레딧 자동 환불
- 임베딩 차원은 512로 DB(pgvector)와 일치 (`dimensions=512`)

## 아키텍처

```
app/
├── routers/        # HTTP 계층 (로직 없음) — api_contract.md와 1:1
├── services/       # 비즈니스 로직 (auth/photos/recommendations/generations/credits/exports/shop/events)
├── repositories/   # DB 접근 (pgvector 랭킹 쿼리 포함)
├── models/         # SQLAlchemy 모델 (11개 테이블)
├── schemas/        # Pydantic 요청/응답 (계약 shape 그대로)
├── providers/      # base(인터페이스) / mock / openai(live)
├── storage/        # StorageService (Local → S3 교체 지점)
└── workers/        # Celery: 6단계 생성 파이프라인 + 만료 사진 정리(beat)
```

생성 파이프라인(Celery): `queued → analyzing → searching → generating → quality_check → done|failed`
각 단계마다 `progress(0~1)/step_label` 갱신, 실패 시 크레딧 자동 환불. 품질검사 탈락 결과는 노출되지 않음.

## 운영/정책 (코드 반영)

- 사진 보관기간 `PHOTO_RETENTION_DAYS`(기본 30일) 경과 시 beat 태스크가 자동 삭제, `DELETE /photos/{id}` 즉시 삭제
- 모든 결과에 disclaimer: "스타일링 시각화이며 실제 핏·사이즈 미보증"
- 신고 스텁 `POST /reports` (미성년자/타인사진/부적절 이미지)
- 상품 이미지는 partner 계약 범위 내 카탈로그만 사용 (외부 크롤 없음)
- 내보내기: 프리미엄만 워터마크 제거·고해상도 (무료는 워터마크 + 1080px)

## Flutter 연동용 엔드포인트 요약

| Method | Path | 설명 | 응답 |
|---|---|---|---|
| POST | `/auth/register` | 가입 (보너스 10크레딧) | 201 `{user, access_token, refresh_token}` |
| POST | `/auth/login` | 로그인 | 200 `{user, access_token, refresh_token}` |
| POST | `/auth/refresh` | 토큰 갱신 | 200 `{access_token, refresh_token}` |
| GET | `/me` | 내 정보 | 200 `User` |
| POST | `/consents` | 동의 upsert | 200 `Consent` |
| GET | `/consents` | 동의 목록 | 200 `{items}` |
| POST | `/photos` | 업로드 (multipart: `file`, `consent_image_processing`) | 201 `{id, storage_url, ...}` |
| POST | `/photos/{id}/analyze` | 분석 (동기) | 200 분석 결과 (`is_valid`, `style_suggestions`...) |
| DELETE | `/photos/{id}` | 즉시 삭제 | 204 |
| GET | `/products` | 카탈로그 (`category/brand/min_price/max_price/limit/cursor`) | 200 `{items, next_cursor}` |
| POST | `/photos/{id}/recommendations` | 추천 (`mode`, `style_id?`) | 200 `{groups}` (A는 `products` 평면) |
| POST | `/generations` | 생성 시작 (크레딧 1) | 202 `{job_id, status, credits_charged}` / 402 |
| GET | `/generations/{job_id}` | 폴링 (2초 권장) | 200 `{status, progress, step_label, error}` |
| GET | `/generations/{job_id}/results` | 결과 (품질 통과만) | 200 `{results[]}` (disclaimer 포함) |
| POST | `/generations/{job_id}/results/{rid}/select` | 결과 선택 | 200 `{ok}` |
| GET | `/results/{id}/shop` | 쇼퍼블 (적용+유사 상품) | 200 `{applied_product, similar_products}` |
| POST | `/results/{id}/export` | 내보내기 (`ratio, hi_res, remove_watermark`) | 200 `{export_url, watermark}` |
| POST | `/events` | 퍼널 이벤트 | 202 `{ok}` |
| GET | `/credits` | 잔액 | 200 `{balance}` |
| POST | `/credits/purchase` | 충전 (결제 목) | 200 `{balance, transaction_id}` |
| POST | `/reports` | 신고 스텁 | 202 `{ok}` |

에러 공통 포맷: `{"error": {"code", "message", "detail"}}` —
`UNAUTHORIZED / VALIDATION_ERROR / INVALID_PHOTO / INSUFFICIENT_CREDITS / NOT_FOUND / GENERATION_FAILED`

## 확장 예정 (스텁)

프리미엄 구독(`is_premium` 게이트만 존재) / 커머스 수수료 정산(`partners.commission_rate`) /
브랜드 프로모션 슬롯 / B2B API·대시보드
