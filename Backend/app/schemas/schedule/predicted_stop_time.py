from datetime import date, datetime, time

from pydantic import BaseModel, ConfigDict


class PredictedStopTimeBase(BaseModel):
    service_date: date
    timetable_id: int
    trip_id: str
    line_id: str
    station_id: str
    line_station_order: int
    stop_sequence: int

    scheduled_arrival_time: time
    scheduled_arrival_day_offset: int = 0
    scheduled_departure_time: time
    scheduled_departure_day_offset: int = 0

    predicted_arrival_time: time
    predicted_arrival_day_offset: int = 0
    predicted_departure_time: time
    predicted_departure_day_offset: int = 0

    predicted_arrival_at: datetime | None = None
    predicted_departure_at: datetime | None = None

    delay_min: int = 0
    status: str = "on_time"
    prediction_source: str = "simulation_engine"
    scenario_id: str | None = None


class PredictedStopTimeCreate(PredictedStopTimeBase):
    updated_at: datetime | None = None


class PredictedStopTimeUpdate(BaseModel):
    service_date: date | None = None
    timetable_id: int | None = None
    trip_id: str | None = None
    line_id: str | None = None
    station_id: str | None = None
    line_station_order: int | None = None
    stop_sequence: int | None = None

    scheduled_arrival_time: time | None = None
    scheduled_arrival_day_offset: int | None = None
    scheduled_departure_time: time | None = None
    scheduled_departure_day_offset: int | None = None

    predicted_arrival_time: time | None = None
    predicted_arrival_day_offset: int | None = None
    predicted_departure_time: time | None = None
    predicted_departure_day_offset: int | None = None

    predicted_arrival_at: datetime | None = None
    predicted_departure_at: datetime | None = None

    delay_min: int | None = None
    status: str | None = None
    prediction_source: str | None = None
    scenario_id: str | None = None


class PredictedStopTimeResponse(PredictedStopTimeBase):
    predicted_stop_time_id: int
    updated_at: datetime
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)