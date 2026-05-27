from datetime import date, datetime, time

from pydantic import BaseModel, ConfigDict


class NextDepartureBase(BaseModel):
    service_date: date
    station_id: str
    line_id: str

    direction_id: int | None = None
    direction_label: str

    trip_id: str
    timetable_id: int
    line_station_order: int
    stop_sequence: int

    headsign: str

    predicted_departure_time: time
    predicted_departure_day_offset: int = 0
    predicted_departure_at: datetime | None = None

    delay_min: int = 0
    status: str = "on_time"


class NextDepartureCreate(NextDepartureBase):
    updated_at: datetime | None = None


class NextDepartureUpdate(BaseModel):
    service_date: date | None = None
    station_id: str | None = None
    line_id: str | None = None

    direction_id: int | None = None
    direction_label: str | None = None

    trip_id: str | None = None
    timetable_id: int | None = None
    line_station_order: int | None = None
    stop_sequence: int | None = None

    headsign: str | None = None

    predicted_departure_time: time | None = None
    predicted_departure_day_offset: int | None = None
    predicted_departure_at: datetime | None = None

    delay_min: int | None = None
    status: str | None = None


class NextDepartureResponse(NextDepartureBase):
    next_departure_id: int
    updated_at: datetime
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)