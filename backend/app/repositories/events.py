import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.models import Event, Report


class EventRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def create_event(
        self,
        *,
        user_id: uuid.UUID | None,
        session_id: str | None,
        type: str,
        payload: dict,
    ) -> Event:
        event = Event(user_id=user_id, session_id=session_id, type=type, payload=payload)
        self.session.add(event)
        await self.session.flush()
        return event

    async def create_report(self, **kwargs) -> Report:
        report = Report(**kwargs)
        self.session.add(report)
        await self.session.flush()
        return report
