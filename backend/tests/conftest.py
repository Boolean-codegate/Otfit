"""통합 테스트 설정.

- 앱 import 전에 환경변수를 테스트용으로 고정 (mock provider, eager celery, 테스트 DB)
- 테스트 DB(otfit_test)를 만들고 스키마 생성 + 시드 후, 끝나면 드랍
- compose의 postgres 컨테이너를 그대로 사용: docker-compose exec api pytest
"""
import asyncio
import os
import tempfile

from sqlalchemy.engine import make_url

# 어떤 환경(.env 주입 포함)에서 실행돼도 반드시 "<원래DB>_test" 파생 DB만 사용한다.
_BASE_ASYNC = os.environ.get("DATABASE_URL", "postgresql+asyncpg://otfit:otfit@postgres:5432/otfit")
_BASE_SYNC = os.environ.get("SYNC_DATABASE_URL", "postgresql+psycopg2://otfit:otfit@postgres:5432/otfit")
_ADMIN_DB = make_url(_BASE_SYNC).database  # 생성/드랍 명령을 실행할 기존 DB
_TEST_DB = f"{_ADMIN_DB}_test"

os.environ["DATABASE_URL"] = make_url(_BASE_ASYNC).set(database=_TEST_DB).render_as_string(hide_password=False)
os.environ["SYNC_DATABASE_URL"] = make_url(_BASE_SYNC).set(database=_TEST_DB).render_as_string(hide_password=False)
os.environ["CELERY_TASK_ALWAYS_EAGER"] = "true"
os.environ["PROVIDER_MODE"] = "mock"
os.environ["STORAGE_BACKEND"] = "local"  # 테스트는 외부(R2) 의존 없이 로컬 스토리지 고정
os.environ["STORAGE_DIR"] = tempfile.mkdtemp(prefix="otfit-test-media-")

import pytest
from sqlalchemy import create_engine, text

from app.models import Base  # noqa: E402  (env 설정 후 import)


def _admin_url():
    """테스트 DB 생성/드랍용 — 같은 서버의 기존 DB로 접속."""
    url = make_url(os.environ["SYNC_DATABASE_URL"])
    return url.set(database=_ADMIN_DB), _TEST_DB


@pytest.fixture(scope="session")
def database():
    admin_url, test_db = _admin_url()
    admin = create_engine(admin_url, isolation_level="AUTOCOMMIT")
    with admin.connect() as conn:
        conn.execute(text(f'DROP DATABASE IF EXISTS "{test_db}"'))
        conn.execute(text(f'CREATE DATABASE "{test_db}"'))

    engine = create_engine(os.environ["SYNC_DATABASE_URL"])
    with engine.begin() as conn:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
        Base.metadata.create_all(conn)
    engine.dispose()

    from seeds.seed import seed

    asyncio.run(seed())

    yield test_db

    with admin.connect() as conn:
        conn.execute(text(f'DROP DATABASE IF EXISTS "{test_db}" WITH (FORCE)'))
    admin.dispose()


@pytest.fixture()
async def client(database):
    from httpx import ASGITransport, AsyncClient

    from app.main import app

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
