
# # from __future__ import annotations
# # from datetime import datetime, timedelta, time
# # from pydantic import BaseModel, ConfigDict

# # from app.schemas.algorithm.enums import SegmentMode, RouteStatus
# # from app.schemas.algorithm.routing_common import Coordinate, RoutePolyline, RouteWarning, StationRef, TimeBreakdown


# # class StepInstruction(BaseModel):
# #     step_index: int 
# #     mode: SegmentMode 
# #     title: str 
# #     description: str 
# #     from_station: StationRef | None = None 
# #     to_station: StationRef | None = None 
# #     line_id: str | None = None 
# #     trip_id: str | None = None 
# #     duration_minutes: float | None = None 
# #     distance_m: float | None = None 
# #     polyline: RoutePolyline | None = None 
# #     model_config = ConfigDict(from_attributes=True)

# # class ETAStopItem(BaseModel):
# #     station_id: str 
# #     station_name: str | None = None 
# #     scheduled_arrival: str | None = None 
# #     scheduled_departure: str | None = None 
# #     predicted_arrival: str | None = None 
# #     predicted_departure: str | None = None 
# #     delay_minutes: float | None = None 
# #     model_config = ConfigDict(from_attributes=True)

# # class RouteEvaluation(BaseModel):
# #     score: float 
# #     rank: int 
# #     fewer_transfers_better: float | None = None 
# #     shorter_time_better: float | None = None 
# #     less_walking_better: float | None = None 
# #     less_disruption_better: float | None = None 
# #     model_config = ConfigDict(from_attributes=True)

# # class RoutePostprocessingRouteOutput(BaseModel):
# #     route_id: str 
# #     is_selected: bool = True 
# #     summary: str 
# #     headsign: str | None = None 
# #     entry_station: StationRef | None = None 
# #     exit_station: StationRef | None = None 
# #     transfer_count: int = 0 
# #     ride_segment_count: int = 0 
# #     walk_segment_count: int = 0 
# #     time_breakdown: TimeBreakdown 
# #     instructions: list[StepInstruction] 
# #     eta_stops: list[ETAStopItem] = [] 
# #     evaluation: RouteEvaluation | None = None 
# #     full_polyline: RoutePolyline | None = None 
# #     warnings: list[RouteWarning] = [] 
# #     model_config = ConfigDict(from_attributes=True)



# # def slice_timetable(entries, start_station, end_station):
# #     entries = sorted(entries, key=lambda x: x.stop_sequence)
# #     start_idx = next((i for i, e in enumerate(entries) if e.station_id == start_station), None)
# #     end_idx = next((i for i, e in enumerate(entries) if e.station_id == end_station), None)
# #     if start_idx is None or end_idx is None:
# #         return []
# #     return entries[start_idx:end_idx + 1]

# # def build_eta_from_timetable(entries, predicted_map=None):
# #     base = datetime(2000, 1, 1)
# #     result = []
# #     cumulative_delay = 0.0 # Khởi tạo delay tích lũy

# #     for e in entries:
# #         # Lấy delay cụ thể của ga này (nếu có), nếu không giữ delay từ ga trước
# #         current_delay = predicted_map.get(e.station_id, 0) if predicted_map else 0
# #         cumulative_delay = max(cumulative_delay, float(current_delay))

# #         arr = base.replace(hour=e.scheduled_arrival_time.hour, minute=e.scheduled_arrival_time.minute, second=e.scheduled_arrival_time.second)
# #         dep = base.replace(hour=e.scheduled_departure_time.hour, minute=e.scheduled_departure_time.minute, second=e.scheduled_departure_time.second)

# #         result.append(
# #             ETAStopItem(
# #                 station_id=e.station_id,
# #                 scheduled_arrival=arr.strftime("%H:%M:%S"),
# #                 scheduled_departure=dep.strftime("%H:%M:%S"),
# #                 predicted_arrival=(arr + timedelta(minutes=cumulative_delay)).strftime("%H:%M:%S"),
# #                 predicted_departure=(dep + timedelta(minutes=cumulative_delay)).strftime("%H:%M:%S"),
# #                 delay_minutes=cumulative_delay
# #             )
# #         )
# #     return result

