from typing import Literal

from fastapi import APIRouter, Depends, HTTPException

from app.api.deps import get_db
from app.db.models.network import Line, Station, Edge


from app.db.models.schedule import Trip



router = APIRouter(
    prefix="/control-center",
    tags=["Control Center"]
)


@router.get("/event-types")
def get_event_types():
    return [
        {
            "value": "line",
            "label": "Line Status Event",
            "target_endpoint": "/control-center/targets?event_type=line",
            "submit_endpoint": "/line-status-events"
        },
        {
            "value": "station",
            "label": "Station Status Event",
            "target_endpoint": "/control-center/targets?event_type=station",
            "submit_endpoint": "/station-status-events"
        },
        {
            "value": "trip",
            "label": "Trip Status Event",
            "target_endpoint": "/control-center/targets?event_type=trip",
            "submit_endpoint": "/trip-status-events"
        },
        {
            "value": "edge",
            "label": "Edge Status Event",
            "target_endpoint": "/control-center/targets?event_type=edge",
            "submit_endpoint": "/edge-status-events"
        }
    ]


@router.get("/status-options")
def get_status_options():
    return [
        {
            "value": "normal",
            "label": "Hoạt động bình thường"
        },
        {
            "value": "warning",
            "label": "Cảnh báo / Quá tải"
        },
        {
            "value": "suspended",
            "label": "Sự cố / Tạm dừng"
        },
        {
            "value": "maintenance",
            "label": "Đang bảo trì"
        }
    ]


@router.get("/targets")
def get_targets(
    event_type: Literal["line", "station", "trip", "edge"],
    db=Depends(get_db)
):
    if event_type == "line":
        lines = db.query(Line).all()

        return [
            {
                "id": line.line_id,
                "label": getattr(line, "line_name", line.line_id),
                "type": "line"
            }
            for line in lines
        ]

    if event_type == "station":
        stations = db.query(Station).all()

        return [
            {
                "id": station.station_id,
                "label": getattr(station, "station_name", station.station_id),
                "type": "station"
            }
            for station in stations
        ]

    if event_type == "trip":
        trips = db.query(Trip).all()

        return [
            {
                "id": trip.trip_id,
                "label": trip.trip_id,
                "type": "trip"
            }
            for trip in trips
        ]

    if event_type == "edge":
        edges = db.query(Edge).all()

        result = []

        for edge in edges:
            edge_id = getattr(edge, "edge_id", None)

            if edge_id is None:
                edge_id = getattr(edge, "id", None)

            result.append(
                {
                    "id": edge_id,
                    "label": f"{edge.from_station_id} → {edge.to_station_id}",
                    "type": "edge"
                }
            )

        return result

    raise HTTPException(
        status_code=400,
        detail="Invalid event_type"
    )