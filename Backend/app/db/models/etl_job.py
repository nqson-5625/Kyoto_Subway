from __future__ import annotations

from datetime import date, datetime
from typing import List, Optional

from sqlalchemy import BigInteger, Date, DateTime, Enum as SQLEnum, ForeignKey, Index, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.db.enums import ETLJobStatus


class ETLJobRun(Base):
    __tablename__ = "etl_job_runs"

    __table_args__ = (
        Index("idx_etl_job_runs_started_at", "started_at"),
        Index("idx_etl_job_runs_status", "status"),
    )

    job_run_id: Mapped[int] = mapped_column(
        BigInteger,
        primary_key=True,
        autoincrement=True,
    )

    job_name: Mapped[str] = mapped_column(Text, nullable=False)
    service_date: Mapped[Optional[date]] = mapped_column(Date, nullable=True)
    scenario_id: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    status: Mapped[ETLJobStatus] = mapped_column(
        SQLEnum(
            ETLJobStatus,
            name="etl_job_status",
            values_callable=lambda enum_cls: [e.value for e in enum_cls],
        ),
        nullable=False,
    )
    current_step: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    finished_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    error_detail: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    error_hint: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    error_context: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    steps: Mapped[List["ETLJobStep"]] = relationship(
        back_populates="job_run",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


class ETLJobStep(Base):
    __tablename__ = "etl_job_steps"

    __table_args__ = (
        Index("idx_etl_job_steps_job_run_id", "job_run_id"),
        Index("idx_etl_job_steps_status", "status"),
    )

    job_step_id: Mapped[int] = mapped_column(
        BigInteger,
        primary_key=True,
        autoincrement=True,
    )

    job_run_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("etl_job_runs.job_run_id", ondelete="CASCADE"),
        nullable=False,
    )

    step_name: Mapped[str] = mapped_column(Text, nullable=False)

    status: Mapped[ETLJobStatus] = mapped_column(
        SQLEnum(
            ETLJobStatus,
            name="etl_job_status",
            values_callable=lambda enum_cls: [e.value for e in enum_cls],
        ),
        nullable=False,
    )

    started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )
    finished_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    error_detail: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    error_hint: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    error_context: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    job_run: Mapped["ETLJobRun"] = relationship(
        back_populates="steps",
    )