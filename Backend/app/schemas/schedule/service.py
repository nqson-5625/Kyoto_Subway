from datetime import date

from pydantic import BaseModel, ConfigDict


class ServiceByDateResponse(BaseModel):
    service_id: str
    service_name: str
    service_type: str
    service_date: date
    is_holiday: bool

    model_config = ConfigDict(from_attributes=True)
