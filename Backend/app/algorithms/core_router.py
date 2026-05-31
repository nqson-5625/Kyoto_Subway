# File: Backend/app/algorithms/core_router.py
import uuid
import json
from datetime import datetime, timedelta
from typing import Tuple, List, Any, Optional
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.schemas.algorithm.core_routing_output import (
    CoreRoutingOutput, CoreRoutingRequestEcho, CoreRoutingRoute, CoreRoutingSegment, RoutePolyline
)
from app.schemas.algorithm.routing_common import Coordinate, CostBreakdown
from app.schemas.algorithm.enums import SegmentMode
from app.algorithms.graph_builder import TransitGraph, RideEdge, TransferEdge
from app.algorithms.dijkstra import time_dependent_dijkstra
from app.algorithms.astar import time_dependent_astar

from app.services.walking_service import walking_service

def get_all_station_coords(db: Session) -> dict:
    sql = text("SELECT station_id, ST_Y(geom) as lat, ST_X(geom) as lon FROM stations WHERE is_active = TRUE;")
    rows = db.execute(sql).fetchall()
    return {row[0]: [row[1], row[2]] for row in rows}

def get_all_edge_geometries(db: Session) -> dict:
    """Tải toàn bộ polyline đường ray một lần để tránh lỗi N+1 Query"""
    sql = text("SELECT from_station_id, to_station_id, ST_AsGeoJSON(geom) as geojson FROM edges WHERE is_active = TRUE;")
    rows = db.execute(sql).fetchall()
    geo_map = {}
    
    for row in rows:
        if row.geojson:
            parsed = json.loads(row.geojson)
            coords = parsed.get("coordinates", [])
            if coords:
                geo_map[(row.from_station_id, row.to_station_id)] = coords
                geo_map[(row.to_station_id, row.from_station_id)] = list(reversed(coords))
                
    return geo_map

def _build_route_object(path_edges, origin_walk_sec, dest_walk_sec, start_station_id, end_station_id, origin_coords, dest_coords, station_coords, edge_geometries):
    if path_edges is None and start_station_id != end_station_id:
        return None
        
    def to_coordinates(coords_list, is_geojson=False) -> list[Coordinate]:
        """Ép kiểu toạ độ mảng thô sang class Coordinate"""
        if not coords_list: return []
        if is_geojson:
            return [Coordinate(lat=pt[1], lon=pt[0]) for pt in coords_list if len(pt) >= 2]
        return [Coordinate(lat=pt[0], lon=pt[1]) for pt in coords_list if len(pt) >= 2]

    segments = []
    idx = 1
    total_cost_min = (origin_walk_sec + dest_walk_sec) / 60.0
    transfer_penalty = 0.0
    
    # 1. Chặng đi bộ đầu
    segments.append(CoreRoutingSegment(
        segment_index=idx, mode=SegmentMode.WALK,
        from_node_id="START_POINT", to_node_id=start_station_id,
        from_station_id=None, to_station_id=start_station_id,
        base_travel_minutes=origin_walk_sec / 60.0,
        polyline=RoutePolyline(coordinates=to_coordinates(origin_coords, is_geojson=False)),
        edge_ids=[], transfer_ids=[], path_node_ids=[]
    ))
    idx += 1
    
    # 2. Các chặng đi tàu và chuyển tuyến
    if path_edges:
        for edge in path_edges:
            geom_coords = edge_geometries.get((edge.from_station, edge.to_station))
            
            if geom_coords:
                final_coords = to_coordinates(geom_coords, is_geojson=True)
            else:
                pt1 = station_coords.get(edge.from_station)
                pt2 = station_coords.get(edge.to_station)
                final_coords = []
                if pt1 and pt2:
                    final_coords = [Coordinate(lat=pt1[0], lon=pt1[1]), Coordinate(lat=pt2[0], lon=pt2[1])]
            
            if isinstance(edge, RideEdge):
                segments.append(CoreRoutingSegment(
                    segment_index=idx, mode=SegmentMode.RIDE,
                    from_node_id=edge.from_station, to_node_id=edge.to_station,
                    from_station_id=edge.from_station, to_station_id=edge.to_station,
                    line_id=edge.line_id, base_travel_minutes=edge.travel_seconds / 60.0,
                    polyline=RoutePolyline(coordinates=final_coords),
                    edge_ids=[], transfer_ids=[], path_node_ids=[]
                ))
                total_cost_min += edge.travel_seconds / 60.0
            elif isinstance(edge, TransferEdge):
                segments.append(CoreRoutingSegment(
                    segment_index=idx, mode=SegmentMode.TRANSFER,
                    from_node_id=edge.from_station, to_node_id=edge.to_station,
                    from_station_id=edge.from_station, to_station_id=edge.to_station,
                    transfer_minutes=edge.travel_seconds / 60.0,
                    polyline=RoutePolyline(coordinates=final_coords),
                    edge_ids=[], transfer_ids=[], path_node_ids=[]
                ))
                total_cost_min += edge.travel_seconds / 60.0
                transfer_penalty += edge.travel_seconds / 60.0
            idx += 1
        
    # 3. Chặng đi bộ cuối cùng
    segments.append(CoreRoutingSegment(
        segment_index=idx, mode=SegmentMode.WALK,
        from_node_id=end_station_id, to_node_id="END_POINT",
        from_station_id=end_station_id, to_station_id=None,
        base_travel_minutes=dest_walk_sec / 60.0,
        polyline=RoutePolyline(coordinates=to_coordinates(dest_coords, is_geojson=False)),
        edge_ids=[], transfer_ids=[], path_node_ids=[]
    ))
    
    return CoreRoutingRoute(
        route_id=f"route_{uuid.uuid4().hex[:8]}", rank=1, segments=segments,
        cost_breakdown=CostBreakdown(total_cost=total_cost_min, time_cost=total_cost_min, transfer_penalty=transfer_penalty),
        visited_station_ids=[], visited_line_ids=[], warnings=[]
    )

async def process_routing_request(
    request: CoreRoutingRequestEcho, graph: TransitGraph, request_time: datetime, db: Session, algorithm: str = "dijkstra"
) -> CoreRoutingOutput:
    
    start_station_id, origin_walk_sec, origin_coords = walking_service.find_nearest_station_path(request.origin[0], request.origin[1])
    end_station_id, dest_walk_sec, dest_coords = walking_service.find_nearest_station_path(request.destination[0], request.destination[1])
    dest_coords.reverse()
    
    actual_start_time = request_time + timedelta(seconds=origin_walk_sec)
    if start_station_id == end_station_id:
        path, time_cost = [], 0.0
    else:
        if algorithm == "astar":
            def heuristic(u, v): return 0.0 
            path, time_cost = time_dependent_astar(graph, start_station_id, end_station_id, actual_start_time, heuristic)
        else:
            path, time_cost = time_dependent_dijkstra(graph, start_station_id, end_station_id, actual_start_time)
            
    if path is None:
        return CoreRoutingOutput(status="no_route", request=request, routes=[])
        
    station_coords = get_all_station_coords(db)
    edge_geometries = get_all_edge_geometries(db) 
    
    route_obj = _build_route_object(path, origin_walk_sec, dest_walk_sec, start_station_id, end_station_id, origin_coords, dest_coords, station_coords, edge_geometries)
    
    if not route_obj:
        return CoreRoutingOutput(status="no_route", request=request, routes=[])
        
    return CoreRoutingOutput(
        status="success", request=request, routes=[route_obj],
        computed_candidate_count=1, selected_route_id=route_obj.route_id
    )