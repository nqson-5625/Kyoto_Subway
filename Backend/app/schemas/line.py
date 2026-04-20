from datetime import datetime

from pydantic import BaseModel, ConfigDict


class LineResponse(BaseModel):
    line_id: str
    line_code: str | None = None
    line_name: str
    operator_name: str
    color_hex: str | None = None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class LineStationResponse(BaseModel):
    station_line_id: int
    line_id: str
    station_id: str
    station_name: str
    station_order: int
    is_terminal: bool

    model_config = ConfigDict(from_attributes=True)
