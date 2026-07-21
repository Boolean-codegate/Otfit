# API 계약서 (단일 소스) — AI 쇼퍼블 패션 리터칭 플랫폼

> **이 문서가 백엔드 ↔ 프론트의 유일한 계약이다.** 백엔드는 이대로 구현하고, 프론트는 이대로 mock을 만든다.
> 나중에 통합할 때 이 문서와 실제 구현이 다르면 → 이 문서를 먼저 고치고 양쪽 반영. (문서 우선)
> 규칙: 모든 요청/응답 JSON, 인증은 `Authorization: Bearer <access_token>`, 시간은 ISO8601(UTC), 금액은 정수(원).

## 0. 공통 규약
- Base URL: `{API_BASE_URL}` (예: `http://localhost:8000`)
- 성공: 2xx + 아래 body. 생성처럼 오래 걸리는 건 `202` + job.
- 에러 공통 포맷:
  ```json
  { "error": { "code": "INVALID_PHOTO", "message": "사람이 여러 명입니다", "detail": {} } }
  ```
  대표 code: `UNAUTHORIZED`, `VALIDATION_ERROR`, `INVALID_PHOTO`, `INSUFFICIENT_CREDITS`, `NOT_FOUND`, `GENERATION_FAILED`, `RATE_LIMITED`.
- 페이지네이션: `?limit=20&cursor=<opaque>` → 응답에 `next_cursor`(없으면 null).
- ID는 문자열(UUID).

## 1. 인증
### POST /auth/register
req: `{ "email": "a@b.com", "password": "…", "nickname": "지훈" }`
res 201: `{ "user": {User}, "access_token": "…", "refresh_token": "…" }`

### POST /auth/login
req: `{ "email": "a@b.com", "password": "…" }`
res 200: `{ "user": {User}, "access_token": "…", "refresh_token": "…" }`

### POST /auth/social
카카오/구글 SDK로 받은 토큰을 서버가 검증해 로그인. 미가입 사용자는 자동 가입.
req: `{ "provider": "kakao" | "google", "token": "…" }`
  - kakao → SDK의 **access_token**, google → SDK의 **id_token**
res 200(기존 사용자) / 201(신규 가입, 보너스 크레딧 지급): `{ "user": {User}, "access_token": "…", "refresh_token": "…" }`
에러: 토큰 무효 `401 UNAUTHORIZED`, 이미 다른 소셜과 연결된 이메일 `409 CONFLICT`
참고: 같은 이메일의 기존 이메일 가입 계정이 있으면 소셜 계정이 자동 연결됨. 카카오가 이메일 미제공 시 `kakao_<id>@social.otfit.app` 형태의 플레이스홀더 이메일 사용.

### POST /auth/refresh
req: `{ "refresh_token": "…" }`
res 200: `{ "access_token": "…", "refresh_token": "…" }`

### GET /me  (auth)
res 200: `{User}`

**User 객체**
```json
{ "id": "u_1", "email": "a@b.com", "nickname": "지훈",
  "credit_balance": 30, "is_premium": false, "created_at": "2026-07-21T00:00:00Z" }
```

## 2. 동의 / 프라이버시
### POST /consents  (auth)
req: `{ "type": "image_processing", "granted": true }`  // type: image_processing | marketing | reuse
res 200: `{ "id": "c_1", "type": "image_processing", "granted": true, "granted_at": "…" }`

### GET /consents  (auth) → `{ "items": [{Consent}] }`

## 3. 사진
### POST /photos  (auth, multipart/form-data)
form: `file`(이미지), `consent_image_processing`=true
res 201:
```json
{ "id": "p_1", "storage_url": "https://…/p_1.jpg",
  "width": 1080, "height": 1440, "status": "uploaded", "uploaded_at": "…" }
```

