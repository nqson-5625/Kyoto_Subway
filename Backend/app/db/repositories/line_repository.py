from app.db.models.network import Line

class LineRepository:

    def __init__(self, db):
        self.db = db

    def get_all(self):
        return self.db.query(Line).all()

    def get_by_id(self, line_id):
        return self.db.query(Line).filter(
            Line.line_id == line_id
        ).first()