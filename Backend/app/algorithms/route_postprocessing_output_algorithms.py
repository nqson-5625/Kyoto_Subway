
from __future__ import annotations
import json
from datetime import datetime, timedelta, time
from typing import List, Optional, Dict
from pydantic import BaseModel, ConfigDict
from enum import Enum

# --- IMPORT HOẶC ĐỊNH NGHĨA LẠI CÁC SCHEMA CHUẨN ---

class SegmentMode(str, Enum):
    WALK = "walk"
    RIDE = "ride"
    TRANSFER = "transfer"

class RouteStatus(str, Enum):
    SUCCESS = "success"
    FAIL = "fail"

class Coordinate(BaseModel):
    lat: float
    lon: float

class StationRef(BaseModel):
    station_id: str
    station_name: Optional[str] = None

class GraphNodeRef(BaseModel):
    node_id: str
    node_name: Optional[str] = None

class RoutePolyline(BaseModel):
    points: str = ""

class RouteWarning(BaseModel):
    text: str
    severity: str

class CostBreakdown(BaseModel):
    total_cost: float = 0.0
    time_cost: float = 0.0
    transfer_penalty: float = 0.0

# --- CORE ROUTING SCHEMAS (KHỚP CHÍNH XÁC VỚI INPUT CỦA BẠN) ---

class CoreRoutingRequestEcho(BaseModel):
    origin: tuple[float, float]        # (lon, lat)
    destination: tuple[float, float]   # (lon, lat)
    scenario_id: Optional[str] = None
    optimize_for: str = "time"
    model_config = ConfigDict(from_attributes=True)

class WalkEndpoint(BaseModel): 
    graph_node: GraphNodeRef
    station: Optional[StationRef] = None
    model_config = ConfigDict(from_attributes=True)

class CoreRoutingSegment(BaseModel):
    segment_index: int
    mode: SegmentMode
    from_node_id: Optional[int | str] = None
    to_node_id: Optional[int | str] = None
    from_station_id: Optional[str] = None
    to_station_id: Optional[str] = None
    line_id: Optional[str] = None
    trip_id: Optional[str] = None
    direction_id: Optional[int] = None
    distance_m: Optional[float] = None
    base_travel_minutes: Optional[float] = None
    transfer_minutes: Optional[float] = None
    edge_ids: list[int] = []
    transfer_ids: list[int] = []
    path_node_ids: list[int | str] = []
    polyline: Optional[RoutePolyline] = None
    model_config = ConfigDict(from_attributes=True)

class CoreRoutingRoute(BaseModel):
    route_id: str
    rank: int = 1
    entry_station: Optional[StationRef] = None
    exit_station: Optional[StationRef] = None
    origin_walk_target: Optional[WalkEndpoint] = None
    destination_walk_source: Optional[WalkEndpoint] = None
    segments: list[CoreRoutingSegment]
    visited_station_ids: list[str] = []
    visited_line_ids: list[str] = []
    cost_breakdown: CostBreakdown
    warnings: list[RouteWarning] = []
    model_config = ConfigDict(from_attributes=True)

class CoreRoutingOutput(BaseModel):
    status: RouteStatus
    request: CoreRoutingRequestEcho
    routes: list[CoreRoutingRoute] = []
    computed_candidate_count: int = 0
    selected_route_id: Optional[str] = None
    debug: Optional[dict[str, object]] = None
    warnings: list[RouteWarning] = []
    model_config = ConfigDict(from_attributes=True)


# --- ROUTE POST-PROCESSING OUTPUT SCHEMAS ---

class StepInstruction(BaseModel):
    step_index: int 
    mode: SegmentMode 
    title: str 
    description: str 
    from_station: Optional[StationRef] = None 
    to_station: Optional[StationRef] = None 
    line_id: Optional[str] = None 
    trip_id: Optional[str] = None 
    duration_minutes: float = 0.0 
    distance_m: Optional[float] = None 
    polyline: Optional[RoutePolyline] = None 
    model_config = ConfigDict(from_attributes=True)

class ETAStopItem(BaseModel):
    station_id: str 
    station_name: Optional[str] = None 
    scheduled_arrival: Optional[str] = None 
    scheduled_departure: Optional[str] = None 
    predicted_arrival: Optional[str] = None 
    predicted_departure: Optional[str] = None 
    delay_minutes: float = 0.0 
    model_config = ConfigDict(from_attributes=True)

