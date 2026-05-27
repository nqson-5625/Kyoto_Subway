from fastapi import HTTPException

from app.db.repositories.trip_status_event_repository import (
    TripStatusEventRepository,
)


class TripStatusEventService:

    def __init__(self, db):
        self.repo = TripStatusEventRepository(db)

    def get_all(self):
        return self.repo.get_all()

    def get_by_id(self, event_id: int):
        event = self.repo.get_by_id(event_id)

        if not event:
            raise HTTPException(
                status_code=404,
                detail="Trip status event not found"
            )

        return event

    def create(self, data):
        payload = data.model_dump()
        return self.repo.create(payload)

    def update(self, event_id: int, data):
        payload = data.model_dump(exclude_unset=True)

        event = self.repo.update(event_id, payload)

        if not event:
            raise HTTPException(
                status_code=404,
                detail="Trip status event not found"
            )

        return event

    def delete(self, event_id: int):
        event = self.repo.delete(event_id)

        if not event:
            raise HTTPException(
                status_code=404,
                detail="Trip status event not found"
            )

        return {
            "message": "Deleted successfully",
            "trip_status_event_id": event_id
        }