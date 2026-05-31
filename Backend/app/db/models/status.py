from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, Numeric, Text, text, CheckConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.enums import ScenarioType, EventCategory, ImpactLevel, SourceType, InfrastructureStatus, TripStatus, CurrentStatus, RoutingStatusSource


class Scenario(Base):
    __tablename__ = "scenarios"

    scenario_id: Mapped[str] = mapped_column(Text, primary_key=True)
    scenario_name: Mapped[str] = mapped_column(Text, nullable=False, unique=True)
    scenario_type: Mapped[ScenarioType] = mapped_column(Text, nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("FALSE"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    line_status_events: Mapped[list["LineStatusEvent"]] = relationship(back_populates="scenario")
    station_status_events: Mapped[list["StationStatusEvent"]] = relationship(back_populates="scenario")
    edge_status_events: Mapped[list["EdgeStatusEvent"]] = relationship(back_populates="scenario")
    trip_status_events: Mapped[list["TripStatusEvent"]] = relationship(back_populates="scenario")
    routing_edges_current: Mapped[list["RoutingEdgesCurrent"]] = relationship(back_populates="scenario")
    station_status_current_rows: Mapped[list["StationStatusCurrent"]] = relationship(back_populates="scenario")
    line_status_current_rows: Mapped[list["LineStatusCurrent"]] = relationship(back_populates="scenario")
    predicted_stop_times: Mapped[list["PredictedStopTime"]] = relationship(back_populates="scenario")
    route_request_logs: Mapped[list["RouteRequestLog"]] = relationship(back_populates="scenario")


class LineStatusEvent(Base):
    __tablename__ = "line_status_events"

    line_status_event_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True, nullable=False, server_default=text("now()"))
    line_id: Mapped[str] = mapped_column(ForeignKey("lines.line_id", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    status: Mapped[InfrastructureStatus] = mapped_column(Text, nullable=False)
    event_category: Mapped[EventCategory] = mapped_column(Text, nullable=False, server_default=text("'incident'"))
    impact_level: Mapped[ImpactLevel] = mapped_column(Text, nullable=False, server_default=text("'minor'"))
    effective_from: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    effective_to: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    delay_min: Mapped[Optional[int]] = mapped_column(Integer)
    reason_code: Mapped[Optional[str]] = mapped_column(Text)
    reason_text: Mapped[Optional[str]] = mapped_column(Text)
    source_type: Mapped[SourceType] = mapped_column(Text, nullable=False, server_default=text("'manual'"))
    source_ref: Mapped[Optional[str]] = mapped_column(Text)
    scenario_id: Mapped[Optional[str]] = mapped_column(ForeignKey("scenarios.scenario_id", onupdate="CASCADE", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    line: Mapped["Line"] = relationship(back_populates="line_status_events")
    scenario: Mapped[Optional["Scenario"]] = relationship(back_populates="line_status_events")


class StationStatusEvent(Base):
    __tablename__ = "station_status_events"

    station_status_event_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True, nullable=False, server_default=text("now()"))
    station_id: Mapped[str] = mapped_column(ForeignKey("stations.station_id", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    status: Mapped[InfrastructureStatus] = mapped_column(Text, nullable=False)
    event_category: Mapped[EventCategory] = mapped_column(Text, nullable=False, server_default=text("'incident'"))
    impact_level: Mapped[ImpactLevel] = mapped_column(Text, nullable=False, server_default=text("'minor'"))
    effective_from: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    effective_to: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    delay_min: Mapped[Optional[int]] = mapped_column(Integer)
    reason_code: Mapped[Optional[str]] = mapped_column(Text)
    reason_text: Mapped[Optional[str]] = mapped_column(Text)
    source_type: Mapped[SourceType] = mapped_column(Text, nullable=False, server_default=text("'manual'"))
    source_ref: Mapped[Optional[str]] = mapped_column(Text)
    scenario_id: Mapped[Optional[str]] = mapped_column(ForeignKey("scenarios.scenario_id", onupdate="CASCADE", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    station: Mapped["Station"] = relationship(back_populates="station_status_events")
    scenario: Mapped[Optional["Scenario"]] = relationship(back_populates="station_status_events")


class EdgeStatusEvent(Base):
    __tablename__ = "edge_status_events"

    edge_status_event_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True, nullable=False, server_default=text("now()"))
    edge_id: Mapped[int] = mapped_column(ForeignKey("edges.edge_id", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    status: Mapped[InfrastructureStatus] = mapped_column(Text, nullable=False)
    event_category: Mapped[EventCategory] = mapped_column(Text, nullable=False, server_default=text("'incident'"))
    impact_level: Mapped[ImpactLevel] = mapped_column(Text, nullable=False, server_default=text("'minor'"))
    effective_from: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    effective_to: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    delay_min: Mapped[Optional[int]] = mapped_column(Integer)
    reason_code: Mapped[Optional[str]] = mapped_column(Text)
    reason_text: Mapped[Optional[str]] = mapped_column(Text)
    source_type: Mapped[SourceType] = mapped_column(Text, nullable=False, server_default=text("'manual'"))
    source_ref: Mapped[Optional[str]] = mapped_column(Text)
    scenario_id: Mapped[Optional[str]] = mapped_column(ForeignKey("scenarios.scenario_id", onupdate="CASCADE", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    edge: Mapped["Edge"] = relationship(back_populates="edge_status_events")
    scenario: Mapped[Optional["Scenario"]] = relationship(back_populates="edge_status_events")


class TripStatusEvent(Base):
    __tablename__ = "trip_status_events"

    trip_status_event_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), primary_key=True, nullable=False, server_default=text("now()"))
    trip_id: Mapped[str] = mapped_column(ForeignKey("trips.trip_id", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    status: Mapped[TripStatus] = mapped_column(Text, nullable=False)
    event_category: Mapped[EventCategory] = mapped_column(Text, nullable=False, server_default=text("'incident'"))
    impact_level: Mapped[ImpactLevel] = mapped_column(Text, nullable=False, server_default=text("'minor'"))
    effective_from: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    effective_to: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True))
    delay_min: Mapped[Optional[int]] = mapped_column(Integer)
    reason_code: Mapped[Optional[str]] = mapped_column(Text)
    reason_text: Mapped[Optional[str]] = mapped_column(Text)
    source_type: Mapped[SourceType] = mapped_column(Text, nullable=False, server_default=text("'manual'"))
    source_ref: Mapped[Optional[str]] = mapped_column(Text)
    scenario_id: Mapped[Optional[str]] = mapped_column(ForeignKey("scenarios.scenario_id", onupdate="CASCADE", ondelete="SET NULL"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    trip: Mapped["Trip"] = relationship(back_populates="trip_status_events")
    scenario: Mapped[Optional["Scenario"]] = relationship(back_populates="trip_status_events")


class RoutingEdgesCurrent(Base):
    __tablename__ = "routing_edges_current"

    routing_edge_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    base_edge_id: Mapped[int] = mapped_column(ForeignKey("edges.edge_id", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    from_station_id: Mapped[str] = mapped_column(ForeignKey("stations.station_id", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    to_station_id: Mapped[str] = mapped_column(ForeignKey("stations.station_id", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    line_id: Mapped[str] = mapped_column(ForeignKey("lines.line_id", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    base_travel_time_min: Mapped[int] = mapped_column(Integer, nullable=False)
    adjusted_travel_time_min: Mapped[int] = mapped_column(Integer, nullable=False)
    is_available: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))
    status_source: Mapped[RoutingStatusSource] = mapped_column(Text, nullable=False, server_default=text("'normal'"))
    reason: Mapped[Optional[str]] = mapped_column(Text)
    scenario_id: Mapped[Optional[str]] = mapped_column(ForeignKey("scenarios.scenario_id", onupdate="CASCADE", ondelete="SET NULL"))
    calculated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    base_edge: Mapped["Edge"] = relationship(back_populates="routing_edges_current")
    from_station: Mapped["Station"] = relationship(
        back_populates="routing_edges_from",
        foreign_keys=[from_station_id],
    )
    to_station: Mapped["Station"] = relationship(
        back_populates="routing_edges_to",
        foreign_keys=[to_station_id],
    )
    line: Mapped["Line"] = relationship(back_populates="routing_edges_current")
    scenario: Mapped[Optional["Scenario"]] = relationship(back_populates="routing_edges_current")

    __table_args__ = (
        CheckConstraint(
            "status_source IN ('normal', 'edge_event', 'line_current', 'station_current', 'scenario', 'delay_event', 'maintenance', 'manual_override')",
            name="routing_edges_current_status_source_chk"
        ),
    )


class StationStatusCurrent(Base):
    __tablename__ = "station_status_current"

    station_id: Mapped[str] = mapped_column(ForeignKey("stations.station_id", onupdate="CASCADE", ondelete="CASCADE"), primary_key=True)
    status: Mapped[CurrentStatus] = mapped_column(Text, nullable=False)
    reason: Mapped[Optional[str]] = mapped_column(Text)
    is_boarding_allowed: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))
    is_alighting_allowed: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))
    scenario_id: Mapped[Optional[str]] = mapped_column(ForeignKey("scenarios.scenario_id", onupdate="CASCADE", ondelete="SET NULL"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    station: Mapped["Station"] = relationship(back_populates="station_status_current")
    scenario: Mapped[Optional["Scenario"]] = relationship(back_populates="station_status_current_rows")


class LineStatusCurrent(Base):
    __tablename__ = "line_status_current"

    line_id: Mapped[str] = mapped_column(ForeignKey("lines.line_id", onupdate="CASCADE", ondelete="CASCADE"), primary_key=True)
    status: Mapped[CurrentStatus] = mapped_column(Text, nullable=False)
    delay_min_avg: Mapped[Decimal] = mapped_column(Numeric(8, 2), nullable=False, server_default=text("0"))
    reason: Mapped[Optional[str]] = mapped_column(Text)
    scenario_id: Mapped[Optional[str]] = mapped_column(ForeignKey("scenarios.scenario_id", onupdate="CASCADE", ondelete="SET NULL"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    line: Mapped["Line"] = relationship(back_populates="line_status_current")
    scenario: Mapped[Optional["Scenario"]] = relationship(back_populates="line_status_current_rows")
