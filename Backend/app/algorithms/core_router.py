# File: app/algorithms/core_router.py
import uuid
from datetime import datetime, timedelta
from typing import Tuple, List, Any, Optional
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.schemas.algorithm.core_routing_output import (
    CoreRoutingOutput, CoreRoutingRequestEcho, CoreRoutingRoute, CoreRoutingSegment
)
from app.schemas.algorithm.enums import SegmentMode
from app.schemas.algorithm.routing_common import CostBreakdown
from app.algorithms.graph_builder import TransitGraph, RideEdge, TransferEdge
from app.algorithms.dijkstra import time_dependent_dijkstra
from app.algorithms.astar import time_dependent_astar

async def find_nearest_station(db: Session, lon: float, lat: float) -> Tuple[str, int]:
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
        raise Exception("Mạng lưới ga tàu không khả dụng hoặc bảng dữ liệu trống.")
        
    station_id = result[0]
    distance_meters = result[1]
    walk_seconds = int(distance_meters / 1.2) # Tốc độ đi bộ quy chuẩn 1.2 m/s
    return station_id, walk_seconds

def _build_route_object(path_edges, origin_walk_sec, dest_walk_sec, start_station_id, end_station_id):
    if path_edges is None and start_station_id != end_station_id:
        return None
        
    segments = []
    idx = 1
    total_cost_min = (origin_walk_sec + dest_walk_sec) / 60.0
    transfer_penalty = 0.0
    
    # 1. Chặng đi bộ đầu: Từ điểm click thực tế tới ga xuất phát gần nhất
    segments.append(CoreRoutingSegment(
        segment_index=idx,
        mode=SegmentMode.WALK,
        from_node_id="START_POINT",
        to_node_id=start_station_id,
        from_station_id=None,
        to_station_id=start_station_id,
        base_travel_minutes=origin_walk_sec / 60.0,
        edge_ids=[],
        transfer_ids=[],
        path_node_ids=[]
    ))
    idx += 1
    
    # 2. Duyệt qua danh sách các cạnh đồ thị tìm được từ thuật toán Dijkstra
    if path_edges:
        for edge in path_edges:
            if isinstance(edge, RideEdge):
                segments.append(CoreRoutingSegment(
                    segment_index=idx,
                    mode=SegmentMode.RIDE,
                    from_node_id=edge.from_station,
                    to_node_id=edge.to_station,
                    from_station_id=edge.from_station,
                    to_station_id=edge.to_station,
                    line_id=edge.line_id,
                    base_travel_minutes=edge.travel_seconds / 60.0,
                    edge_ids=[],
                    transfer_ids=[],
                    path_node_ids=[]
                ))
                total_cost_min += edge.travel_seconds / 60.0
            elif isinstance(edge, TransferEdge):
                segments.append(CoreRoutingSegment(
                    segment_index=idx,
                    mode=SegmentMode.TRANSFER,
                    from_node_id=edge.from_station,
                    to_node_id=edge.to_station,
                    from_station_id=edge.from_station,
                    to_station_id=edge.to_station,
                    transfer_minutes=edge.travel_seconds / 60.0,
                    edge_ids=[],
                    transfer_ids=[],
                    path_node_ids=[]
                ))
                total_cost_min += edge.travel_seconds / 60.0
                transfer_penalty += edge.travel_seconds / 60.0
            idx += 1
        
    # 3. Chặng đi bộ cuối: Từ ga tàu kết thúc ra vị trí đích thực tế được chọn
    segments.append(CoreRoutingSegment(
        segment_index=idx,
        mode=SegmentMode.WALK,
        from_node_id=end_station_id,
        to_node_id="END_POINT",
        from_station_id=end_station_id,
        to_station_id=None,
        base_travel_minutes=dest_walk_sec / 60.0,
        edge_ids=[],
        transfer_ids=[],
        path_node_ids=[]
    ))
    
    return CoreRoutingRoute(
        route_id="",
        rank=1,
        segments=segments,
        cost_breakdown=CostBreakdown(
            total_cost=total_cost_min,
            time_cost=total_cost_min,
            transfer_penalty=transfer_penalty
        ),
        visited_station_ids=[],
        visited_line_ids=[],
        warnings=[]
    )

async def process_routing_request(
    request: CoreRoutingRequestEcho,
    graph: TransitGraph,
    request_time: datetime,
    db: Session,
    algorithm: str = "dijkstra"
) -> CoreRoutingOutput:
    
    start_station_id, origin_walk_sec = await find_nearest_station(db, request.origin[0], request.origin[1])
    end_station_id, dest_walk_sec = await find_nearest_station(db, request.destination[0], request.destination[1])
    actual_start_time = request_time + timedelta(seconds=origin_walk_sec)
    
    if start_station_id == end_station_id:
        path = []
        time_cost = 0.0
    else:
        if algorithm == "astar":
            def heuristic(u, v): return 0.0 
            path, time_cost = time_dependent_astar(graph, start_station_id, end_station_id, actual_start_time, heuristic)
        else:
            path, time_cost = time_dependent_dijkstra(graph, start_station_id, end_station_id, actual_start_time)
            
    if path is None:
        return CoreRoutingOutput(status="fail", request=request, routes=[])
        
    route_obj = _build_route_object(path, origin_walk_sec, dest_walk_sec, start_station_id, end_station_id)
    if not route_obj:
        return CoreRoutingOutput(status="fail", request=request, routes=[])
        
    route_obj.route_id = f"route_{uuid.uuid4().hex[:8]}"
    return CoreRoutingOutput(
        status="success",
        request=request,
        routes=[route_obj],
        computed_candidate_count=1,
        selected_route_id=route_obj.route_id
    )