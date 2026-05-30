from datetime import datetime
from pydantic import BaseModel, ConfigDict


class EdgeResponse(BaseModel):
    edge_id: int
    from_station_id: str
    to_station_id: str
    line_id: str | None = None
    travel_time_min: float | int
    distance_m: float | None = None
    is_active: bool = True
    created_at: datetime | None = None

    model_config = ConfigDict(from_attributes=True)