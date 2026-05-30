from fastapi import APIRouter, Depends

from app.api.deps import get_db
from app.services.trip_service import TripService
from app.schemas.schedule.trip import (
    TripResponse,
    TripStopResponse,
)


router = APIRouter(
    prefix="/trips",
    tags=["Trips"]
)


@router.get("", response_model=list[TripResponse])
def get_trips(db=Depends(get_db)):
    service = TripService(db)
    return service.get_all()


@router.get("/{trip_id}", response_model=TripResponse)
def get_trip(trip_id: str, db=Depends(get_db)):
    service = TripService(db)
    return service.get_by_id(trip_id)


@router.get("/{trip_id}/stops", response_model=list[TripStopResponse])
def get_trip_stops(trip_id: str, db=Depends(get_db)):
    service = TripService(db)
    return service.get_stops(trip_id)