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
# 파이프라인 계약이 바뀔 때 큐 이름을 올린다 — 구버전 워커(기본 'celery' 큐)가
# 새 잡을 가로채 절반만 처리하는 사고 방지 (멀티 아이템 도입 시 실제 발생).
# api와 worker는 같은 코드 버전으로 함께 배포해야 한다.
celery_app.conf.task_default_queue = "otfit-v2"
# beat 상태 파일은 쓰기 가능한 경로로 (Cloudtype 등 비루트/읽기전용 워킹디렉토리 대응)
celery_app.conf.beat_schedule_filename = "/tmp/celerybeat-schedule"
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
