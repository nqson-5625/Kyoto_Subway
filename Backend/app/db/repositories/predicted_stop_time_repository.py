from app.db.models.network import PredictedStopTime


class PredictedStopTimeRepository:

    def __init__(self, db):
        self.db = db

    def get_all(self):
        return self.db.query(PredictedStopTime).all()

    def get_by_id(self, predicted_stop_time_id: int):
        return (
            self.db.query(PredictedStopTime)
            .filter(
                PredictedStopTime.predicted_stop_time_id == predicted_stop_time_id
            )
            .order_by(PredictedStopTime.updated_at.desc())
            .first()
        )

    def get_by_station(self, station_id: str):
        return (
            self.db.query(PredictedStopTime)
            .filter(PredictedStopTime.station_id == station_id)
            .all()
        )

    def get_by_trip(self, trip_id: str):
        return (
            self.db.query(PredictedStopTime)
            .filter(PredictedStopTime.trip_id == trip_id)
            .all()
        )

    def create(self, data: dict):
        item = PredictedStopTime(**data)

        self.db.add(item)
        self.db.commit()
        self.db.refresh(item)

        return item

    def update(self, predicted_stop_time_id: int, data: dict):
        item = self.get_by_id(predicted_stop_time_id)

        if not item:
            return None

        for key, value in data.items():
            if value is not None:
                setattr(item, key, value)

        self.db.commit()
        self.db.refresh(item)

        return item

    def delete(self, predicted_stop_time_id: int):
        item = self.get_by_id(predicted_stop_time_id)

        if not item:
            return None

        self.db.delete(item)
        self.db.commit()

        return item