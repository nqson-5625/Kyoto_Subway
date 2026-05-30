from datetime import datetime, time
from pydantic import BaseModel, ConfigDict


class TripResponse(BaseModel):
    trip_id: str
    line_id: str
    service_id: str | None = None
    direction_id: int | None = None
    headsign: str | None = None
    is_active: bool | None = True
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)


class TripStopResponse(BaseModel):
    timetable_id: int
    trip_id: str
    station_id: str
    line_id: str | None = None
    line_station_order: int | None = None
    stop_sequence: int

    arrival_time: time | None = None
    arrival_day_offset: int | None = 0
    departure_time: time | None = None
    departure_day_offset: int | None = 0

    model_config = ConfigDict(from_attributes=True)