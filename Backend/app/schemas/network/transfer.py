from datetime import datetime

from pydantic import BaseModel, ConfigDict


class TransferResponse(BaseModel):
    transfer_id: int
    from_station_id: str
    to_station_id: str
    transfer_time_min: int
    is_active: bool
    transfer_type: str
    note: str | None = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
