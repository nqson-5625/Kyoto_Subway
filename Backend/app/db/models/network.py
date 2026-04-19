from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from typing import Optional

from geoalchemy2 import Geometry
from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, ForeignKeyConstraint, Integer, Numeric, Text, UniqueConstraint, and_, text
from sqlalchemy.orm import Mapped, foreign, mapped_column, relationship

from app.db.base import Base


class Line(Base):
    __tablename__ = "lines"

    line_id: Mapped[str] = mapped_column(Text, primary_key=True)
    line_code: Mapped[Optional[str]] = mapped_column(Text, unique=True)
    line_name: Mapped[str] = mapped_column(Text, nullable=False)
    operator_name: Mapped[str] = mapped_column(Text, nullable=False)
    color_hex: Mapped[Optional[str]] = mapped_column(Text)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    station_lines: Mapped[list["StationLine"]] = relationship(back_populates="line", cascade="all, delete-orphan")
    edges: Mapped[list["Edge"]] = relationship(back_populates="line")
    trips: Mapped[list["Trip"]] = relationship(back_populates="line")
    line_status_events: Mapped[list["LineStatusEvent"]] = relationship(back_populates="line")
    line_status_current: Mapped[Optional["LineStatusCurrent"]] = relationship(back_populates="line", uselist=False)
    routing_edges_current: Mapped[list["RoutingEdgesCurrent"]] = relationship(back_populates="line")
    next_departures: Mapped[list["NextDeparture"]] = relationship(back_populates="line")


class Station(Base):
    __tablename__ = "stations"

    station_id: Mapped[str] = mapped_column(Text, primary_key=True)
    station_name: Mapped[str] = mapped_column(Text, nullable=False)
    geom: Mapped[object | None] = mapped_column(Geometry(geometry_type="POINT", srid=4326))
    is_transfer_station: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("FALSE"))
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    station_lines: Mapped[list["StationLine"]] = relationship(back_populates="station", cascade="all, delete-orphan")
    origin_trips: Mapped[list["Trip"]] = relationship(
        back_populates="origin_station",
        foreign_keys="Trip.origin_station_id",
    )
    destination_trips: Mapped[list["Trip"]] = relationship(
        back_populates="destination_station",
        foreign_keys="Trip.destination_station_id",
    )
    from_transfers: Mapped[list["Transfer"]] = relationship(
        back_populates="from_station",
        foreign_keys="Transfer.from_station_id",
        cascade="all, delete-orphan",
    )
    to_transfers: Mapped[list["Transfer"]] = relationship(
        back_populates="to_station",
        foreign_keys="Transfer.to_station_id",
        cascade="all, delete-orphan",
    )
    station_status_events: Mapped[list["StationStatusEvent"]] = relationship(back_populates="station")
    station_status_current: Mapped[Optional["StationStatusCurrent"]] = relationship(back_populates="station", uselist=False)
    predicted_stop_times: Mapped[list["PredictedStopTime"]] = relationship(back_populates="station")
    next_departures: Mapped[list["NextDeparture"]] = relationship(back_populates="station")
    routing_edges_from: Mapped[list["RoutingEdgesCurrent"]] = relationship(
        back_populates="from_station",
        foreign_keys="RoutingEdgesCurrent.from_station_id",
    )
    routing_edges_to: Mapped[list["RoutingEdgesCurrent"]] = relationship(
        back_populates="to_station",
        foreign_keys="RoutingEdgesCurrent.to_station_id",
    )
    route_requests_origin: Mapped[list["RouteRequestLog"]] = relationship(
        back_populates="origin_station",
        foreign_keys="RouteRequestLog.origin_station_id",
    )
    route_requests_destination: Mapped[list["RouteRequestLog"]] = relationship(
        back_populates="destination_station",
        foreign_keys="RouteRequestLog.destination_station_id",
    )


