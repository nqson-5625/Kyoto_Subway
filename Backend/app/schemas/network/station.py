from datetime import datetime

from pydantic import BaseModel, ConfigDict


class StationResponse(BaseModel):
    station_id: str
    station_name: str
    is_transfer_station: bool
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
