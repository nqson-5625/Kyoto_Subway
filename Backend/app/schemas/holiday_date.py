from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


class HolidayDateBase(BaseModel):
    holiday_name: str
    is_public_holiday: bool = True
    note: str | None = None


class HolidayDateCreate(HolidayDateBase):
    holiday_date: date


class HolidayDateUpdate(BaseModel):
    holiday_name: str | None = None
    is_public_holiday: bool | None = None
    note: str | None = None


class HolidayDateResponse(HolidayDateBase):
    holiday_date: date
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