# # def build_route_from_core(core_route, trip_map, predicted_map=None):
# #     instructions = []
# #     full_eta_stops = []
# #     base_time = datetime(2000, 1, 1, 8, 0)
# #     current_time = base_time

# #     for i, seg in enumerate(core_route.segments):
# #         # --- WALK ---
# #         if seg.mode == SegmentMode.WALK:
# #             duration = float(seg.base_travel_minutes or 0)
# #             instructions.append(
# #                 StepInstruction(
# #                     step_index=i + 1,
# #                     mode=seg.mode,
# #                     title="Walk",
# #                     description=f"Walk from {seg.from_station_id} to {seg.to_station_id}",
# #                     duration_minutes=duration
# #                 )
# #             )
# #             current_time += timedelta(minutes=duration)

# #         # --- TRANSFER ---
# #         elif seg.mode == SegmentMode.TRANSFER:
# #             duration = float(seg.transfer_minutes or 0)
# #             instructions.append(
# #                 StepInstruction(
# #                     step_index=i + 1,
# #                     mode=seg.mode,
# #                     title="Transfer",
# #                     description="Transfer to another line",
# #                     duration_minutes=duration
# #                 )
# #             )
# #             current_time += timedelta(minutes=duration)

# #         # --- RIDE ---
# #         elif seg.mode == SegmentMode.RIDE:
# #             trip = trip_map.get(seg.trip_id)
# #             if not trip: continue

# #             eta_stops = slice_timetable(trip.timetable_entries, seg.from_station_id, seg.to_station_id)
# #             processed_etas = build_eta_from_timetable(eta_stops, predicted_map)
# #             if not processed_etas: continue

# #             # Đồng bộ thời gian thực tế vào hành trình (Shift time)
# #             first_dep_dt = datetime.strptime(processed_etas[0].scheduled_departure, "%H:%M:%S")
# #             first_dep_dt = base_time.replace(hour=first_dep_dt.hour, minute=first_dep_dt.minute, second=first_dep_dt.second)
# #             shift = current_time - first_dep_dt

# #             for stop in processed_etas:
# #                 for attr in ['scheduled_arrival', 'scheduled_departure', 'predicted_arrival', 'predicted_departure']:
# #                     t_dt = datetime.strptime(getattr(stop, attr), "%H:%M:%S")
# #                     new_t = (base_time.replace(hour=t_dt.hour, minute=t_dt.minute, second=t_dt.second) + shift).strftime("%H:%M:%S")
# #                     setattr(stop, attr, new_t)
# #                 full_eta_stops.append(stop)

# #             # Tính thời gian chặng Ride (từ lúc đi ga đầu đến lúc tới ga cuối)
# #             ride_start = datetime.strptime(processed_etas[0].predicted_departure, "%H:%M:%S")
# #             ride_end = datetime.strptime(processed_etas[-1].predicted_arrival, "%H:%M:%S")
# #             ride_duration = (ride_end - ride_start).total_seconds() / 60
# #             if ride_duration < 0: ride_duration += 1440 # Xử lý qua đêm

# #             instructions.append(
# #                 StepInstruction(
# #                     step_index=i + 1,
# #                     mode=seg.mode,
# #                     title=f"Take line {seg.line_id}",
# #                     description=f"{seg.from_station_id} → {seg.to_station_id}",
# #                     from_station=StationRef(station_id=seg.from_station_id),
# #                     to_station=StationRef(station_id=seg.to_station_id),
# #                     line_id=seg.line_id,
# #                     trip_id=seg.trip_id,
# #                     duration_minutes=ride_duration
# #                 )
# #             )
# #             current_time = base_time.replace(hour=ride_end.hour, minute=ride_end.minute, second=ride_end.second)

