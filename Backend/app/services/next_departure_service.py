from fastapi import HTTPException

from app.db.repositories.next_departure_repository import (
    NextDepartureRepository,
)


class NextDepartureService:

    def __init__(self, db):
        self.repo = NextDepartureRepository(db)

    def get_all(self):
        return self.repo.get_all()

    def get_by_id(self, next_departure_id: int):
        item = self.repo.get_by_id(next_departure_id)

        if not item:
            raise HTTPException(
                status_code=404,
                detail="Next departure not found"
            )

        return item

    def get_by_station(self, station_id: str):
        return self.repo.get_by_station(station_id)

    def get_by_line(self, line_id: str):
        return self.repo.get_by_line(line_id)

    def create(self, data):
        payload = data.model_dump(exclude_unset=True)
        return self.repo.create(payload)

    def update(self, next_departure_id: int, data):
        payload = data.model_dump(exclude_unset=True)

        item = self.repo.update(
            next_departure_id=next_departure_id,
            data=payload
        )

        if not item:
            raise HTTPException(
                status_code=404,
                detail="Next departure not found"
            )

        return item

    def delete(self, next_departure_id: int):
        item = self.repo.delete(next_departure_id)

        if not item:
            raise HTTPException(
                status_code=404,
                detail="Next departure not found"
            )

        return {
            "message": "Deleted successfully",
            "next_departure_id": next_departure_id
        }