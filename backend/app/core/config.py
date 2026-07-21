from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Otfit"
    base_url: str = "http://localhost:8000"
    # Flutter 웹 로컬 개발 서버(포트 임의)를 허용 — 배포 시 실제 도메인 정규식으로 교체
    cors_allow_origin_regex: str = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
    secret_key: str = "change-me-in-production"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 14

    # 소셜 로그인 — 설정 시 구글 id_token의 aud를 검증 (카카오는 서버 키 불필요)
    google_client_id: str = ""

    database_url: str = "postgresql+asyncpg://otfit:otfit@localhost:5432/otfit"
    sync_database_url: str = "postgresql+psycopg2://otfit:otfit@localhost:5432/otfit"
    redis_url: str = "redis://localhost:6379/0"
    celery_task_always_eager: bool = False

    storage_backend: str = "local"
    storage_dir: str = "/data/media"

    provider_mode: str = "mock"  # mock | live
    openai_api_key: str = ""
    vision_model: str = "gpt-5.6-sol"  # 분석·판단(두뇌): 텍스트+이미지 → structured output
    image_model: str = "gpt-image-1"  # 픽셀 생성(손): 마스크 인페인팅
    embedding_model: str = "text-embedding-3-small"

    signup_bonus_credits: int = 10
    generation_cost_credits: int = 1
    photo_retention_days: int = 30
    embedding_dim: int = 512

    # 입력 검증 (MVP 범위)
    min_photo_short_side: int = 512
    max_occlusion_score: float = 0.4
    allowed_poses: tuple[str, ...] = ("front", "three_quarter")
    quality_score_threshold: float = 0.6
    face_similarity_threshold: float = 0.85  # 정체성 보존 판정 (live 품질검사)
    generation_max_retries: int = 2  # 품질 미달 시 재생성 횟수

    disclaimer: str = "본 이미지는 스타일링 시각화이며 실제 핏·사이즈를 보증하지 않습니다."


@lru_cache
def get_settings() -> Settings:
    return Settings()