# #     # --- TÍNH TOÁN CUỐI CÙNG ---
# #     walking_m = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.WALK)
# #     riding_m = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.RIDE)
# #     transfer_m = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.TRANSFER)
# #     total_m = walking_m + riding_m + transfer_m

# #     # return RoutePostprocessingRouteOutput(
# #     #     route_id=core_route.route_id,
# #     #     summary=f"Total: {total_m:.1f} min ({int(riding_m)} min riding)",
# #     #     entry_station=core_route.entry_station,
# #     #     exit_station=core_route.exit_station,
# #     #     transfer_count=sum(1 for s in core_route.segments if s.mode == SegmentMode.TRANSFER),
# #     #     ride_segment_count=sum(1 for s in core_route.segments if s.mode == SegmentMode.RIDE),
# #     #     walk_segment_count=sum(1 for s in core_route.segments if s.mode == SegmentMode.WALK),
# #     #     time_breakdown=TimeBreakdown(
# #     #         walking_minutes=walking_m,
# #     #         in_vehicle_minutes=riding_m,
# #     #         transfer_minutes=transfer_m,
# #     #         total_time_minutes=total_m
# #     #     ),
# #     #     instructions=instructions,
# #     #     eta_stops=full_eta_stops
# #     # )
# # # Sửa lại hàm build_route_from_core ở đoạn return để an toàn hơn
# #     return RoutePostprocessingRouteOutput(
# #         route_id=str(core_route.route_id),
# #         summary=f"Total: {total_m:.1f} min ({int(riding_m)} min riding)",
# #         # Đảm bảo đây là Pydantic model hoặc None
# #         entry_station=core_route.entry_station if isinstance(core_route.entry_station, StationRef) else None,
# #         exit_station=core_route.exit_station if isinstance(core_route.exit_station, StationRef) else None,
# #         transfer_count=sum(1 for s in core_route.segments if s.mode == SegmentMode.TRANSFER),
# #         ride_segment_count=sum(1 for s in core_route.segments if s.mode == SegmentMode.RIDE),
# #         walk_segment_count=sum(1 for s in core_route.segments if s.mode == SegmentMode.WALK),
# #         time_breakdown=TimeBreakdown(
# #             walking_minutes=walking_m,
# #             in_vehicle_minutes=riding_m,
# #             transfer_minutes=transfer_m,
# #             total_time_minutes=total_m
# #         ),
# #         instructions=instructions,
# #         eta_stops=full_eta_stops
# #     )
# # # [Phần Fake Classes để TEST giữ nguyên như cũ của bạn là chạy được]



# # # ===== TEST =====
# # class FakeEntry:
# #     def __init__(self, station_id, seq, h, m):
# #         self.station_id = station_id
# #         self.stop_sequence = seq
# #         self.scheduled_arrival_time = time(h, m)
# #         self.scheduled_departure_time = time(h, m)
# #         self.scheduled_arrival_day_offset = 0
# #         self.scheduled_departure_day_offset = 0


# # class FakeTrip:
# #     def __init__(self):
# #         self.trip_id = "T1"
# #         self.line_id = "L1"
# #         self.timetable_entries = [
# #             FakeEntry("A", 1, 8, 0),
# #             FakeEntry("B", 2, 8, 5),
# #             FakeEntry("C", 3, 8, 10),
# #             FakeEntry("D", 4, 8, 15),
# #         ]


# # class FakeSeg:
# #     def __init__(self, mode, fs, ts, trip_id=None):
# #         self.mode = mode
# #         self.from_station_id = fs
# #         self.to_station_id = ts
# #         self.trip_id = trip_id
# #         self.line_id = "L1"
# #         self.base_travel_minutes = 5
# #         self.transfer_minutes = 3