class RouteEvaluation(BaseModel):
    score: float 
    rank: int 
    fewer_transfers_better: Optional[float] = None
    shorter_time_better: Optional[float] = None
    model_config = ConfigDict(from_attributes=True)

class TimeBreakdown(BaseModel):
    walking_minutes: float = 0
    in_vehicle_minutes: float = 0
    transfer_minutes: float = 0
    total_time_minutes: float = 0

class RoutePostprocessingRouteOutput(BaseModel):
    route_id: str 
    is_selected: bool = True 
    summary: str 
    headsign: Optional[str] = None
    entry_station: Optional[StationRef] = None 
    exit_station: Optional[StationRef] = None 
    transfer_count: int = 0 
    ride_segment_count: int = 0 
    walk_segment_count: int = 0 
    time_breakdown: TimeBreakdown 
    instructions: List[StepInstruction] 
    eta_stops: List[ETAStopItem] = [] 
    evaluation: Optional[RouteEvaluation] = None 
    full_polyline: Optional[RoutePolyline] = None
    warnings: List[RouteWarning] = []
    model_config = ConfigDict(from_attributes=True)

class RoutePostprocessingOutput(BaseModel):
    status: RouteStatus
    origin: Coordinate
    destination: Coordinate
    generated_at: Optional[str] = None
    selected_route_id: Optional[str] = None
    routes: List[RoutePostprocessingRouteOutput] = []
    warnings: List[RouteWarning] = []
    model_config = ConfigDict(from_attributes=True)


# --- LOGIC XỬ LÝ CHÍNH ---

def slice_timetable(entries, start_station, end_station):
    entries = sorted(entries, key=lambda x: x.stop_sequence)
    start_idx = next((i for i, e in enumerate(entries) if e.station_id == start_station), None)
    end_idx = next((i for i, e in enumerate(entries) if e.station_id == end_station), None)
    if start_idx is None or end_idx is None: 
        return []
    return entries[start_idx:end_idx + 1]

def build_eta_from_timetable(entries, predicted_map=None):
    base_date = datetime(2000, 1, 1).date()
    result = []
    cumulative_delay = 0.0 
    for e in entries:
        current_delay = float(predicted_map.get(e.station_id, 0)) if predicted_map else 0.0
        cumulative_delay = max(cumulative_delay, current_delay)
        arr_dt = datetime.combine(base_date, e.scheduled_arrival_time)
        dep_dt = datetime.combine(base_date, e.scheduled_departure_time)
        result.append(ETAStopItem(
            station_id=e.station_id,
            station_name=f"Station {e.station_id}",
            scheduled_arrival=arr_dt.strftime("%H:%M:%S"),
            scheduled_departure=dep_dt.strftime("%H:%M:%S"),
            predicted_arrival=(arr_dt + timedelta(minutes=cumulative_delay)).strftime("%H:%M:%S"),
            predicted_departure=(dep_dt + timedelta(minutes=cumulative_delay)).strftime("%H:%M:%S"),
            delay_minutes=cumulative_delay
        ))
    return result