### POST /photos/{id}/analyze  (auth)
res 200 (분석은 빠르면 동기 반환, 느리면 202+job — MVP는 동기 가정):
```json
{ "photo_id": "p_1", "is_valid": true, "reject_reason": null,
  "person_count": 1, "pose": "front",
  "garment_regions": [{ "type": "top", "bbox": [x,y,w,h] }],
  "occlusion_score": 0.1,
  "background_tags": ["beach","daylight"],
  "lighting": { "brightness": 0.7, "direction": "front" },
  "color_palette": ["#f2e8d5","#3a6ea5"],
  "style_suggestions": [
    { "id": "st_1", "label": "청량한 휴양지룩" },
    { "id": "st_2", "label": "미니멀 데이트룩" }
  ] }
```
검증 실패 예: `is_valid=false, reject_reason="MULTIPLE_PERSONS" | "HEAVY_OCCLUSION" | "UNSUPPORTED_POSE" | "LOW_RESOLUTION"`

### DELETE /photos/{id}  (auth) → 204  (사진 즉시 삭제)

## 4. 상품 / 추천
### GET /products  (auth)  ?category=top&brand=&min_price=&max_price=&limit=&cursor=
res 200: `{ "items": [{Product}], "next_cursor": null }`

**Product 객체**
```json
{ "id": "prod_1", "title": "린넨 오버셔츠", "brand": "ACME",
  "category": "top", "price": 39000, "currency": "KRW",
  "stock_status": "in_stock", "product_url": "https://shop…/1",
  "image_url": "https://…/prod_1.jpg",
  "attributes": { "color": "ivory", "pattern": "solid", "length": "regular", "material": "linen" } }
```

### POST /photos/{id}/recommendations  (auth)
req: `{ "mode": "B_stylist", "style_id": "st_1" }`  // mode: A_direct | B_stylist | C_similar | D_variation
res 200:
```json
{ "photo_id": "p_1", "mode": "B_stylist",
  "groups": [
    { "style_id": "st_1", "label": "청량한 휴양지룩",
      "products": [{Product}, {Product}] }
  ] }
```
(MODE A는 groups 없이 `products` 평면 리스트도 허용)

## 5. 생성 (핵심 비동기 플로우)
### POST /generations  (auth)
req: `{ "photo_id": "p_1", "mode": "B_stylist", "product_id": "prod_1", "options": { "styles": ["casual","formal"] } }`
res 202:
```json
{ "job_id": "job_1", "status": "queued", "credits_charged": 1 }
```
크레딧 부족 시 402 `INSUFFICIENT_CREDITS`.

### GET /generations/{job_id}  (auth)  ← 프론트가 2초 간격 폴링
res 200:
```json
{ "job_id": "job_1",
  "status": "generating",   // queued|analyzing|searching|generating|quality_check|done|failed
  "progress": 0.6,
  "step_label": "의상 생성 중",
  "error": null }
```
`status="done"`이면 아래 results 호출. `failed`면 `error`에 code/message + 크레딧 자동 환불.

### GET /generations/{job_id}/results  (auth)
res 200:
```json
{ "job_id": "job_1",
  "results": [
    { "id": "res_1", "product_id": "prod_1",
      "result_url": "https://…/res_1.jpg",
      "style_label": "casual",
      "quality_score": 0.92, "identity_preserved": true,
      "is_selected": false,
      "disclaimer": "스타일링 시각화이며 실제 핏/사이즈를 보증하지 않습니다" }
  ] }
```
(품질검사 탈락 결과는 애초에 포함되지 않음)

### POST /generations/{job_id}/results/{result_id}/select  (auth) → 200 `{ "ok": true }`

## 6. 쇼퍼블 / 이벤트
### GET /results/{id}/shop  (auth)
res 200:
```json
{ "applied_product": {Product},
  "similar_products": [{Product}, {Product}] }   // MODE C
```

### POST /events  (auth)  ← 퍼널 추적
req: `{ "type": "product_click", "session_id": "s_1", "payload": { "product_id": "prod_1", "result_id": "res_1" } }`
type 예: `result_view | result_save | result_share | product_click | purchase_click`
res 202: `{ "ok": true }`