class StationLine(Base):
    __tablename__ = "station_lines"
    __table_args__ = (
        UniqueConstraint("station_id", "line_id", name="station_lines_unique"),
        UniqueConstraint("line_id", "station_order", name="station_lines_line_order_unique"),
        UniqueConstraint("line_id", "station_order", "station_id", name="station_lines_line_order_station_unique"),
    )

    station_line_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    station_id: Mapped[str] = mapped_column(ForeignKey("stations.station_id", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    line_id: Mapped[str] = mapped_column(ForeignKey("lines.line_id", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    station_order: Mapped[int] = mapped_column(Integer, nullable=False)
    is_terminal: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("FALSE"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    station: Mapped["Station"] = relationship(back_populates="station_lines")
    line: Mapped["Line"] = relationship(back_populates="station_lines")
    timetable_entries: Mapped[list["Timetable"]] = relationship(back_populates="station_line")
    outgoing_edges: Mapped[list["Edge"]] = relationship(
        back_populates="from_station_line",
        primaryjoin=lambda: and_(
            StationLine.line_id == foreign(Edge.line_id),
            StationLine.station_order == foreign(Edge.from_station_order),
            StationLine.station_id == foreign(Edge.from_station_id),
        ),
        foreign_keys=lambda: [Edge.line_id, Edge.from_station_order, Edge.from_station_id],
    )
    incoming_edges: Mapped[list["Edge"]] = relationship(
        back_populates="to_station_line",
        primaryjoin=lambda: and_(
            StationLine.line_id == foreign(Edge.line_id),
            StationLine.station_order == foreign(Edge.to_station_order),
            StationLine.station_id == foreign(Edge.to_station_id),
        ),
        foreign_keys=lambda: [Edge.line_id, Edge.to_station_order, Edge.to_station_id],
    )
    origin_trips: Mapped[list["Trip"]] = relationship(
        back_populates="origin_station_line",
        primaryjoin=lambda: and_(
            StationLine.station_id == foreign(Trip.origin_station_id),
            StationLine.line_id == foreign(Trip.line_id),
        ),
        foreign_keys=lambda: [Trip.origin_station_id, Trip.line_id],
    )
    destination_trips: Mapped[list["Trip"]] = relationship(
        back_populates="destination_station_line",
        primaryjoin=lambda: and_(
            StationLine.station_id == foreign(Trip.destination_station_id),
            StationLine.line_id == foreign(Trip.line_id),
        ),
        foreign_keys=lambda: [Trip.destination_station_id, Trip.line_id],
    )


class Edge(Base):
    __tablename__ = "edges"
    __table_args__ = (
        ForeignKeyConstraint(
            ["line_id", "from_station_order", "from_station_id"],
            ["station_lines.line_id", "station_lines.station_order", "station_lines.station_id"],
            onupdate="CASCADE",
            ondelete="RESTRICT",
            name="edges_from_station_position_fk",
        ),
        ForeignKeyConstraint(
            ["line_id", "to_station_order", "to_station_id"],
            ["station_lines.line_id", "station_lines.station_order", "station_lines.station_id"],
            onupdate="CASCADE",
            ondelete="RESTRICT",
            name="edges_to_station_position_fk",
        ),
        UniqueConstraint("line_id", "from_station_id", "to_station_id", name="edges_unique"),
        UniqueConstraint("line_id", "from_station_order", "to_station_order", name="edges_unique_orders"),
    )

    edge_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    line_id: Mapped[str] = mapped_column(ForeignKey("lines.line_id", onupdate="CASCADE", ondelete="RESTRICT"), nullable=False)
    from_station_id: Mapped[str] = mapped_column(Text, nullable=False)
    from_station_order: Mapped[int] = mapped_column(Integer, nullable=False)
    to_station_id: Mapped[str] = mapped_column(Text, nullable=False)
    to_station_order: Mapped[int] = mapped_column(Integer, nullable=False)
    travel_time_min: Mapped[int] = mapped_column(Integer, nullable=False)
    distance_km: Mapped[Optional[Decimal]] = mapped_column(Numeric(8, 3))
    geom: Mapped[object | None] = mapped_column(Geometry(geometry_type="LINESTRING", srid=4326))
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    line: Mapped["Line"] = relationship(back_populates="edges")
    from_station_line: Mapped["StationLine"] = relationship(
        back_populates="outgoing_edges",
        primaryjoin=lambda: and_(
            foreign(Edge.line_id) == StationLine.line_id,
            foreign(Edge.from_station_order) == StationLine.station_order,
            foreign(Edge.from_station_id) == StationLine.station_id,
        ),
        foreign_keys=lambda: [Edge.line_id, Edge.from_station_order, Edge.from_station_id],
    )
    to_station_line: Mapped["StationLine"] = relationship(
        back_populates="incoming_edges",
        primaryjoin=lambda: and_(
            foreign(Edge.line_id) == StationLine.line_id,
            foreign(Edge.to_station_order) == StationLine.station_order,
            foreign(Edge.to_station_id) == StationLine.station_id,
        ),
        foreign_keys=lambda: [Edge.line_id, Edge.to_station_order, Edge.to_station_id],
    )
    edge_status_events: Mapped[list["EdgeStatusEvent"]] = relationship(back_populates="edge")
    routing_edges_current: Mapped[list["RoutingEdgesCurrent"]] = relationship(back_populates="base_edge")


class Transfer(Base):
    __tablename__ = "transfers"
    __table_args__ = (
        UniqueConstraint("from_station_id", "to_station_id", name="transfers_unique"),
    )

    transfer_id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    from_station_id: Mapped[str] = mapped_column(ForeignKey("stations.station_id", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    to_station_id: Mapped[str] = mapped_column(ForeignKey("stations.station_id", onupdate="CASCADE", ondelete="CASCADE"), nullable=False)
    transfer_time_min: Mapped[int] = mapped_column(Integer, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("TRUE"))
    transfer_type: Mapped[str] = mapped_column(Text, nullable=False, server_default=text("'same_station_interchange'"))
    note: Mapped[Optional[str]] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=text("now()"))

    from_station: Mapped["Station"] = relationship(back_populates="from_transfers", foreign_keys=[from_station_id])
    to_station: Mapped["Station"] = relationship(back_populates="to_transfers", foreign_keys=[to_station_id])
