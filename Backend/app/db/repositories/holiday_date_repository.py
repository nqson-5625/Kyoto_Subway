from datetime import date

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models.schedule import HolidayDate


class HolidayDateRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_by_date(self, holiday_date: date) -> HolidayDate | None:
        stmt = select(HolidayDate).where(HolidayDate.holiday_date == holiday_date)
        return self.db.execute(stmt).scalar_one_or_none()

    def list_all(self) -> list[HolidayDate]:
        stmt = select(HolidayDate).order_by(HolidayDate.holiday_date.asc())
        return list(self.db.execute(stmt).scalars().all())

    def create(self, **kwargs) -> HolidayDate:
        holiday_date = HolidayDate(**kwargs)
        try:
            self.db.add(holiday_date)
            self.db.flush()
            self.db.refresh(holiday_date)
            self.db.commit()
            return holiday_date
        except Exception:
            self.db.rollback()
            raise

    def update(self, holiday_date: HolidayDate, **kwargs) -> HolidayDate:
        try:
            for key, value in kwargs.items():
                setattr(holiday_date, key, value)
            self.db.add(holiday_date)
            self.db.flush()
            self.db.refresh(holiday_date)
            self.db.commit()
            return holiday_date
        except Exception:
            self.db.rollback()
            raise

    def delete(self, holiday_date: HolidayDate) -> None:
        try:
            self.db.delete(holiday_date)
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise