from __future__ import annotations

from datetime import date, datetime, time
from typing import Any, Optional

from sqlalchemy import BigInteger, Date, DateTime, ForeignKey, ForeignKeyConstraint, Integer, SmallInteger, Text, text
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.enums import PredictionStatus, PredictionSource, RouteRequestResultStatus, DirectionId


class PredictedStopTime(Base):
    __tablename__ = "predicted_stop_times"
    __table_args__ = (
        ForeignKeyConstraint(["trip_id", "line_id"], ["trips.trip_id", "trips.line_id"], onupdate="CASCADE", ondelete="CASCADE", name="predicted_stop_times_trip_fk"),
        ForeignKeyConstraint(
            ["timetable_id", "trip_id", "line_id", "station_id", "line_station_order", "stop_sequence"],
            ["timetable.timetable_id", "timetable.trip_id", "timetable.line_id", "timetable.station_id", "timetable.line_station_order", "timetable.stop_sequence"],
            onupdate="CASCADE",
            ondelete="CASCADE",
            name="predicted_stop_times_timetable_row_fk",
        ),
    )

    predicted_stop_time_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True, nullable=False, server_default=text("now()"))
    service_date: Mapped[date] = mapped_column(Date, nullable=False)
    timetable_id: Mapped[int] = mapped_column(BigInteger, nullable=False)
    trip_id: Mapped[str] = mapped_column(Text, nullable=False)
    line_id: Mapped[str] = mapped_column(Text, nullable=False)
    station_id: Mapped[str] = mapped_column(ForeignKey("stations.station_id", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    line_station_order: Mapped[int] = mapped_column(Integer, nullable=False)
    stop_sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    scheduled_arrival_time: Mapped[time] = mapped_column(nullable=False)
    scheduled_arrival_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default=text("0"))
    scheduled_departure_time: Mapped[time] = mapped_column(nullable=False)
    scheduled_departure_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default=text("0"))
    predicted_arrival_time: Mapped[time] = mapped_column(nullable=False)
    predicted_arrival_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default=text("0"))
    predicted_departure_time: Mapped[time] = mapped_column(nullable=False)
    predicted_departure_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default=text("0"))
    predicted_arrival_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    predicted_departure_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    delay_min: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    status: Mapped[PredictionStatus] = mapped_column(Text, nullable=False, server_default=text("'on_time'"))
    prediction_source: Mapped[PredictionSource] = mapped_column(Text, nullable=False, server_default=text("'simulation_engine'"))
    scenario_id: Mapped[Optional[str]] = mapped_column(ForeignKey("scenarios.scenario_id", onupdate="CASCADE", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    trip: Mapped["Trip"] = relationship(back_populates="predicted_stop_times")
    timetable: Mapped["Timetable"] = relationship(back_populates="predicted_stop_times")
    station: Mapped["Station"] = relationship(back_populates="predicted_stop_times")
    scenario: Mapped[Optional["Scenario"]] = relationship(back_populates="predicted_stop_times")


class NextDeparture(Base):
    __tablename__ = "next_departures"
    __table_args__ = (
        ForeignKeyConstraint(["trip_id", "line_id"], ["trips.trip_id", "trips.line_id"], onupdate="CASCADE", ondelete="CASCADE", name="next_departures_trip_fk"),
        ForeignKeyConstraint(
            ["timetable_id", "trip_id", "line_id", "station_id", "line_station_order", "stop_sequence"],
            ["timetable.timetable_id", "timetable.trip_id", "timetable.line_id", "timetable.station_id", "timetable.line_station_order", "timetable.stop_sequence"],
            onupdate="CASCADE",
            ondelete="CASCADE",
            name="next_departures_timetable_row_fk",
        ),
    )

    next_departure_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True, nullable=False)
    service_date: Mapped[date] = mapped_column(Date, nullable=False)
    station_id: Mapped[str] = mapped_column(ForeignKey("stations.station_id", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    line_id: Mapped[str] = mapped_column(ForeignKey("lines.line_id", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    direction_id: Mapped[Optional[DirectionId]] = mapped_column(SmallInteger)
    direction_label: Mapped[str] = mapped_column(Text, nullable=False)
    trip_id: Mapped[str] = mapped_column(Text, nullable=False)
    timetable_id: Mapped[int] = mapped_column(BigInteger, nullable=False)
    line_station_order: Mapped[int] = mapped_column(Integer, nullable=False)
    stop_sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    headsign: Mapped[str] = mapped_column(Text, nullable=False)
    predicted_departure_time: Mapped[time] = mapped_column(nullable=False)
    predicted_departure_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default=text("0"))
    predicted_departure_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    delay_min: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    status: Mapped[PredictionStatus] = mapped_column(Text, nullable=False, server_default=text("'on_time'"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    station: Mapped["Station"] = relationship(back_populates="next_departures")
    line: Mapped["Line"] = relationship(back_populates="next_departures")
    trip: Mapped["Trip"] = relationship(back_populates="next_departures")
    timetable: Mapped["Timetable"] = relationship(back_populates="next_departures")


class RouteRequestLog(Base):
    __tablename__ = "route_request_logs"

    request_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True, nullable=False, server_default=text("now()"))
    origin_station_id: Mapped[str] = mapped_column(ForeignKey("stations.station_id", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    destination_station_id: Mapped[str] = mapped_column(ForeignKey("stations.station_id", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    departure_time: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    scenario_id: Mapped[Optional[str]] = mapped_column(ForeignKey("scenarios.scenario_id", onupdate="CASCADE", ondelete="SET NULL"))
    algorithm_version: Mapped[str] = mapped_column(Text, nullable=False)
    execution_ms: Mapped[Optional[int]] = mapped_column(Integer)
    result_status: Mapped[RouteRequestResultStatus] = mapped_column(Text, nullable=False)
    result_payload: Mapped[Optional[dict[str, Any]]] = mapped_column(JSONB)

    origin_station: Mapped["Station"] = relationship(back_populates="route_requests_origin", foreign_keys=[origin_station_id])
    destination_station: Mapped["Station"] = relationship(back_populates="route_requests_destination", foreign_keys=[destination_station_id])
    scenario: Mapped[Optional["Scenario"]] = relationship(back_populates="route_request_logs")
