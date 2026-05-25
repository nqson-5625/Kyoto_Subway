from pydantic import BaseModel


class RouteResponse(BaseModel):
    minutes: int
    path: list[str]