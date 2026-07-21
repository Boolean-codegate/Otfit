from fastapi import APIRouter, status

from app.core.deps import CurrentUser, DbSession
from app.schemas.event import EventCreateRequest, ReportCreateRequest
from app.schemas.generation import OkResponse
from app.services.events import EventService, ReportService

router = APIRouter(tags=["events"])


@router.post("/events", response_model=OkResponse, status_code=status.HTTP_202_ACCEPTED)
async def create_event(body: EventCreateRequest, user: CurrentUser, session: DbSession):
    await EventService(session).record(user.id, body.type, body.payload, body.session_id)
    return {"ok": True}


@router.post("/reports", response_model=OkResponse, status_code=status.HTTP_202_ACCEPTED)
async def create_report(body: ReportCreateRequest, user: CurrentUser, session: DbSession):
    await ReportService(session).create(
        user.id, body.target_type, body.target_id, body.reason, body.detail
    )
    return {"ok": True}
