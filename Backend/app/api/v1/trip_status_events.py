from fastapi import APIRouter, Depends

from app.api.deps import get_db
from app.services.trip_status_event_service import TripStatusEventService
from app.schemas.status.trip_status_event import (
    TripStatusEventCreate,
    TripStatusEventUpdate,
    TripStatusEventResponse,
)

router = APIRouter(
    prefix="/trip-status-events",
    tags=["Trip Status Events"]
)


@router.get("", response_model=list[TripStatusEventResponse])
def get_trip_status_events(db=Depends(get_db)):
    service = TripStatusEventService(db)
    return service.get_all()


@router.get("/{event_id}", response_model=TripStatusEventResponse)
def get_trip_status_event(event_id: int, db=Depends(get_db)):
    service = TripStatusEventService(db)
    return service.get_by_id(event_id)


@router.post("", response_model=TripStatusEventResponse)
def create_trip_status_event(
    data: TripStatusEventCreate,
    db=Depends(get_db)
):
    service = TripStatusEventService(db)
    return service.create(data)


@router.patch("/{event_id}", response_model=TripStatusEventResponse)
def update_trip_status_event(
    event_id: int,
    data: TripStatusEventUpdate,
    db=Depends(get_db)
):
    service = TripStatusEventService(db)
    return service.update(event_id, data)


@router.delete("/{event_id}")
def delete_trip_status_event(event_id: int, db=Depends(get_db)):
    service = TripStatusEventService(db)
    return service.delete(event_id)