from fastapi import APIRouter, Depends

from app.api.deps import get_db
from app.services.line_status_event_service import LineStatusEventService
from app.schemas.status.line_status_event import (
    LineStatusEventCreate,
    LineStatusEventUpdate,
    LineStatusEventResponse,
)

router = APIRouter(
    prefix="/line-status-events",
    tags=["Line Status Events"]
)


@router.get("", response_model=list[LineStatusEventResponse])
def get_line_status_events(db=Depends(get_db)):
    service = LineStatusEventService(db)
    return service.get_all()


@router.get("/{event_id}", response_model=LineStatusEventResponse)
def get_line_status_event(event_id: int, db=Depends(get_db)):
    service = LineStatusEventService(db)
    return service.get_by_id(event_id)


@router.post("", response_model=LineStatusEventResponse)
def create_line_status_event(
    data: LineStatusEventCreate,
    db=Depends(get_db)
):
    service = LineStatusEventService(db)
    return service.create(data)


@router.patch("/{event_id}", response_model=LineStatusEventResponse)
def update_line_status_event(
    event_id: int,
    data: LineStatusEventUpdate,
    db=Depends(get_db)
):
    service = LineStatusEventService(db)
    return service.update(event_id, data)


@router.delete("/{event_id}")
def delete_line_status_event(event_id: int, db=Depends(get_db)):
    service = LineStatusEventService(db)
    return service.delete(event_id)