## 7. 내보내기
### POST /results/{id}/export  (auth)
req: `{ "ratio": "4:5", "hi_res": true, "remove_watermark": true }`
res 200: `{ "export_url": "https://…/res_1_export.jpg", "watermark": false }`
(유료/프리미엄 아니면 402 또는 워터마크 포함으로 반환)

## 8. 크레딧
### GET /credits  (auth) → `{ "balance": 30 }`
### POST /credits/purchase  (auth) — 결제는 목
req: `{ "amount": 50 }` → res 200: `{ "balance": 80, "transaction_id": "tx_1" }`

## 9. 신고
### POST /reports  (auth)
req: `{ "target_type": "photo|result", "target_id": "…", "reason": "…" }` → 202 `{ "ok": true }`

---

## 10. SNS 피드 (홈)

### GET /platforms  (auth)
홈 상단 쇼핑몰 스토리바. res 200: `[{ "id": "pt_1", "name": "OTFIT 파트너몰" }]`

### GET /feed  (auth)
`?sort=hot|new&limit=20&cursor=<opaque>` (기본 hot = 투표수·최근성)
res 200:
```json
{ "items": [ {Post} ], "next_cursor": "20" }
```
**Post 객체**
```json
{ "id": "po_1",
  "author": { "id": "u_2", "nickname": "미나" },
  "caption": "여름 바다 갈 때 이거 어때요? 🌊",
  "before_url": null, "after_url": "https://…/result.png",
  "product": {Product} | null,
  "buy_votes": 14, "skip_votes": 3,
  "my_vote": "buy" | "skip" | null,
  "created_at": "…" }
```

### POST /posts  (auth)
req: `{ "result_id": "r_1"?, "product_id": "p_1"?, "caption": "…", "before_url": "…"?, "after_url": "…"? }`
- `result_id`가 있으면 after/product를 결과에서 자동 결정 (본인 결과만 가능, before는 명시할 때만 공개)
- `result_id`가 없으면 `after_url` 필수
res 201: `{Post}`

### POST /posts/{id}/vote  (auth)
req: `{ "choice": "buy" | "skip" }` — 재투표 시 선택 변경, 같은 선택은 멱등.
res 200: `{ "post": {Post}, "reward_credits": 1 }`
- 보상: **타인 게시물 신규 투표**에 한해 하루 3회까지 +1 크레딧 (리텐션 루프)

## 11. 마이페이지

### GET /me/fittings  (auth)
내 피팅 기록 (품질검사 통과 결과만, 최신순). `?limit=20&cursor=<opaque>`
res 200:
```json
{ "items": [
    { "result_id": "res_1", "job_id": "job_1", "result_url": "https://…",
      "style_label": "casual", "product": {Product} | null, "created_at": "…" }
  ], "next_cursor": null }
```

### GET /me/photos  (auth)
내가 업로드한 사진 (삭제된 것 제외, 최신순). `?limit=20&cursor=<opaque>`
res 200: `{ "items": [{ "id","storage_url","width","height","status","uploaded_at" }], "next_cursor": null }`
삭제는 기존 `DELETE /photos/{id}` 사용.

### GET /me/favorites  (auth)
찜한 상품. res 200: `{ "items": [{Product}] }`

### PUT /me/favorites/{product_id}  (auth) → 200 `{ "ok": true }`  (멱등)
### DELETE /me/favorites/{product_id}  (auth) → 204

## 통합 체크리스트 (나중에 붙일 때)
- [ ] 프론트가 쓴 mock 응답 shape == 이 문서 == 백엔드 실제 응답
- [ ] `API_BASE_URL`만 바꿔서 mock↔real 전환되는지
- [ ] JWT refresh 흐름(401→refresh→재요청) 양쪽 확인
- [ ] 생성 폴링: status 전이값(queued→…→done/failed) 문자열 일치
- [ ] 에러 code 문자열 일치 (INSUFFICIENT_CREDITS 등)
- [ ] 이 문서가 백엔드 OpenAPI(`/docs`)와 일치하는지 대조