def build_route_from_core(
    core_route: CoreRoutingRoute, 
    trip_map: Dict, 
    predicted_map: Optional[Dict] = None,
    is_selected: bool = False
) -> RoutePostprocessingRouteOutput:
    
    def parse_polyline(poly_obj) -> Optional[RoutePolyline]:
        if not poly_obj:
            return None
            
        # Nếu object mang mảng `coordinates` (từ CoreRouting, chứa list các class Coordinate)
        if hasattr(poly_obj, 'coordinates') and poly_obj.coordinates:
            # Trích xuất thuộc tính .lat và .lon ra thành mảng array thô
            raw_coords_list = [[c.lat, c.lon] for c in poly_obj.coordinates]
            return RoutePolyline(points=json.dumps(raw_coords_list))
            
        # Nếu object mang sẵn chuỗi `points`
        if hasattr(poly_obj, 'points') and poly_obj.points is not None:
            return RoutePolyline(points=poly_obj.points)
            
        return None
    # ---------------------------------------------

    instructions = []
    full_eta_stops = []
    current_time_dt = datetime(2000, 1, 1, 8, 0, 0)
    
    ride_count = 0
    walk_count = 0
    transfer_count = 0

    sorted_segments = sorted(core_route.segments, key=lambda x: x.segment_index)

    for seg in sorted_segments:
        # Xử lý an toàn polyline trước khi gắn vào StepInstruction
        safe_polyline = parse_polyline(seg.polyline)

        if seg.mode == SegmentMode.WALK:
            walk_count += 1
            dur = float(seg.base_travel_minutes or 0)
            instructions.append(StepInstruction(
                step_index=seg.segment_index, 
                mode=seg.mode, 
                title="Walk",
                description=f"Walk from {seg.from_node_id or seg.from_station_id} to {seg.to_node_id or seg.to_station_id}",
                duration_minutes=dur,
                distance_m=seg.distance_m,
                polyline=safe_polyline # SỬ DỤNG BIẾN ĐÃ XỬ LÝ
            ))
            current_time_dt += timedelta(minutes=dur)

        elif seg.mode == SegmentMode.RIDE:
            ride_count += 1
            trip = trip_map.get(seg.trip_id)
            ride_dur = float(seg.base_travel_minutes or 0) 
            
            # ... (Đoạn mã xử lý ETA giữ nguyên) ...
            
            instructions.append(StepInstruction(
                step_index=seg.segment_index, 
                mode=seg.mode, 
                title=f"Line {seg.line_id or 'Unknown'}",
                description=f"Ride from {seg.from_station_id} to {seg.to_station_id}",
                from_station=StationRef(station_id=seg.from_station_id) if seg.from_station_id else None,
                to_station=StationRef(station_id=seg.to_station_id) if seg.to_station_id else None,
                line_id=seg.line_id, 
                trip_id=seg.trip_id,
                duration_minutes=ride_dur,
                distance_m=seg.distance_m,
                polyline=safe_polyline # SỬ DỤNG BIẾN ĐÃ XỬ LÝ
            ))

        elif seg.mode == SegmentMode.TRANSFER:
            transfer_count += 1
            dur = float(seg.transfer_minutes or 0)
            instructions.append(StepInstruction(
                step_index=seg.segment_index, 
                mode=seg.mode, 
                title="Transfer",
                description=f"Transfer at station {seg.from_station_id or ''}",
                duration_minutes=dur,
                distance_m=seg.distance_m,
                polyline=safe_polyline # SỬ DỤNG BIẾN ĐÃ XỬ LÝ
            ))
            current_time_dt += timedelta(minutes=dur)

    walk_total = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.WALK)
    ride_total = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.RIDE)
    trans_total = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.TRANSFER)
    total_time = walk_total + ride_total + trans_total

    return RoutePostprocessingRouteOutput(
        route_id=core_route.route_id,
        is_selected=is_selected,
        summary=f"Total {total_time:.1f} min",
        entry_station=core_route.entry_station,
        exit_station=core_route.exit_station,
        transfer_count=transfer_count,
        ride_segment_count=ride_count,
        walk_segment_count=walk_count,
        time_breakdown=TimeBreakdown(
            walking_minutes=walk_total, 
            in_vehicle_minutes=ride_total, 
            transfer_minutes=trans_total,
            total_time_minutes=total_time
        ),
        instructions=instructions,
        eta_stops=full_eta_stops,
        evaluation=RouteEvaluation(score=100.0 - core_route.cost_breakdown.total_cost, rank=core_route.rank),
        warnings=core_route.warnings
    )


# --- WRAPPER CHÍNH (ĐÃ ĐƯỢC SỬA ĐỂ NHẬN CORE_OUTPUT CHUẨN) ---