# # class FakeRoute:
# #     def __init__(self):
# #         self.route_id = "R1"
# #         self.segments = [
# #             FakeSeg(SegmentMode.WALK, "HOME", "B"),
# #             FakeSeg(SegmentMode.RIDE, "B", "D", "T1")
# #         ]
# #         self.entry_station = StationRef(station_id="B")
# #         self.exit_station = StationRef(station_id="D")


# # trip_map = {"T1": FakeTrip()}
# # core_route = FakeRoute()

# # result = build_route_from_core(core_route, trip_map, {"C": 3})

# # print(result.model_dump())


# from __future__ import annotations
# import json
# from datetime import datetime, timedelta, time
# from typing import List, Optional, Dict
# from pydantic import BaseModel, ConfigDict

# # --- MOCK SCHEMAS (Để chạy được ngay nếu bạn copy ra file riêng) ---
# from enum import Enum

# class SegmentMode(str, Enum):
#     WALK = "walk"
#     RIDE = "ride"
#     TRANSFER = "transfer"

# class StationRef(BaseModel):
#     station_id: str
#     station_name: Optional[str] = None

# class TimeBreakdown(BaseModel):
#     walking_minutes: float = 0
#     in_vehicle_minutes: float = 0
#     transfer_minutes: float = 0
#     total_time_minutes: float = 0

# class RoutePolyline(BaseModel):
#     points: str = ""

# class RouteWarning(BaseModel):
#     text: str
#     severity: str

# # --- CÁC CLASS BẠN ĐÃ CUNG CẤP ---

# class StepInstruction(BaseModel):
#     step_index: int 
#     mode: SegmentMode 
#     title: str 
#     description: str 
#     from_station: Optional[StationRef] = None 
#     to_station: Optional[StationRef] = None 
#     line_id: Optional[str] = None 
#     trip_id: Optional[str] = None 
#     duration_minutes: float = 0.0 
#     distance_m: Optional[float] = None 
#     polyline: Optional[RoutePolyline] = None 
#     model_config = ConfigDict(from_attributes=True)

# class ETAStopItem(BaseModel):
#     station_id: str 
#     station_name: Optional[str] = None 
#     scheduled_arrival: Optional[str] = None 
#     scheduled_departure: Optional[str] = None 
#     predicted_arrival: Optional[str] = None 
#     predicted_departure: Optional[str] = None 
#     delay_minutes: float = 0.0 
#     model_config = ConfigDict(from_attributes=True)

# class RouteEvaluation(BaseModel):
#     score: float 
#     rank: int 
#     model_config = ConfigDict(from_attributes=True)

# class RoutePostprocessingRouteOutput(BaseModel):
#     route_id: str 
#     is_selected: bool = True 
#     summary: str 
#     entry_station: Optional[StationRef] = None 
#     exit_station: Optional[StationRef] = None 
#     transfer_count: int = 0 
#     ride_segment_count: int = 0 
#     walk_segment_count: int = 0 
#     time_breakdown: TimeBreakdown 
#     instructions: List[StepInstruction] 
#     eta_stops: List[ETAStopItem] = [] 
#     evaluation: Optional[RouteEvaluation] = None 
#     model_config = ConfigDict(from_attributes=True)

# # --- LOGIC XỬ LÝ ---

# def slice_timetable(entries, start_station, end_station):
#     entries = sorted(entries, key=lambda x: x.stop_sequence)
#     start_idx = next((i for i, e in enumerate(entries) if e.station_id == start_station), None)
#     end_idx = next((i for i, e in enumerate(entries) if e.station_id == end_station), None)
#     if start_idx is None or end_idx is None:
#         return []
#     return entries[start_idx:end_idx + 1]

# def build_eta_from_timetable(entries, predicted_map=None):
#     base_date = datetime(2000, 1, 1).date()
#     result = []
#     cumulative_delay = 0.0 

#     for e in entries:
#         current_delay = float(predicted_map.get(e.station_id, 0)) if predicted_map else 0.0
#         cumulative_delay = max(cumulative_delay, current_delay)

