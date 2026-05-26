from fastapi import APIRouter, Depends

from app.api.deps import get_db
from app.services.station_status_event_service import StationStatusEventService
from app.schemas.status.station_status_event import (
    StationStatusEventCreate,
    StationStatusEventUpdate,
    StationStatusEventResponse,
)

router = APIRouter(
    prefix="/station-status-events",
    tags=["Station Status Events"]
)


@router.get("", response_model=list[StationStatusEventResponse])
def get_station_status_events(db=Depends(get_db)):
    service = StationStatusEventService(db)
    return service.get_all()


@router.get("/{event_id}", response_model=StationStatusEventResponse)
def get_station_status_event(event_id: int, db=Depends(get_db)):
    service = StationStatusEventService(db)
    return service.get_by_id(event_id)


@router.post("", response_model=StationStatusEventResponse)
def create_station_status_event(
    data: StationStatusEventCreate,
    db=Depends(get_db)
):
    service = StationStatusEventService(db)
    return service.create(data)


@router.patch("/{event_id}", response_model=StationStatusEventResponse)
def update_station_status_event(
    event_id: int,
    data: StationStatusEventUpdate,
    db=Depends(get_db)
):
    service = StationStatusEventService(db)
    return service.update(event_id, data)


@router.delete("/{event_id}")
def delete_station_status_event(event_id: int, db=Depends(get_db)):
    service = StationStatusEventService(db)
    return service.delete(event_id)