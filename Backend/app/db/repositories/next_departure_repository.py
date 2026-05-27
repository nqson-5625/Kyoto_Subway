from datetime import datetime, timezone

from app.db.models.network import NextDeparture


class NextDepartureRepository:

    def __init__(self, db):
        self.db = db

    def get_all(self):
        return self.db.query(NextDeparture).all()

    def get_by_id(self, next_departure_id: int):
        return (
            self.db.query(NextDeparture)
            .filter(NextDeparture.next_departure_id == next_departure_id)
            .order_by(NextDeparture.updated_at.desc())
            .first()
        )

    def get_by_station(self, station_id: str):
        return (
            self.db.query(NextDeparture)
            .filter(NextDeparture.station_id == station_id)
            .order_by(NextDeparture.predicted_departure_time.asc())
            .all()
        )

    def get_by_line(self, line_id: str):
        return (
            self.db.query(NextDeparture)
            .filter(NextDeparture.line_id == line_id)
            .order_by(NextDeparture.predicted_departure_time.asc())
            .all()
        )

    def create(self, data: dict):
        if data.get("updated_at") is None:
            data["updated_at"] = datetime.now(timezone.utc)

        item = NextDeparture(**data)

        self.db.add(item)
        self.db.commit()
        self.db.refresh(item)

        return item

    def update(self, next_departure_id: int, data: dict):
        item = self.get_by_id(next_departure_id)

        if not item:
            return None

        for key, value in data.items():
            if value is not None:
                setattr(item, key, value)

        self.db.commit()
        self.db.refresh(item)

        return item

    def delete(self, next_departure_id: int):
        item = self.get_by_id(next_departure_id)

        if not item:
            return None

        self.db.delete(item)
        self.db.commit()

        return item