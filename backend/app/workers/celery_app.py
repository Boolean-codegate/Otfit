from celery import Celery

from app.core.config import get_settings

settings = get_settings()

celery_app = Celery(
    "otfit",
    broker=settings.redis_url,
    backend=settings.redis_url,
    include=["app.workers.tasks.generation_pipeline", "app.workers.tasks.cleanup"],
)
celery_app.conf.task_always_eager = settings.celery_task_always_eager
celery_app.conf.timezone = "UTC"
# 이미지 생성이 3분 이상 걸릴 수 있음 (Responses image_generation 경로)
celery_app.conf.task_time_limit = settings.generation_task_time_limit_seconds
celery_app.conf.task_soft_time_limit = max(60, settings.generation_task_time_limit_seconds - 30)
celery_app.conf.beat_schedule = {
    # 이미지 보관기간(delete_after) 만료 자동 삭제 — 운영 정책 §6
    "cleanup-expired-photos": {
        "task": "app.workers.tasks.cleanup.cleanup_expired_photos",
        "schedule": 3600.0,
    },
}