#         # Kết hợp date và time để tính toán
#         arr_dt = datetime.combine(base_date, e.scheduled_arrival_time)
#         dep_dt = datetime.combine(base_date, e.scheduled_departure_time)

#         result.append(
#             ETAStopItem(
#                 station_id=e.station_id,
#                 station_name=f"Ga {e.station_id}",
#                 scheduled_arrival=arr_dt.strftime("%H:%M:%S"),
#                 scheduled_departure=dep_dt.strftime("%H:%M:%S"),
#                 predicted_arrival=(arr_dt + timedelta(minutes=cumulative_delay)).strftime("%H:%M:%S"),
#                 predicted_departure=(dep_dt + timedelta(minutes=cumulative_delay)).strftime("%H:%M:%S"),
#                 delay_minutes=cumulative_delay
#             )
#         )
#     return result

# def build_route_from_core(core_route, trip_map, predicted_map=None):
#     instructions = []
#     full_eta_stops = []
#     # Giả định bắt đầu hành trình lúc 8:00 sáng
#     current_time_dt = datetime(2000, 1, 1, 8, 0, 0)

#     for i, seg in enumerate(core_route.segments):
#         # WALK
#         if seg.mode == SegmentMode.WALK:
#             dur = float(seg.base_travel_minutes or 0)
#             instructions.append(StepInstruction(
#                 step_index=i + 1, mode=seg.mode, title="Walk",
#                 description=f"Walk from {seg.from_station_id} to {seg.to_station_id}",
#                 duration_minutes=dur
#             ))
#             current_time_dt += timedelta(minutes=dur)

#         # RIDE
#         elif seg.mode == SegmentMode.RIDE:
#             trip = trip_map.get(seg.trip_id)
#             if not trip: continue

#             eta_entries = slice_timetable(trip.timetable_entries, seg.from_station_id, seg.to_station_id)
#             processed_etas = build_eta_from_timetable(eta_entries, predicted_map)
            
#             if processed_etas:
#                 full_eta_stops.extend(processed_etas)
#                 # Tính thời gian tàu chạy thực tế (từ ga đầu đến ga cuối)
#                 start_ride = datetime.strptime(processed_etas[0].predicted_departure, "%H:%M:%S")
#                 end_ride = datetime.strptime(processed_etas[-1].predicted_arrival, "%H:%M:%S")
#                 ride_dur = (end_ride - start_ride).total_seconds() / 60
#                 if ride_dur < 0: ride_dur += 1440

#                 instructions.append(StepInstruction(
#                     step_index=i + 1, mode=seg.mode, title=f"Line {seg.line_id}",
#                     description=f"{seg.from_station_id} -> {seg.to_station_id}",
#                     from_station=StationRef(station_id=seg.from_station_id),
#                     to_station=StationRef(station_id=seg.to_station_id),
#                     line_id=seg.line_id, trip_id=seg.trip_id,
#                     duration_minutes=ride_dur
#                 ))
#                 current_time_dt = current_time_dt.replace(hour=end_ride.hour, minute=end_ride.minute)

#     # Tổng hợp
#     walk_total = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.WALK)
#     ride_total = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.RIDE)
#     total = walk_total + ride_total

#     return RoutePostprocessingRouteOutput(
#         route_id=core_route.route_id,
#         summary=f"Total {total:.1f} min",
#         entry_station=core_route.entry_station,
#         exit_station=core_route.exit_station,
#         time_breakdown=TimeBreakdown(
#             walking_minutes=walk_total, 
#             in_vehicle_minutes=ride_total, 
#             total_time_minutes=total
#         ),
#         instructions=instructions,
#         eta_stops=full_eta_stops
#     )

# # --- PHẦN TEST ---

# class FakeEntry:
#     def __init__(self, sid, seq, h, m):
#         self.station_id = sid
#         self.stop_sequence = seq
#         self.scheduled_arrival_time = time(h, m)
#         self.scheduled_departure_time = time(h, m)

