"""관리자 알림 — 모더레이션 적발 등 운영 이벤트를 웹훅으로 전달.

ADMIN_ALERT_WEBHOOK(디스코드/슬랙 인커밍 웹훅 URL)이 설정되면 POST로 전송하고,
없으면 서버 로그(warning)로만 남긴다. 알림 실패가 본 요청을 깨뜨리지 않도록
예외는 항상 삼킨다.
"""
import logging

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)


async def notify_admin(text: str) -> None:
    url = get_settings().admin_alert_webhook
    logger.warning("[관리자 알림] %s", text)
    if not url:
        return
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            # Discord는 content, Slack은 text 필드를 읽는다 — 둘 다 실어 호환
            await client.post(url, json={"content": text, "text": text})
    except Exception:  # noqa: BLE001 — 알림 실패는 업로드 흐름에 영향 없음
        logger.exception("관리자 알림 웹훅 전송 실패")
