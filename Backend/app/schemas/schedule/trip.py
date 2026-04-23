from datetime import date, datetime, time

from pydantic import BaseModel, ConfigDict


class TripResponse(BaseModel):
    trip_id: str
    line_id: str
    service_id: str
    direction_id: int
    direction_name: str | None = None
    origin_station_id: str | None = None
    destination_station_id: str | None = None
    headsign: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TripStopResponse(BaseModel):
    timetable_id: int
    trip_id: str
    line_id: str
    station_id: str
    line_station_order: int
    stop_sequence: int
    scheduled_arrival_time: time
    scheduled_arrival_day_offset: int
    scheduled_departure_time: time
    scheduled_departure_day_offset: int
    pickup_allowed: bool
    dropoff_allowed: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TripStopByServiceDateResponse(BaseModel):
    service_date: date
    trip_id: str
    line_id: str
    line_name: str
    line_code: str | None = None
    service_id: str
    service_name: str
    service_type: str
    direction_id: int
    direction_name: str | None = None
    origin_station_id: str | None = None
    origin_station_name: str | None = None
    destination_station_id: str | None = None
    destination_station_name: str | None = None
    headsign: str
    timetable_id: int
    station_id: str
    station_name: str
    line_station_order: int
    stop_sequence: int
    scheduled_arrival_day_offset: int
    scheduled_arrival_time: time
    scheduled_departure_day_offset: int
    scheduled_departure_time: time
    scheduled_arrival_at: datetime
    scheduled_departure_at: datetime
    pickup_allowed: bool
    dropoff_allowed: bool
    is_holiday: bool

    model_config = ConfigDict(from_attributes=True)