# class FakeTrip:
#     def __init__(self):
#         self.trip_id = "T1"
#         self.timetable_entries = [
#             FakeEntry("A", 1, 8, 0), FakeEntry("B", 2, 8, 5),
#             FakeEntry("C", 3, 8, 10), FakeEntry("D", 4, 8, 15)
#         ]

# class FakeSeg:
#     def __init__(self, mode, fs, ts, tid=None):
#         self.mode = mode
#         self.from_station_id = fs
#         self.to_station_id = ts
#         self.trip_id = tid
#         self.line_id = "L1"
#         self.base_travel_minutes = 5

# class FakeRoute:
#     def __init__(self):
#         self.route_id = "R1"
#         self.segments = [
#             FakeSeg(SegmentMode.WALK, "HOME", "B"),
#             FakeSeg(SegmentMode.RIDE, "B", "D", "T1")
#         ]
#         self.entry_station = StationRef(station_id="B")
#         self.exit_station = StationRef(station_id="D")

# if __name__ == "__main__":
#     trip_map = {"T1": FakeTrip()}
#     core_route = FakeRoute()
#     # Test với delay 3 phút tại ga C
#     result = build_route_from_core(core_route, trip_map, {"C": 3})
    
#     print(json.dumps(result.model_dump(), indent=2))

from __future__ import annotations
import json
from datetime import datetime, timedelta, time
from typing import List, Optional, Dict
from pydantic import BaseModel, ConfigDict

# --- IMPORT SCHEMAS (Giả định bạn đã sửa file __init__.py như hướng dẫn trước) ---
# Ở đây tôi dùng Mock để bạn có thể chạy test độc lập ngay lập tức
from enum import Enum

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

class TimeBreakdown(BaseModel):
    walking_minutes: float = 0
    in_vehicle_minutes: float = 0
    transfer_minutes: float = 0
    total_time_minutes: float = 0

class RoutePolyline(BaseModel):
    points: str = ""

class RouteWarning(BaseModel):
    text: str
    severity: str

# --- CÁC CLASS OUTPUT THEO YÊU CẦU ---

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
    if start_idx is None or end_idx is None: return []
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

def build_route_from_core(core_route, trip_map, predicted_map=None) -> RoutePostprocessingRouteOutput:
    instructions = []
    full_eta_stops = []
    current_time_dt = datetime(2000, 1, 1, 8, 0, 0)
    
    ride_count = 0
    walk_count = 0
    transfer_count = 0

    for i, seg in enumerate(core_route.segments):
        if seg.mode == SegmentMode.WALK:
            walk_count += 1
            dur = float(seg.base_travel_minutes or 0)
            instructions.append(StepInstruction(
                step_index=i + 1, mode=seg.mode, title="Walk",
                description=f"Walk from {seg.from_station_id} to {seg.to_station_id}",
                duration_minutes=dur
            ))
            current_time_dt += timedelta(minutes=dur)

        elif seg.mode == SegmentMode.RIDE:
            ride_count += 1
            trip = trip_map.get(seg.trip_id)
            if not trip: continue
            eta_entries = slice_timetable(trip.timetable_entries, seg.from_station_id, seg.to_station_id)
            processed_etas = build_eta_from_timetable(eta_entries, predicted_map)
            
            if processed_etas:
                full_eta_stops.extend(processed_etas)
                start_ride = datetime.strptime(processed_etas[0].predicted_departure, "%H:%M:%S")
                end_ride = datetime.strptime(processed_etas[-1].predicted_arrival, "%H:%M:%S")
                ride_dur = (end_ride - start_ride).total_seconds() / 60
                if ride_dur < 0: ride_dur += 1440

                instructions.append(StepInstruction(
                    step_index=i + 1, mode=seg.mode, title=f"Line {seg.line_id}",
                    description=f"Ride from {seg.from_station_id} to {seg.to_station_id}",
                    from_station=StationRef(station_id=seg.from_station_id),
                    to_station=StationRef(station_id=seg.to_station_id),
                    line_id=seg.line_id, trip_id=seg.trip_id,
                    duration_minutes=ride_dur
                ))
                current_time_dt = current_time_dt.replace(hour=end_ride.hour, minute=end_ride.minute)

        elif seg.mode == SegmentMode.TRANSFER:
            transfer_count += 1
            dur = float(seg.transfer_minutes or 0)
            instructions.append(StepInstruction(
                step_index=i + 1, mode=seg.mode, title="Transfer",
                description="Transfer at station",
                duration_minutes=dur
            ))
            current_time_dt += timedelta(minutes=dur)

    walk_total = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.WALK)
    ride_total = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.RIDE)
    trans_total = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.TRANSFER)

    return RoutePostprocessingRouteOutput(
        route_id=core_route.route_id,
        summary=f"Total {walk_total + ride_total + trans_total:.1f} min",
        entry_station=core_route.entry_station,
        exit_station=core_route.exit_station,
        transfer_count=transfer_count,
        ride_segment_count=ride_count,
        walk_segment_count=walk_count,
        time_breakdown=TimeBreakdown(
            walking_minutes=walk_total, 
            in_vehicle_minutes=ride_total, 
            transfer_minutes=trans_total,
            total_time_minutes=walk_total + ride_total + trans_total
        ),
        instructions=instructions,
        eta_stops=full_eta_stops,
        evaluation=RouteEvaluation(score=95.0, rank=1)
    )

