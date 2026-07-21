import uuid
from typing import Literal

from pydantic import BaseModel

EventType = Literal["result_view", "result_save", "result_share", "product_click", "purchase_click"]


class EventCreateRequest(BaseModel):
    type: EventType
    session_id: str | None = None
    payload: dict = {}


class ReportCreateRequest(BaseModel):
    target_type: Literal["photo", "result"]
    target_id: uuid.UUID
    reason: str
