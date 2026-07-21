# OTFIT — 옷, 나답게, 핏하게.

> **온라인의 모든 옷이 내 피팅룸 안으로. 필요한 건 사진 한 장.**
>
> 사진 한 장으로 실제 판매 중인 옷·하의·신발·액세서리를 조합해 입어보고(AI 피팅),
> 마음에 들면 바로 구매하고, 비포→애프터 변신을 피드에 공유하는 **AI 쇼퍼블 패션 플랫폼**.

## 🔗 라이브 데모

| | 링크 |
|---|---|
| 🖥 **웹 앱 (모바일/PC)** | https://port-0-otfit-web-m7c8oc297ff7fd19.sel4.cloudtype.app |
| ⚙️ API (Swagger) | https://port-0-otfit-api-m7c8oc297ff7fd19.sel4.cloudtype.app/docs |
| 🎬 **데모 영상** | [demo/OTFIT_DEMO.mp4](demo/OTFIT_DEMO.mp4) |

## ✨ 핵심 기능

- **멀티 아이템 AI 피팅** — 옷/하의/신발/액세서리 슬롯에 원하는 것만 담아 최대 4개를 **한 번에** 피팅.
  얼굴·체형·포즈·배경·구도는 원본 그대로, 옷만 바뀝니다 (GPT-5.6 Sol + gpt-image-2, 한 번의 생성 콜).
- **쇼퍼블** — 피팅 결과의 모든 아이템이 무신사 등 **실제 상품 페이지**로 연결. 사기 전에 입어보세요.
- **비포 → 애프터 피드** — 변신을 게시하면 누구나 비포↔애프터를 전환하며 구경하고,
  살까/말까 투표와 댓글로 반응. 팔로우/팔로워, 계정 검색, 프로필(소개글)까지.
- **사진 저장** — 모바일은 공유 시트로 갤러리에, PC는 다운로드 폴더로.
- **안전한 커뮤니티** — 업로드 시 AI 모더레이션 3중 필터(나체·성적·폭력 / 무기 / 공포·혐오),
  반복 위반 자동 계정 제한, 게시물·댓글 신고(사유 선택), 관리자 웹훅 알림.
- **프라이버시** — 사용자 사진·결과는 만료되는 presigned URL로만 서빙(공개 URL은 상품 카탈로그만),
  업로드 시 EXIF(GPS·기기정보) 자동 제거, 사진 즉시 삭제·계정 완전 삭제(GDPR) 지원.

## 🧱 아키텍처

```
Flutter Web (모바일/PC 반응형)
   │  REST (api_contract.md — 단일 계약)
   ▼
FastAPI ── Celery Worker (버전링된 큐)
   │            │  AI 생성 파이프라인: 분석 → 검색 → 생성 → 품질검사
   │            ▼
   │      OpenAI (GPT-5.6 Sol 오케스트레이션 + gpt-image-2 이미지 생성)
   │      Segmind IDM-VTON (대체 생성 경로) · omni-moderation (유해 콘텐츠)
   ▼
Supabase Postgres(pgvector) · Upstash Redis(큐) · Cloudflare R2(이미지)
```

- **계약 우선 개발**: [api_contract.md](api_contract.md)가 백엔드↔프론트의 유일한 소스.
- **프로바이더 추상화**: vision/embedding/generation/moderation을 컴포넌트별로 mock ↔ live 전환
  (`PROVIDER_MODE` + `*_PROVIDER` env) — API 키 없이도 전체 플로우가 동작합니다.

## 📁 레포 구조

| 경로 | 내용 |
|---|---|
| [api_contract.md](api_contract.md) | **API 계약 (유일한 소스)** — 인증/사진/생성/피드/신고/마이페이지 전 명세 |
| [backend/](backend/) | FastAPI + Celery + pgvector 백엔드, 시드/마이그레이션/테스트 |
| [frontend/](frontend/) | Flutter 웹 앱 (모바일·PC 반응형) |
| [demo/](demo/) | 데모 영상 |

## 🚀 로컬 실행

### 백엔드

```bash
cd backend
cp .env.example .env        # 키 없이 mock 모드로 전체 동작. live는 OPENAI_API_KEY 등 설정
docker-compose up -d --build
docker-compose exec api python -m seeds.seed     # 카탈로그 + 테스트 계정
# Swagger: http://localhost:8000/docs
```

### 프론트엔드

```bash
cd frontend
flutter pub get
flutter run -d web-server --web-port=8080 --dart-define=API_BASE_URL=http://localhost:8000
# http://localhost:8080  (API_BASE_URL 생략 시 mock 데이터로 단독 실행)
```

테스트 계정: `test@otfit.app` / `test1234`

## 🛡 안전 · 신뢰 장치

| 장치 | 동작 |
|---|---|
| 유해 이미지 차단 | 업로드 즉시 omni-moderation + 비전 스캔 — 나체·성적·폭력·자해는 차단 + 스트라이크, 3회 누적 시 계정 제한 |
| 위험 물품 / 공포·혐오 | 칼·총 등 무기, 호러·유혈 연출 감지 시 차단·경고 (사유를 한글로 안내) |
| 신고 | 게시물·댓글 신고 (부적절/스팸/저작권/기타 직접 입력) → 신고함 접수 + 관리자 웹훅 알림 |
| 품질 게이트 | 생성 결과의 인물 동일성·품질 점수 기록, 실패 시 크레딧 자동 환불 |

## 👥 Team Boolean-codegate

2026 해커톤 출품작입니다.
