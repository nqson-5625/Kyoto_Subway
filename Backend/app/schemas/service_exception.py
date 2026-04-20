from datetime import date, datetime

from pydantic import BaseModel, ConfigDict


class ServiceExceptionBase(BaseModel):
    service_id: str
    service_date: date
    exception_type: str
    exception_category: str = 'special_operation'
    reason: str | None = None
    note: str | None = None


class ServiceExceptionCreate(ServiceExceptionBase):
    pass


class ServiceExceptionUpdate(BaseModel):
    service_id: str | None = None
    service_date: date | None = None
    exception_type: str | None = None
    exception_category: str | None = None
    reason: str | None = None
    note: str | None = None


class ServiceExceptionResponse(ServiceExceptionBase):
    service_exception_id: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
