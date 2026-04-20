from __future__ import annotations

from datetime import date, datetime, time
from typing import Optional

from sqlalchemy import Boolean, Date, DateTime, Integer, SmallInteger, BigInteger, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base
from app.db.enums import RoutingEdgeType, DirectionId, ServiceType, PredictionStatus, PredictionSource


class ServiceDatesBaseView(Base):
    __tablename__ = "v_service_dates_base"

    service_id: Mapped[str] = mapped_column(Text, primary_key=True)
    service_date: Mapped[date] = mapped_column(Date, primary_key=True)


class ServiceDatesActiveView(Base):
    __tablename__ = "v_service_dates_active"

    service_id: Mapped[str] = mapped_column(Text, primary_key=True)
    service_date: Mapped[date] = mapped_column(Date, primary_key=True)


class ActiveTripStopTimesView(Base):
    __tablename__ = "v_active_trip_stop_times"

    service_date: Mapped[date] = mapped_column(Date, primary_key=True)
    trip_id: Mapped[str] = mapped_column(Text, nullable=False)
    line_id: Mapped[str] = mapped_column(Text, nullable=False)
    line_name: Mapped[str] = mapped_column(Text, nullable=False)
    line_code: Mapped[Optional[str]] = mapped_column(Text)
    service_id: Mapped[str] = mapped_column(Text, nullable=False)
    service_name: Mapped[str] = mapped_column(Text, nullable=False)
    service_type: Mapped[ServiceType] = mapped_column(Text, nullable=False)
    direction_id: Mapped[DirectionId] = mapped_column(SmallInteger, nullable=False)
    direction_name: Mapped[Optional[str]] = mapped_column(Text)
    origin_station_id: Mapped[Optional[str]] = mapped_column(Text)
    origin_station_name: Mapped[Optional[str]] = mapped_column(Text)
    destination_station_id: Mapped[Optional[str]] = mapped_column(Text)
    destination_station_name: Mapped[Optional[str]] = mapped_column(Text)
    headsign: Mapped[str] = mapped_column(Text, nullable=False)
    timetable_id: Mapped[int] = mapped_column(primary_key=True)
    station_id: Mapped[str] = mapped_column(Text, nullable=False)
    station_name: Mapped[str] = mapped_column(Text, nullable=False)
    line_station_order: Mapped[int] = mapped_column(Integer, nullable=False)
    stop_sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    scheduled_arrival_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    scheduled_arrival_time: Mapped[time] = mapped_column(nullable=False)
    scheduled_departure_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    scheduled_departure_time: Mapped[time] = mapped_column(nullable=False)
    scheduled_arrival_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    scheduled_departure_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    pickup_allowed: Mapped[bool] = mapped_column(Boolean, nullable=False)
    dropoff_allowed: Mapped[bool] = mapped_column(Boolean, nullable=False)
    is_holiday: Mapped[bool] = mapped_column(Boolean, nullable=False)


class ActiveTripSegmentsView(Base):
    __tablename__ = "v_active_trip_segments"

    service_date: Mapped[date] = mapped_column(Date, primary_key=True)
    trip_id: Mapped[str] = mapped_column(Text, primary_key=True)
    line_id: Mapped[str] = mapped_column(Text, nullable=False)
    line_name: Mapped[str] = mapped_column(Text, nullable=False)
    line_code: Mapped[Optional[str]] = mapped_column(Text)
    service_id: Mapped[str] = mapped_column(Text, nullable=False)
    service_name: Mapped[str] = mapped_column(Text, nullable=False)
    service_type: Mapped[ServiceType] = mapped_column(Text, nullable=False)
    direction_id: Mapped[DirectionId] = mapped_column(SmallInteger, nullable=False)
    direction_name: Mapped[Optional[str]] = mapped_column(Text)
    headsign: Mapped[str] = mapped_column(Text, nullable=False)
    from_timetable_id: Mapped[int] = mapped_column(primary_key=True)
    from_station_id: Mapped[str] = mapped_column(Text, nullable=False)
    from_station_name: Mapped[str] = mapped_column(Text, nullable=False)
    from_line_station_order: Mapped[int] = mapped_column(Integer, nullable=False)
    from_stop_sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    departure_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    to_timetable_id: Mapped[int] = mapped_column(nullable=False)
    to_station_id: Mapped[str] = mapped_column(Text, nullable=False)
    to_station_name: Mapped[str] = mapped_column(Text, nullable=False)
    to_line_station_order: Mapped[int] = mapped_column(Integer, nullable=False)
    to_stop_sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    arrival_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    travel_seconds: Mapped[int] = mapped_column(Integer, nullable=False)


