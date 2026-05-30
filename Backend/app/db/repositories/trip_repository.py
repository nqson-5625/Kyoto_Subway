from app.db.models.schedule import Trip, Timetable

class TripRepository:

    def __init__(self, db):
        self.db = db

    def get_all(self):
        return self.db.query(Trip).all()

    def get_by_id(self, trip_id: str):
        return (
            self.db.query(Trip)
            .filter(Trip.trip_id == trip_id)
            .first()
        )

    def get_stops_by_trip_id(self, trip_id: str):
        return (
            self.db.query(Timetable)
            .filter(Timetable.trip_id == trip_id)
            .order_by(Timetable.stop_sequence.asc())
            .all()
        )