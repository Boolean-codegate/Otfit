# Otfit — AI 쇼퍼블 패션 리터칭 플랫폼

사진을 업로드하면 AI가 사진 분위기에 어울리는 실제 판매 상품을 추천해 옷만 자연스럽게 교체하고,
바로 구매로 연결되는 쇼퍼블 사진 보정 앱.

## 레포 구조

| 경로 | 내용 |
|---|---|
| [api_contract.md](api_contract.md) | **백엔드 ↔ 프론트 API 계약 (유일한 소스)** |
| [backend/](backend/) | FastAPI + PostgreSQL(pgvector) + Celery 백엔드 — 실행법은 [backend/README.md](backend/README.md) |
| [frontend/](frontend/) | Flutter 앱 (별도 개발 후 통합 예정) |

## 백엔드 빠른 시작

```bash
cd backend
cp .env.example .env
docker-compose up -d --build
docker-compose exec api alembic upgrade head
docker-compose exec api python -m seeds.seed
# Swagger: http://localhost:8000/docs
```
