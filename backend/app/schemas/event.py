import uuid
from typing import Literal

from pydantic import BaseModel

EventType = Literal["result_view", "result_save", "result_share", "product_click", "purchase_click"]


class EventCreateRequest(BaseModel):
    type: EventType
    session_id: str | None = None
    payload: dict = {}


class ReportCreateRequest(BaseModel):
    target_type: Literal["photo", "result", "post", "comment"]
    target_id: uuid.UUID
    # 사유: inappropriate | spam | copyright | other (프론트 선택지)
    reason: str
    # '기타' 선택 시 직접 입력한 상세 사유
    detail: str | None = None
