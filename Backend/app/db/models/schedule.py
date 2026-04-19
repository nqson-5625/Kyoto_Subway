from __future__ import annotations

from datetime import date, datetime, time
from typing import Optional

from sqlalchemy import BigInteger, Boolean, Date, DateTime, ForeignKey, ForeignKeyConstraint, Integer, SmallInteger, Text, UniqueConstraint, and_, text
from sqlalchemy.orm import Mapped, foreign, mapped_column, relationship

from app.db.base import Base


class ServiceCalendar(Base):
    __tablename__ = "service_calendar"

    service_id: Mapped[str] = mapped_column(Text, primary_key=True)
    service_name: Mapped[str] = mapped_column(Text, nullable=False)
    service_type: Mapped[str] = mapped_column(Text, nullable=False)
    monday: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("FALSE"))
    tuesday: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("FALSE"))
    wednesday: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("FALSE"))
    thursday: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("FALSE"))
    friday: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("FALSE"))
    saturday: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("FALSE"))
    sunday: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("FALSE"))
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    service_exceptions: Mapped[list["ServiceException"]] = relationship(back_populates="service", cascade="all, delete-orphan")
    trips: Mapped[list["Trip"]] = relationship(back_populates="service")


class HolidayDate(Base):
    __tablename__ = "holiday_dates"

    holiday_date: Mapped[date] = mapped_column(Date, primary_key=True)
    holiday_name: Mapped[str] = mapped_column(Text, nullable=False)
    is_public_holiday: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))
    note: Mapped[Optional[str]] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))


class ServiceException(Base):
    __tablename__ = "service_exceptions"
    __table_args__ = (UniqueConstraint("service_id", "service_date", name="service_exceptions_unique"),)

    service_exception_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    service_id: Mapped[str] = mapped_column(ForeignKey("service_calendar.service_id", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    service_date: Mapped[date] = mapped_column(Date, nullable=False)
    exception_type: Mapped[str] = mapped_column(Text, nullable=False)
    exception_category: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("'special_operation'"))
    reason: Mapped[Optional[str]] = mapped_column(Text)
    note: Mapped[Optional[str]] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    service: Mapped["ServiceCalendar"] = relationship(back_populates="service_exceptions")


class Trip(Base):
    __tablename__ = "trips"
    __table_args__ = (
        ForeignKeyConstraint(["origin_station_id", "line_id"], ["station_lines.station_id", "station_lines.line_id"], onupdate="CASCADE", ondelete="RESTRICT", name="trips_origin_station_line_fk"),
        ForeignKeyConstraint(["destination_station_id", "line_id"], ["station_lines.station_id", "station_lines.line_id"], onupdate="CASCADE", ondelete="RESTRICT", name="trips_destination_station_line_fk"),
        UniqueConstraint("trip_id", "line_id", name="trips_trip_line_unique"),
    )

    trip_id: Mapped[str] = mapped_column(Text, primary_key=True)
    line_id: Mapped[str] = mapped_column(ForeignKey("lines.line_id", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    service_id: Mapped[str] = mapped_column(ForeignKey("service_calendar.service_id", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    direction_id: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    direction_name: Mapped[Optional[str]] = mapped_column(Text)
    origin_station_id: Mapped[Optional[str]] = mapped_column(ForeignKey("stations.station_id", onupdate="CASCADE", ondelete="RESTRICT"))
    destination_station_id: Mapped[Optional[str]] = mapped_column(ForeignKey("stations.station_id", onupdate="CASCADE", ondelete="RESTRICT"))
    headsign: Mapped[str] = mapped_column(Text, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    line: Mapped["Line"] = relationship(back_populates="trips")
    service: Mapped["ServiceCalendar"] = relationship(back_populates="trips")
    origin_station: Mapped[Optional["Station"]] = relationship(back_populates="origin_trips", foreign_keys=[origin_station_id])
    destination_station: Mapped[Optional["Station"]] = relationship(back_populates="destination_trips", foreign_keys=[destination_station_id])
    origin_station_line: Mapped[Optional["StationLine"]] = relationship(
        back_populates="origin_trips",
        primaryjoin=lambda: and_(
            foreign(Trip.origin_station_id) == StationLine.station_id,
            foreign(Trip.line_id) == StationLine.line_id,
        ),
        foreign_keys=lambda: [Trip.origin_station_id, Trip.line_id],
    )
    destination_station_line: Mapped[Optional["StationLine"]] = relationship(
        back_populates="destination_trips",
        primaryjoin=lambda: and_(
            foreign(Trip.destination_station_id) == StationLine.station_id,
            foreign(Trip.line_id) == StationLine.line_id,
        ),
        foreign_keys=lambda: [Trip.destination_station_id, Trip.line_id],
    )
    timetable_entries: Mapped[list["Timetable"]] = relationship(back_populates="trip", cascade="all, delete-orphan")
    trip_status_events: Mapped[list["TripStatusEvent"]] = relationship(back_populates="trip")
    predicted_stop_times: Mapped[list["PredictedStopTime"]] = relationship(back_populates="trip")
    next_departures: Mapped[list["NextDeparture"]] = relationship(back_populates="trip")


class Timetable(Base):
    __tablename__ = "timetable"
    __table_args__ = (
        ForeignKeyConstraint(["trip_id", "line_id"], ["trips.trip_id", "trips.line_id"], onupdate="CASCADE", ondelete="CASCADE", name="timetable_trip_fk"),
        ForeignKeyConstraint(["line_id", "line_station_order", "station_id"], ["station_lines.line_id", "station_lines.station_order", "station_lines.station_id"], onupdate="CASCADE", ondelete="RESTRICT", name="timetable_station_position_fk"),
        UniqueConstraint("trip_id", "stop_sequence", name="timetable_trip_sequence_unique"),
        UniqueConstraint("trip_id", "station_id", name="timetable_trip_station_unique"),
        UniqueConstraint("trip_id", "line_id", "stop_sequence", name="timetable_trip_line_sequence_unique"),
        UniqueConstraint("trip_id", "line_id", "station_id", name="timetable_trip_line_station_unique"),
        UniqueConstraint("trip_id", "line_id", "line_station_order", name="timetable_trip_line_station_order_unique"),
        UniqueConstraint("timetable_id", "trip_id", "line_id", "station_id", "line_station_order", "stop_sequence", name="timetable_row_identity_unique"),
    )

    timetable_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    trip_id: Mapped[str] = mapped_column(Text, nullable=False)
    line_id: Mapped[str] = mapped_column(Text, nullable=False)
    station_id: Mapped[str] = mapped_column(Text, nullable=False)
    line_station_order: Mapped[int] = mapped_column(Integer, nullable=False)
    stop_sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    scheduled_arrival_time: Mapped[time] = mapped_column(nullable=False)
    scheduled_arrival_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default=text("0"))
    scheduled_departure_time: Mapped[time] = mapped_column(nullable=False)
    scheduled_departure_day_offset: Mapped[int] = mapped_column(SmallInteger, nullable=False, server_default=text("0"))
    pickup_allowed: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))
    dropoff_allowed: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    trip: Mapped["Trip"] = relationship(back_populates="timetable_entries")
    station_line: Mapped["StationLine"] = relationship(back_populates="timetable_entries")
    predicted_stop_times: Mapped[list["PredictedStopTime"]] = relationship(back_populates="timetable")
    next_departures: Mapped[list["NextDeparture"]] = relationship(back_populates="timetable")
