from datetime import datetime

from pydantic import BaseModel, ConfigDict


class EdgeStatusEventBase(BaseModel):
    edge_id: int
    status: str
    event_category: str = 'incident'
    impact_level: str = 'minor'
    effective_from: datetime
    effective_to: datetime | None = None
    delay_min: int | None = None
    reason_code: str | None = None
    reason_text: str | None = None
    source_type: str = 'manual'
    source_ref: str | None = None
    scenario_id: str | None = None


class EdgeStatusEventCreate(EdgeStatusEventBase):
    pass


class EdgeStatusEventUpdate(BaseModel):
    edge_id: int | None = None
    status: str | None = None
    event_category: str | None = None
    impact_level: str | None = None
    effective_from: datetime | None = None
    effective_to: datetime | None = None
    delay_min: int | None = None
    reason_code: str | None = None
    reason_text: str | None = None
    source_type: str | None = None
    source_ref: str | None = None
    scenario_id: str | None = None


class EdgeStatusEventResponse(EdgeStatusEventBase):
    edge_status_event_id: int
    recorded_at: datetime
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