def get_final_output(core_output: CoreRoutingOutput, trip_map: Dict, predicted_map: Dict) -> RoutePostprocessingOutput:
    processed_routes = []
    
    # Duyệt trực tiếp qua mảng `routes` của object đầu vào CoreRoutingOutput
    for cr in core_output.routes:
        # Kiểm tra xem route hiện tại có phải route được Core chọn tốt nhất không
        is_selected = (core_output.selected_route_id == cr.route_id)
        processed_routes.append(build_route_from_core(cr, trip_map, predicted_map, is_selected=is_selected))
    
    # Map đúng cấu trúc (lon, lat) từ RequestEcho sang dạng Class Coordinate của đầu ra
    origin_coord = Coordinate(lon=core_output.request.origin[0], lat=core_output.request.origin[1])
    dest_coord = Coordinate(lon=core_output.request.destination[0], lat=core_output.request.destination[1])
    
    return RoutePostprocessingOutput(
        status=core_output.status,
        origin=origin_coord,
        destination=dest_coord,
        generated_at=datetime.now().isoformat(),
        selected_route_id=core_output.selected_route_id,
        routes=processed_routes,
        warnings=core_output.warnings
    )


# from datetime import time
# import json

# # ====== IMPORT toàn bộ hàm + schema của bạn ở trên ======
# # giả sử bạn đã paste toàn bộ code schema + logic ở trên file này

# # =========================
# # MOCK TIMETABLE (giống DB thật)
# # =========================
# class MockTimetableEntry:
#     def __init__(self, station_id, seq, arr, dep):
#         self.station_id = station_id
#         self.stop_sequence = seq
#         self.scheduled_arrival_time = arr
#         self.scheduled_departure_time = dep


# class MockTrip:
#     def __init__(self):
#         self.trip_id = "T1"
#         self.timetable_entries = [
#             MockTimetableEntry("K01", 1, time(8, 0), time(8, 1)),
#             MockTimetableEntry("K02", 2, time(8, 3), time(8, 3)),
#             MockTimetableEntry("K03", 3, time(8, 6), time(8, 6)),
#             MockTimetableEntry("K04", 4, time(8, 9), time(8, 9)),
#         ]


# trip_map = {
#     "T1": MockTrip()
# }

# predicted_map = {
#     "K01": 0,
#     "K02": 2.0,
#     "K03": 4.0,
#     "K04": 1.0
# }

# # =========================
# # CORE ROUTING MOCK INPUT
# # =========================
# mock_core_output = CoreRoutingOutput(
#     status=RouteStatus.SUCCESS,
#     request=CoreRoutingRequestEcho(
#         origin=(135.785171, 35.063612),
#         destination=(135.758505, 34.987082),
#         optimize_for="time"
#     ),
#     routes=[
#         CoreRoutingRoute(
#             route_id="ROUTE_1",
#             rank=1,
#             entry_station=StationRef(station_id="K01", station_name="Kokusaikaikan"),
#             exit_station=StationRef(station_id="K03", station_name="Kitayama"),
#             segments=[
#                 CoreRoutingSegment(
#                     segment_index=1,
#                     mode=SegmentMode.WALK,
#                     from_node_id="W_START",
#                     to_node_id="N_K01",
#                     base_travel_minutes=4
#                 ),
#                 CoreRoutingSegment(
#                     segment_index=2,
#                     mode=SegmentMode.RIDE,
#                     from_station_id="K01",
#                     to_station_id="K03",
#                     trip_id="T1",
#                     line_id="karasuma",
#                     base_travel_minutes=6
#                 ),
#                 CoreRoutingSegment(
#                     segment_index=3,
#                     mode=SegmentMode.TRANSFER,
#                     from_station_id="K03",
#                     to_station_id="K03",
#                     transfer_minutes=2
#                 ),
#                 CoreRoutingSegment(
#                     segment_index=4,
#                     mode=SegmentMode.WALK,
#                     from_node_id="N_K03",
#                     to_node_id="DEST",
#                     base_travel_minutes=3
#                 )
#             ],
#             cost_breakdown=CostBreakdown(
#                 total_cost=11.0,
#                 time_cost=11.0,
#                 transfer_penalty=1.0
#             ),
#             warnings=[]
#         )
#     ],
#     computed_candidate_count=1,
#     selected_route_id="ROUTE_1",
#     warnings=[]
# )

# # =========================
# # RUN TEST
# # =========================
# if __name__ == "__main__":
#     result = get_final_output(
#         core_output=mock_core_output,
#         trip_map=trip_map,
#         predicted_map=predicted_map
#     )

#     print(json.dumps(result.model_dump(), indent=2, ensure_ascii=False))