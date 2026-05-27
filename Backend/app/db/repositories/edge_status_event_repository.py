from app.db.models.network import EdgeStatusEvent


class EdgeStatusEventRepository:

    def __init__(self, db):
        self.db = db

    def get_all(self):
        return self.db.query(EdgeStatusEvent).all()

    def get_by_id(self, event_id: int):
        return (
            self.db.query(EdgeStatusEvent)
            .filter(EdgeStatusEvent.edge_status_event_id == event_id)
            .first()
        )

    def create(self, data: dict):
        event = EdgeStatusEvent(**data)

        self.db.add(event)
        self.db.commit()
        self.db.refresh(event)

        return event

    def update(self, event_id: int, data: dict):
        event = self.get_by_id(event_id)

        if not event:
            return None

        for key, value in data.items():
            if value is not None:
                setattr(event, key, value)

        self.db.commit()
        self.db.refresh(event)

        return event

    def delete(self, event_id: int):
        event = self.get_by_id(event_id)

        if not event:
            return None

        self.db.delete(event)
        self.db.commit()

        return event