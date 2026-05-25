from fastapi import APIRouter, Depends
from app.api.deps import get_db
from app.services.station_service import StationService

router = APIRouter(prefix="/stations", tags=["stations"])

@router.get("")
def get_stations(db=Depends(get_db)):
    service = StationService(db)
    return service.get_all_stations()


@router.get("/{station_id}")
def get_station(station_id: str, db=Depends(get_db)):
    service = StationService(db)
    return service.get_station_detail(station_id)