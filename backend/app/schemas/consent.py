import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel

from app.schemas.common import ORMModel

ConsentType = Literal["image_processing", "marketing", "reuse"]


class ConsentUpsertRequest(BaseModel):
    type: ConsentType
    granted: bool


class ConsentOut(ORMModel):
    id: uuid.UUID
    type: str
    granted: bool
    granted_at: datetime | None


class ConsentListResponse(BaseModel):
    items: list[ConsentOut]
