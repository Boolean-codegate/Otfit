# 빌드 컨텍스트 = 레포 루트 기준 (Cloudtype: -f backend/Dockerfile . / 로컬 compose: context ..)
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /code

COPY backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ .

EXPOSE 8000

# 기본: API 서버 (마이그레이션 후 기동). compose/Cloudtype worker는 command로 덮어씀
# worker: celery -A app.workers.celery_app worker --beat --loglevel=info
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