# --- WRAPPER CHO OUTPUT CUỐI CÙNG ---

def get_final_output(core_routes, trip_map, predicted_map, origin_coord, dest_coord) -> RoutePostprocessingOutput:
    processed_routes = []
    for cr in core_routes:
        processed_routes.append(build_route_from_core(cr, trip_map, predicted_map))
    
    return RoutePostprocessingOutput(
        status=RouteStatus.SUCCESS,
        origin=origin_coord,
        destination=dest_coord,
        generated_at=datetime.now().isoformat(),
        selected_route_id=processed_routes[0].route_id if processed_routes else None,
        routes=processed_routes
    )

# --- MOCK DATA ĐỂ CHẠY THỬ ---

if __name__ == "__main__":
    # Giả lập các Class đầu vào từ Core Routing
    class MockSeg:
        def __init__(self, mode, fs, ts, tid=None, line="L1"):
            self.mode, self.from_station_id, self.to_station_id, self.trip_id, self.line_id = mode, fs, ts, tid, line
            self.base_travel_minutes, self.transfer_minutes = 5, 2

    class MockRoute:
        def __init__(self):
            self.route_id = "ROUTE_66"
            self.segments = [MockSeg(SegmentMode.WALK, "START", "A"), MockSeg(SegmentMode.RIDE, "A", "C", "T1")]
            self.entry_station = StationRef(station_id="A")
            self.exit_station = StationRef(station_id="C")

    class MockTrip:
        def __init__(self):
            self.trip_id = "T1"
            self.timetable_entries = [
                type('E', (), {'station_id': 'A', 'stop_sequence': 1, 'scheduled_arrival_time': time(8,0), 'scheduled_departure_time': time(8,2)}),
                type('E', (), {'station_id': 'B', 'stop_sequence': 2, 'scheduled_arrival_time': time(8,5), 'scheduled_departure_time': time(8,6)}),
                type('E', (), {'station_id': 'C', 'stop_sequence': 3, 'scheduled_arrival_time': time(8,10), 'scheduled_departure_time': time(8,11)})
            ]

    # Thực thi
    final_result = get_final_output(
        core_routes=[MockRoute()],
        trip_map={"T1": MockTrip()},
        predicted_map={"B": 2}, # Delay 2 phút tại ga B
        origin_coord=Coordinate(lat=35.0, lon=135.0),
        dest_coord=Coordinate(lat=35.1, lon=135.1)
    )

    print(json.dumps(final_result.model_dump(), indent=2))