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

    database_url: str = "postgresql+asyncpg://otfit:otfit@localhost:5432/otfit"
    sync_database_url: str = "postgresql+psycopg2://otfit:otfit@localhost:5432/otfit"
    redis_url: str = "redis://localhost:6379/0"
    celery_task_always_eager: bool = False

    storage_backend: str = "local"  # local | s3
    storage_dir: str = "/data/media"

    # S3 호환 스토리지 (Cloudflare R2 등) — live 모드에서 Segmind이 가져갈
    # 공개(presigned) URL 생성에 필요
    s3_endpoint: str = ""
    s3_access_key: str = ""
    s3_secret_key: str = ""
    s3_bucket: str = ""
    s3_region: str = "auto"
    s3_public_base_url: str = ""  # 공개 버킷 도메인 (없으면 presigned URL 사용)

    provider_mode: str = "mock"  # mock | live (전역 기본값)
    # 컴포넌트별 오버라이드: mock | live. 비우면 provider_mode를 따른다.
    # 예) 분석·추천은 mock, 생성만 Segmind 실호출(하이브리드 데모):
    #     VISION_PROVIDER=mock EMBEDDING_PROVIDER=mock GENERATION_PROVIDER=live
    vision_provider: str = ""
    embedding_provider: str = ""
    generation_provider: str = ""
    # 의상 교체 생성: Segmind IDM-VTON (live)
    segmind_api_key: str = ""
    segmind_api_url: str = "https://api.segmind.com/v1/idm-vton"
    segmind_timeout_seconds: float = 30.0
    segmind_steps: int = 30
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

    def resolved_provider(self, component: str) -> str:
        """컴포넌트별 프로바이더 모드: 오버라이드가 있으면 우선, 없으면 provider_mode."""
        override = {
            "vision": self.vision_provider,
            "embedding": self.embedding_provider,
            "generation": self.generation_provider,
        }[component].strip().lower()
        return override or self.provider_mode


@lru_cache
def get_settings() -> Settings:
    return Settings()
