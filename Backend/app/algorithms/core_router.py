import uuid
from datetime import datetime, timedelta
from typing import Tuple, List, Any, Optional

from app.schemas.algorithm.core_routing_output import (
    CoreRoutingOutput, CoreRoutingRequestEcho, CoreRoutingRoute,
    CoreRoutingSegment, WalkEndpoint
)
from app.schemas.algorithm.routing_common import CostBreakdown, GraphNodeRef, StationRef
from app.schemas.algorithm.enums import SegmentMode, RouteStatus

from .graph_builder import TransitGraph, RideEdge, TransferEdge
from .dijkstra import time_dependent_dijkstra
from .astar import time_dependent_astar

async def find_nearest_station(lon: float, lat: float) -> Tuple[str, int]:
    """
    (Hàm giả lập) 
    Thực tế bạn sẽ gọi PostGIS ST_Distance(geom, ST_SetSRID(ST_MakePoint(lon, lat), 4326)) 
    tại bảng stations để tìm ga gần nhất và tính thời gian đi bộ.
    """
    # Giả sử tốc độ đi bộ 1.2m/s
    mock_station_id = "K08" # Giả lập ga xuất phát (Karasuma Oike)
    mock_walk_seconds = 300 # 5 phút đi bộ
    return mock_station_id, mock_walk_seconds

def _build_route_object(
    path_edges: List[Any], 
    origin_walk_sec: int, 
    dest_walk_sec: int,
    start_station_id: str,
    end_station_id: str
) -> Optional[CoreRoutingRoute]:
    """Helper ánh xạ chuỗi edges từ thuật toán thành CoreRoutingRoute schema."""
    if not path_edges:
        return None
        
    # Build Cost Breakdown
    walking_cost = origin_walk_sec + dest_walk_sec
    ride_cost = 0
    transfer_cost = 0
    
    # Map Path Thành Segments theo Schema chuẩn
    segments: List[CoreRoutingSegment] = []
    visited_stations = set([start_station_id, end_station_id])
    visited_lines = set()
    
    for i, edge in enumerate(path_edges):
        visited_stations.add(edge.from_station)
        visited_stations.add(edge.to_station)
        
        if isinstance(edge, RideEdge):
            ride_cost += edge.travel_seconds
            visited_lines.add(edge.line_id)
            segments.append(CoreRoutingSegment(
                segment_index=i+1,
                mode="ride", # SegmentMode.ride
                from_station_id=edge.from_station,
                to_station_id=edge.to_station,
                line_id=edge.line_id,
                trip_id=edge.trip_id,
                direction_id=edge.direction_id,
                base_travel_minutes=edge.travel_seconds / 60.0
            ))
        elif isinstance(edge, TransferEdge):
            transfer_cost += edge.travel_seconds
            segments.append(CoreRoutingSegment(
                segment_index=i+1,
                mode="transfer", # SegmentMode.transfer
                from_station_id=edge.from_station,
                to_station_id=edge.to_station,
                transfer_minutes=edge.travel_seconds / 60.0
            ))
            
    total_cost = (walking_cost + ride_cost + transfer_cost) / 60.0

    return CoreRoutingRoute(
        route_id=str(uuid.uuid4()),
        rank=1, # Sẽ được update lại trong tiến trình sort
        segments=segments,
        visited_station_ids=list(visited_stations),
        visited_line_ids=list(visited_lines),
        cost_breakdown=CostBreakdown(
            total_cost=total_cost,
            walking_cost=walking_cost / 60.0,
            ride_cost=ride_cost / 60.0,
            transfer_cost=transfer_cost / 60.0
        )
    )

async def process_routing_request(
    request: CoreRoutingRequestEcho,
    graph: TransitGraph, # Nhận graph đã load từ memory cache
    request_time: datetime
) -> CoreRoutingOutput:
    
    # 1. Tìm Ga gần điểm Origin / Destination (First/Last mile)
    start_station_id, origin_walk_sec = await find_nearest_station(request.origin[0], request.origin[1])
    end_station_id, dest_walk_sec = await find_nearest_station(request.destination[0], request.destination[1])
    
    # Thời điểm hành khách đến được ga đầu tiên
    actual_start_time = request_time + timedelta(seconds=origin_walk_sec)
    
    # 2. Chạy thuật toán Dijkstra
    path_dijkstra, time_dijkstra = time_dependent_dijkstra(
        graph=graph,
        start_station_id=start_station_id,
        end_station_id=end_station_id,
        start_time=actual_start_time
    )
    
    # 3. Chạy thuật toán A*
    def mock_heuristic(u: str, v: str) -> float:
        # Trong thực tế, bạn sẽ map tọa độ lon/lat của u và v, sau đó tính khoảng cách Haversine / 1.2m/s
        # Tạm thời để 0.0, khi đó A* sẽ chạy chính xác như Dijkstra.
        return 0.0
        
    path_astar, time_astar = time_dependent_astar(
        graph=graph,
        start_station_id=start_station_id,
        end_station_id=end_station_id,
        start_time=actual_start_time,
        heuristic=mock_heuristic
    )
    
    # 4. Ánh xạ dữ liệu và chọn Candidate tốt nhất
    candidate_routes = []
    
    route_dijkstra = _build_route_object(path_dijkstra, origin_walk_sec, dest_walk_sec, start_station_id, end_station_id)
    if route_dijkstra:
        candidate_routes.append((time_dijkstra, route_dijkstra))
        
    route_astar = _build_route_object(path_astar, origin_walk_sec, dest_walk_sec, start_station_id, end_station_id)
    if route_astar:
        candidate_routes.append((time_astar, route_astar))
        
    if not candidate_routes:
        return CoreRoutingOutput(
            status="no_path",
            request=request,
            routes=[]
        )
        
    # Sắp xếp để chọn ra route tốt nhất (thời gian thấp nhất)
    candidate_routes.sort(key=lambda x: x[0])
    
    # Lấy ra path nhanh nhất (cost thấp nhất)
    best_cost, best_route = candidate_routes[0]
    best_route.rank = 1
    best_route.route_id = f"route_1_{uuid.uuid4().hex[:8]}"
    
    return CoreRoutingOutput(
        status="success",
        request=request,
        routes=[best_route],
        computed_candidate_count=1,
        selected_route_id=best_route.route_id
    )