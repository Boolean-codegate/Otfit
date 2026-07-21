"""이미지 저장 추상화 — local | s3(R2 호환).

live 생성(Segmind IDM-VTON)은 사용자 사진을 "공개 접근 가능한 URL"로 요구하므로,
S3Storage.presigned_url()로 유효기간이 있는 임시 URL을 만들어 넘긴다.
"""
from abc import ABC, abstractmethod
from functools import lru_cache
from pathlib import Path

from app.core.config import get_settings


class StorageService(ABC):
    @abstractmethod
    def save(self, key: str, data: bytes) -> str: ...

    @abstractmethod
    def load(self, key: str) -> bytes: ...

    @abstractmethod
    def delete(self, key: str) -> None: ...

    @abstractmethod
    def url_for(self, key: str) -> str: ...

    @abstractmethod
    def presigned_url(self, key: str, expires_seconds: int = 3600) -> str:
        """외부 서비스가 직접 가져갈 수 있는 임시(또는 공개) URL."""

    @abstractmethod
    def exists(self, key: str) -> bool: ...


class LocalStorage(StorageService):
    def __init__(self, root: str, base_url: str):
        self.root = Path(root)
        self.base_url = base_url.rstrip("/")

    def _path(self, key: str) -> Path:
        path = (self.root / key).resolve()
        if not str(path).startswith(str(self.root.resolve())):
            raise ValueError(f"invalid storage key: {key}")
        return path

    def save(self, key: str, data: bytes) -> str:
        path = self._path(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return key

    def load(self, key: str) -> bytes:
        return self._path(key).read_bytes()

    def delete(self, key: str) -> None:
        path = self._path(key)
        if path.exists():
            path.unlink()

    def url_for(self, key: str) -> str:
        return f"{self.base_url}/media/{key}"

    def presigned_url(self, key: str, expires_seconds: int = 3600) -> str:
        # 로컬 스토리지는 BASE_URL이 외부에서 접근 가능할 때만 유효 (개발용)
        return self.url_for(key)

    def exists(self, key: str) -> bool:
        return self._path(key).exists()


class S3Storage(StorageService):
    """S3 호환 스토리지 (Cloudflare R2 검증)."""

    def __init__(
        self,
        *,
        endpoint: str,
        access_key: str,
        secret_key: str,
        bucket: str,
        region: str = "auto",
        public_base_url: str = "",
    ):
        import boto3
        from botocore.config import Config

        self.bucket = bucket
        self.public_base_url = public_base_url.rstrip("/")
        self.client = boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            region_name=region,
            config=Config(signature_version="s3v4"),
        )

    @staticmethod
    def _content_type(key: str) -> str:
        suffix = key.rsplit(".", 1)[-1].lower()
        return {
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
            "webp": "image/webp",
            "bmp": "image/bmp",
        }.get(suffix, "application/octet-stream")

    def save(self, key: str, data: bytes) -> str:
        self.client.put_object(
            Bucket=self.bucket, Key=key, Body=data, ContentType=self._content_type(key)
        )
        return key

    def load(self, key: str) -> bytes:
        response = self.client.get_object(Bucket=self.bucket, Key=key)
        return response["Body"].read()

    def delete(self, key: str) -> None:
        self.client.delete_object(Bucket=self.bucket, Key=key)

    def url_for(self, key: str) -> str:
        if self.public_base_url:
            return f"{self.public_base_url}/{key}"
        # 공개 도메인이 없으면 24시간 presigned URL로 대체
        return self.presigned_url(key, expires_seconds=86400)

    def presigned_url(self, key: str, expires_seconds: int = 3600) -> str:
        return self.client.generate_presigned_url(
            "get_object",
            Params={"Bucket": self.bucket, "Key": key},
            ExpiresIn=expires_seconds,
        )

    def exists(self, key: str) -> bool:
        from botocore.exceptions import ClientError

        try:
            self.client.head_object(Bucket=self.bucket, Key=key)
            return True
        except ClientError:
            return False


def build_s3_storage() -> S3Storage:
    """설정된 S3(R2) 자격증명으로 S3Storage 생성. 미설정이면 RuntimeError."""
    settings = get_settings()
    if not (settings.s3_endpoint and settings.s3_access_key and settings.s3_secret_key and settings.s3_bucket):
        raise RuntimeError(
            "S3 설정이 없습니다 (S3_ENDPOINT/S3_ACCESS_KEY/S3_SECRET_KEY/S3_BUCKET). "
            "live 생성은 사용자 사진의 공개 URL이 필요합니다."
        )
    return S3Storage(
        endpoint=settings.s3_endpoint,
        access_key=settings.s3_access_key,
        secret_key=settings.s3_secret_key,
        bucket=settings.s3_bucket,
        region=settings.s3_region,
        public_base_url=settings.r2_public_url,
    )


@lru_cache
def get_storage() -> StorageService:
    settings = get_settings()
    if settings.storage_backend == "s3":
        return build_s3_storage()
    return LocalStorage(settings.storage_dir, settings.base_url)
