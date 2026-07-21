FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /code

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

# 기본: API 서버 (마이그레이션 후 기동). compose/Cloudtype에서 command로 덮어쓸 수 있음
# worker는: celery -A app.workers.celery_app worker --beat --loglevel=info
CMD ["sh", "-c", "alembic upgrade head && uvicorn app.main:app --host 0.0.0.0 --port 8000"]