class RoutingEdgesActiveView(Base):
    __tablename__ = "v_routing_edges_active"

    service_date: Mapped[date] = mapped_column(Date)
    edge_type: Mapped[RoutingEdgeType] = mapped_column(Text)

    trip_id: Mapped[Optional[str]] = mapped_column(Text)
    line_id: Mapped[Optional[str]] = mapped_column(Text)
    direction_id: Mapped[Optional[DirectionId]] = mapped_column(SmallInteger)
    direction_name: Mapped[Optional[str]] = mapped_column(Text)
    headsign: Mapped[Optional[str]] = mapped_column(Text)

    from_station_id: Mapped[str] = mapped_column(Text, nullable=False)
    from_station_name: Mapped[str] = mapped_column(Text, nullable=False)
    from_stop_sequence: Mapped[Optional[int]] = mapped_column(Integer)
    departure_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))

    to_station_id: Mapped[str] = mapped_column(Text, nullable=False)
    to_station_name: Mapped[str] = mapped_column(Text, nullable=False)
    to_stop_sequence: Mapped[Optional[int]] = mapped_column(Integer)
    arrival_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))

    travel_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    from_timetable_id: Mapped[Optional[int]] = mapped_column(BigInteger)
    to_timetable_id: Mapped[Optional[int]] = mapped_column(BigInteger)

    __mapper_args__ = {
        "primary_key": [
            service_date,
            edge_type,
            from_timetable_id,
            to_timetable_id,
            from_station_id,
            to_station_id,
            trip_id,
            departure_at,
        ]
    }


class LatestPredictedStopTimesView(Base):
    __tablename__ = "v_latest_predicted_stop_times"

    service_date: Mapped[date] = mapped_column(Date, nullable=False)
    scenario_id: Mapped[Optional[str]] = mapped_column(Text)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True)
    predicted_stop_time_id: Mapped[int] = mapped_column(primary_key=True)
    timetable_id: Mapped[int] = mapped_column(nullable=False)
    trip_id: Mapped[str] = mapped_column(Text, nullable=False)
    line_id: Mapped[str] = mapped_column(Text, nullable=False)
    line_name: Mapped[str] = mapped_column(Text, nullable=False)
    line_code: Mapped[Optional[str]] = mapped_column(Text)
    station_id: Mapped[str] = mapped_column(Text, nullable=False)
    station_name: Mapped[str] = mapped_column(Text, nullable=False)
    line_station_order: Mapped[int] = mapped_column(Integer, nullable=False)
    stop_sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    scheduled_arrival_time: Mapped[time] = mapped_column(nullable=False)
    scheduled_arrival_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    scheduled_departure_time: Mapped[time] = mapped_column(nullable=False)
    scheduled_departure_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    predicted_arrival_time: Mapped[time] = mapped_column(nullable=False)
    predicted_arrival_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    predicted_departure_time: Mapped[time] = mapped_column(nullable=False)
    predicted_departure_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    predicted_arrival_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    predicted_departure_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    delay_min: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[PredictionStatus] = mapped_column(Text, nullable=False)
    prediction_source: Mapped[PredictionSource] = mapped_column(Text, nullable=False)


class StationDepartureBoardView(Base):
    __tablename__ = "v_station_departure_board"

    service_date: Mapped[date] = mapped_column(Date, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True)
    next_departure_id: Mapped[int] = mapped_column(primary_key=True)
    timetable_id: Mapped[int] = mapped_column(nullable=False)
    station_id: Mapped[str] = mapped_column(Text, nullable=False)
    station_name: Mapped[str] = mapped_column(Text, nullable=False)
    line_id: Mapped[str] = mapped_column(Text, nullable=False)
    line_name: Mapped[str] = mapped_column(Text, nullable=False)
    line_code: Mapped[Optional[str]] = mapped_column(Text)
    trip_id: Mapped[str] = mapped_column(Text, nullable=False)
    direction_id: Mapped[Optional[DirectionId]] = mapped_column(SmallInteger)
    direction_label: Mapped[str] = mapped_column(Text, nullable=False)
    line_station_order: Mapped[int] = mapped_column(Integer, nullable=False)
    stop_sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    headsign: Mapped[str] = mapped_column(Text, nullable=False)
    predicted_departure_time: Mapped[time] = mapped_column(nullable=False)
    predicted_departure_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    predicted_departure_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    delay_min: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[PredictionStatus] = mapped_column(Text, nullable=False)
