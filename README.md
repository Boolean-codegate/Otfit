# OTFIT — 옷, 나답게, 핏하게.

> **온라인의 모든 옷이 내 피팅룸 안으로. 필요한 건 사진 한 장.**
>
> 사진 한 장으로 실제 판매 중인 옷·하의·신발·액세서리를 조합해 입어보고(AI 피팅),
> 마음에 들면 바로 구매하고, 비포→애프터 변신을 피드에 공유하는 **AI 패션 플랫폼**.

## 🔗 라이브 데모

| | 링크 |
|---|---|
| 🖥 **웹 앱 (모바일/PC)** | https://port-0-otfit-web-m7c8oc297ff7fd19.sel4.cloudtype.app |
| ⚙️ API (Swagger) | https://port-0-otfit-api-m7c8oc297ff7fd19.sel4.cloudtype.app/docs |
| 🎬 **데모 영상** | [demo/OTFIT_DEMO.mp4](demo/OTFIT_DEMO.mp4) |

[![데모 영상 보기](https://img.youtube.com/vi/f_NS_p3AZ7s/maxresdefault.jpg)](https://www.youtube.com/watch?v=f_NS_p3AZ7s)

> 이미지를 클릭하면 YouTube에서 데모 영상을 볼 수 있어요.

## ✨ 핵심 기능

- **한 번에 최대 4개까지 AI 피팅** — 상의, 하의, 신발, 액세서리 중 원하는 아이템만 골라 담아보세요. 얼굴이나 체형, 포즈, 배경, 구도는 그대로 유지하고 옷만 자연스럽게 바꿔드려요. 한 번의 생성으로 전체 코디를 완성할 수 있어요.
- **마음에 들면 바로 쇼핑** — 피팅에 사용한 모든 아이템은 무신사 등 실제 상품 페이지로 연결돼요. 사기 전에 먼저 입어보고, 잘 어울리는 아이템만 골라보세요.
- **비포 ↔ 애프터로 함께 즐기는 피드** — 변신 전후 사진을 올리면 누구나 비포와 애프터를 오가며 볼 수 있어요. ‘살까, 말까’ 투표와 댓글로 의견을 나누고, 마음에 드는 계정을 팔로우해 보세요. 계정 검색과 프로필 소개도 지원해요.
- **완성된 사진은 간편하게 저장** — 모바일에서는 공유 시트를 통해 갤러리에 저장하고, PC에서는 바로 다운로드할 수 있어요.
- **안심하고 이용하는 커뮤니티** — 사진을 올릴 때 나체·성적 콘텐츠, 폭력, 무기, 공포·혐오 요소를 AI가 여러 단계로 확인해요. 게시물과 댓글은 사유를 선택해 신고할 수 있고, 반복적으로 규칙을 어기면 계정 이용이 자동으로 제한돼요. 중요한 신고는 관리자에게 즉시 전달됩니다.
- **내 사진과 개인정보는 안전하게** — 사용자 사진과 피팅 결과는 일정 시간이 지나면 만료되는 보안 링크로만 제공돼요. 업로드할 때 GPS 위치나 기기 정보 같은 EXIF 데이터도 자동으로 삭제합니다. 원한다면 사진을 즉시 지우거나 계정과 관련 데이터를 완전히 삭제할 수 있어요.

## 🧱 아키텍처

```
Flutter Web (모바일·PC 반응형)
   │  REST API — api_contract.md를 단일 계약으로 사용
   ▼
FastAPI ── Celery Worker (버전별 작업 큐)
   │            │
   │            │  AI 피팅 파이프라인
   │            │  분석 → 상품 검색 → 이미지 생성 → 품질 검사
   │            ▼
   │      OpenAI
   │      GPT-5.6 Sol 오케스트레이션 · gpt-image-2 이미지 생성
   │
   │      Segmind IDM-VTON 대체 생성 경로
   │      omni-moderation 유해 콘텐츠 검사
   ▼
Supabase Postgres + pgvector · Upstash Redis · Cloudflare R2
데이터·벡터 검색              작업 큐          이미지 저장소
```

## 📁 레포 구조

| 경로 | 내용 |
|---|---|
| [api_contract.md](api_contract.md) | **단일 API 계약서** — 인증, 사진, AI 피팅, 피드, 신고, 마이페이지 전체 명세 |
| [backend/](backend/) | FastAPI·Celery·pgvector 기반 백엔드와 시드, 마이그레이션, 테스트 |
| [frontend/](frontend/) | 모바일·PC에 대응하는 Flutter 웹 앱 |
| [demo/](demo/) | 주요 기능을 담은 데모 영상 |
| [코드게이트_AI_해커톤_Boolean.pptx](코드게이트_AI_해커톤_Boolean.pptx) | 발표 자료 PPT

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

## 🛡 안전과 신뢰를 위한 장치

| 장치 | 작동 방 |
|---|---|
| 유해 이미지 차단 | 업로드 즉시 omni-moderation과 비전 모델로 검사해 나체·성적 콘텐츠, 폭력, 자해 이미지를 차단해요. 위반이 반복되면 횟수를 기록하고, 3회 누적 시 계정 이용을 제한합니다. |
| 위험 물품·공포 콘텐츠 감지 | 칼이나 총과 같은 무기, 유혈 또는 공포 연출이 감지되면 업로드를 차단하고 그 이유를 한글로 안내해요. |
| 게시물·댓글 신고 | 부적절한 콘텐츠, 스팸, 저작권 침해 등의 사유로 신고할 수 있어요. 필요한 경우 사유를 직접 입력할 수 있으며, 접수된 신고는 관리자에게 즉시 전달됩니다. |
| 결과 품질 검사 | 생성 결과의 인물 유사도와 이미지 품질을 자동으로 확인하고 점수를 기록해요. 기준을 충족하지 못하면 사용한 크레딧을 자동으로 돌려드립니다. |

## 👥 Team Boolean-codegate

CODEGATE 2026 해커톤 출품작
