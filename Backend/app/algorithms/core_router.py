# File: app/algorithms/core_router.py
import uuid
from datetime import datetime, timedelta
from typing import Tuple, List, Any, Optional
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.schemas.algorithm.core_routing_output import (
    CoreRoutingOutput, CoreRoutingRequestEcho, CoreRoutingRoute, CoreRoutingSegment
)
from app.schemas.algorithm.routing_common import CostBreakdown
from app.algorithms.graph_builder import TransitGraph, RideEdge, TransferEdge
from app.algorithms.dijkstra import time_dependent_dijkstra
from app.algorithms.astar import time_dependent_astar

async def find_nearest_station(db: Session, lon: float, lat: float) -> Tuple[str, int]:
    """
    Sử dụng PostGIS để tính toán khoảng cách thực tế từ điểm click đến ga gần nhất.
    Tốc độ đi bộ quy chuẩn: 1.2 m/s
    """
    sql = text("""
        SELECT station_id, 
               ST_Distance(geom::geography, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography) as dist_meters
        FROM stations
        WHERE is_active = TRUE
        ORDER BY geom <-> ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)
        LIMIT 1;
    """)
    result = db.execute(sql, {"lon": lon, "lat": lat}).fetchone()
    
    if not result:
        raise Exception("Mạng lưới ga tàu không khả dụng.")
        
    station_id = result[0]
    distance_meters = result[1]
    walk_seconds = int(distance_meters / 1.2)
    
    return station_id, walk_seconds

# ... (Hàm _build_route_object giữ nguyên như code cũ của bạn) ...
def _build_route_object(path_edges, origin_walk_sec, dest_walk_sec, start_station_id, end_station_id):
    # (Giữ nguyên đoạn code bạn đã có ở hàm này)
    pass 
# ... (Bạn tự paste lại nội dung _build_route_object ở file cũ vào đây) ...

async def process_routing_request(
    request: CoreRoutingRequestEcho,
    graph: TransitGraph,
    request_time: datetime,
    db: Session,
    algorithm: str = "dijkstra"
) -> CoreRoutingOutput:
    
    # 1. Truy vấn Database lấy ga gần nhất (Dữ liệu thật)
    start_station_id, origin_walk_sec = await find_nearest_station(db, request.origin[0], request.origin[1])
    end_station_id, dest_walk_sec = await find_nearest_station(db, request.destination[0], request.destination[1])
    actual_start_time = request_time + timedelta(seconds=origin_walk_sec)
    
    # 2. Định tuyến theo yêu cầu của FE
    if algorithm == "astar":
        def heuristic(u, v): return 0.0 # Bổ sung logic Haversine sau nếu cần
        path, time_cost = time_dependent_astar(graph, start_station_id, end_station_id, actual_start_time, heuristic)
    else:
        path, time_cost = time_dependent_dijkstra(graph, start_station_id, end_station_id, actual_start_time)
        
    candidate_routes = []
    route_obj = _build_route_object(path, origin_walk_sec, dest_walk_sec, start_station_id, end_station_id)
    
    if route_obj:
        route_obj.route_id = f"route_1_{uuid.uuid4().hex[:8]}"
        candidate_routes.append((time_cost, route_obj))
        
    if not candidate_routes:
        return CoreRoutingOutput(status="no_route", request=request, routes=[])
        
    return CoreRoutingOutput(
        status="success",
        request=request,
        routes=[candidate_routes[0][1]],
        computed_candidate_count=1,
        selected_route_id=candidate_routes[0][1].route_id
    )