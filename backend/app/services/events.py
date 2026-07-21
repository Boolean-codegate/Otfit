import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Event, Report
from app.repositories.events import EventRepository


class EventService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.events = EventRepository(session)

    async def record(
        self, user_id: uuid.UUID | None, type: str, payload: dict, session_id: str | None = None
    ) -> Event:
        event = await self.events.create_event(
            user_id=user_id, session_id=session_id, type=type, payload=payload
        )
        await self.session.commit()
        return event


class ReportService:
    """신고 접수 스텁: 저장만 하고 후속 처리(검토/제재)는 이후 단계."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.events = EventRepository(session)

    async def create(
        self,
        reporter_id: uuid.UUID,
        target_type: str,
        target_id: uuid.UUID | None,
        reason: str,
        detail: str | None,
    ) -> Report:
        report = await self.events.create_report(
            reporter_id=reporter_id,
            target_type=target_type,
            target_id=target_id,
            reason=reason,
            detail=detail,
        )
        await self.session.commit()
        return report
