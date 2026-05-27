from fastapi import APIRouter, Depends

from app.api.deps import get_db
from app.services.edge_status_event_service import EdgeStatusEventService
from app.schemas.status.edge_status_event import (
    EdgeStatusEventCreate,
    EdgeStatusEventUpdate,
    EdgeStatusEventResponse,
)

router = APIRouter(
    prefix="/edge-status-events",
    tags=["Edge Status Events"]
)


@router.get("", response_model=list[EdgeStatusEventResponse])
def get_edge_status_events(db=Depends(get_db)):
    service = EdgeStatusEventService(db)
    return service.get_all()


@router.get("/{event_id}", response_model=EdgeStatusEventResponse)
def get_edge_status_event(event_id: int, db=Depends(get_db)):
    service = EdgeStatusEventService(db)
    return service.get_by_id(event_id)


@router.post("", response_model=EdgeStatusEventResponse)
def create_edge_status_event(
    data: EdgeStatusEventCreate,
    db=Depends(get_db)
):
    service = EdgeStatusEventService(db)
    return service.create(data)


@router.patch("/{event_id}", response_model=EdgeStatusEventResponse)
def update_edge_status_event(
    event_id: int,
    data: EdgeStatusEventUpdate,
    db=Depends(get_db)
):
    service = EdgeStatusEventService(db)
    return service.update(event_id, data)


@router.delete("/{event_id}")
def delete_edge_status_event(event_id: int, db=Depends(get_db)):
    service = EdgeStatusEventService(db)
    return service.delete(event_id)