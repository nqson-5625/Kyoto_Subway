# from __future__ import annotations

# from pydantic import BaseModel, ConfigDict

# from app.schemas.algorithm.enums import SegmentMode, RouteStatus
# from app.schemas.algorithm.routing_common import Coordinate, RoutePolyline, RouteWarning, StationRef, TimeBreakdown


# # Mô tả từng instruction/step cho FE hoặc API consumer
# class StepInstruction(BaseModel):
#     step_index: int # Thứ tự step trong route 
#     mode: SegmentMode # Loại step: walk / ride / transfer

#     title: str # Tiêu đề ngắn, ví dụ: "Walk to Karasuma Oike Station"
#     description: str # Mô tả chi tiết cho FE hiển thị

#     from_station: StationRef | None = None # Ga bắt đầu của step
#     to_station: StationRef | None = None # Ga kết thúc của step 

#     line_id: str | None = None # Tuyến dùng trong step ride 
#     trip_id: str | None = None # Trip cụ thể 

#     duration_minutes: float | None = None # Thời lượng step
#     distance_m: float | None = None # Quãng đường step theo mét 

#     polyline: RoutePolyline | None = None # Polyline riêng của step

#     model_config = ConfigDict(from_attributes=True)



# # Schema ETA theo từng ga/stop Route PostProcessing trả chi tiết
# class ETAStopItem(BaseModel):
#     station_id: str # Mã ga
#     station_name: str | None = None # Tên ga

#     scheduled_arrival: str | None = None # Giờ đến theo lịch
#     scheduled_departure: str | None = None # Giờ rời theo lịch

#     predicted_arrival: str | None = None # Giờ đến dự đoán nếu có realtime
#     predicted_departure: str | None = None # Giờ rời dự đoán nếu có realtime

#     delay_minutes: float | None = None # Delay tính bằng phút 

#     model_config = ConfigDict(from_attributes=True)

# # Schema phục vụ evaluation/scoring route 
# # Hữu ích nếu có nhiều candidate route và muốn explain score
# class RouteEvaluation(BaseModel):
#     score: float # Tổng score cuối cùng
#     rank: int # Xếp hạng của route

#     fewer_transfers_better: float | None = None # Điểm theo tiêu chí ít transfer hơn là tốt hơn
#     shorter_time_better: float | None = None # Điểm theo tiêu chí thời gian ngắn hơn là tốt hơn
#     less_walking_better: float | None = None # Điểm theo tiêu chí đi bộ ít hơn là tốt hơn
#     less_disruption_better: float | None = None # Điểm theo tiêu chí ít bị ảnh hưởng disruption hơn

#     model_config = ConfigDict(from_attributes=True)


# # Output route hoàn thiện, là object mà API trả về cho frontend
# class RoutePostprocessingRouteOutput(BaseModel):
#     route_id: str # ID route tương ứng với route_id từ core-routing
#     is_selected: bool = True # Route này có phải route được chọn cuối cùng không

#     summary: str # Summary ngắn gọn cho FE, ví dụ: "Walk 3 min, take Karasuma Line to K11, transfer once"
#     headsign: str | None = None # Headsign chính để hiển thị nếu cần

#     entry_station: StationRef | None = None # Ga vào subway
#     exit_station: StationRef | None = None # Ga ra subway

#     transfer_count: int = 0 # Số lần transfer
#     ride_segment_count: int = 0 # Số segment ride
#     walk_segment_count: int = 0 # Số segment walk
#     time_breakdown: TimeBreakdown # Breakdown thời gian hoàn chỉnh

#     instructions: list[StepInstruction] # Danh sách instruction để FE render step-by-step
#     eta_stops: list[ETAStopItem] = [] # ETA chi tiết theo stop nếu có
#     evaluation: RouteEvaluation | None = None # Evaluation/score nếu có
#     full_polyline: RoutePolyline | None = None # Polyline đầy đủ của toàn route

#     warnings: list[RouteWarning] = [] # Warning riêng của route

#     model_config = ConfigDict(from_attributes=True)


# # Output tổng cuối cùng 
# class RoutePostprocessingOutput(BaseModel):
#     status: RouteStatus # Trạng thái chung của kết quả

#     origin: Coordinate # Tọa độ điểm đầu
#     destination: Coordinate # Tọa độ điểm cuối

#     generated_at: str | None = None # Timestamp lúc output được tạo ra

#     selected_route_id: str | None = None # Route được chọn cuối cùng
#     routes: list[RoutePostprocessingRouteOutput] = [] # Danh sách routes hoàn chỉnh

#     warnings: list[RouteWarning] = [] # Warning mức toàn response

#     model_config = ConfigDict(from_attributes=True)

# ####################################################################################


# from datetime import datetime, timedelta, time

# def slice_timetable(entries, start_station, end_station):
#     entries = sorted(entries, key=lambda x: x.stop_sequence)

#     start_idx = next(
#         (i for i, e in enumerate(entries) if e.station_id == start_station),
#         None
#     )
#     end_idx = next(
#         (i for i, e in enumerate(entries) if e.station_id == end_station),
#         None
#     )

#     if start_idx is None or end_idx is None:
#         return []

#     return entries[start_idx:end_idx + 1]


# def build_eta_from_timetable(entries, predicted_map=None):
#     base = datetime(2000, 1, 1)
#     result = []

#     for e in entries:
#         arr = base.replace(
#             hour=e.scheduled_arrival_time.hour,
#             minute=e.scheduled_arrival_time.minute,
#             second=e.scheduled_arrival_time.second
#         )

#         dep = base.replace(
#             hour=e.scheduled_departure_time.hour,
#             minute=e.scheduled_departure_time.minute,
#             second=e.scheduled_departure_time.second
#         )

#         delay = predicted_map.get(e.station_id, 0) if predicted_map else 0

#         result.append(
#             ETAStopItem(
#                 station_id=e.station_id,
#                 scheduled_arrival=arr.strftime("%H:%M:%S"),
#                 scheduled_departure=dep.strftime("%H:%M:%S"),
#                 predicted_arrival=(arr + timedelta(minutes=delay)).strftime("%H:%M:%S"),
#                 predicted_departure=(dep + timedelta(minutes=delay)).strftime("%H:%M:%S"),
#                 delay_minutes=delay
#             )
#         )

#     return result

# def build_eta_for_route(trip, start_station, end_station, predicted_map=None):
#     if not trip:
#         return []

#     sliced = slice_timetable(trip.timetable_entries, start_station, end_station)
#     return build_eta_from_timetable(sliced, predicted_map)

# def build_route_from_core(
#     core_route,
#     trip_map,
#     predicted_map=None
# ):
#     instructions = []
#     full_eta_stops = []

#     base_time = datetime(2000, 1, 1, 8, 0)
#     current_time = base_time

#     for i, seg in enumerate(core_route.segments):

#         # ================= WALK =================
#         if seg.mode == SegmentMode.WALK:
#             duration = seg.base_travel_minutes or 0

#             instructions.append(
#                 StepInstruction(
#                     step_index=i + 1,
#                     mode=seg.mode,
#                     title="Walk",
#                     description=f"{seg.from_station_id} → {seg.to_station_id}",
#                     duration_minutes=duration
#                 )
#             )

#             current_time += timedelta(minutes=duration)

#         # ================= TRANSFER =================
#         elif seg.mode == SegmentMode.TRANSFER:
#             duration = seg.transfer_minutes or 0

#             instructions.append(
#                 StepInstruction(
#                     step_index=i + 1,
#                     mode=seg.mode,
#                     title="Transfer",
#                     description="Transfer between lines",
#                     duration_minutes=duration
#                 )
#             )

#             current_time += timedelta(minutes=duration)

#         # ================= RIDE =================
#         elif seg.mode == SegmentMode.RIDE:
#             trip = trip_map.get(seg.trip_id)
#             if not trip:
#                 continue

#             eta_stops = build_eta_for_route(
#                 trip,
#                 seg.from_station_id,
#                 seg.to_station_id,
#                 predicted_map
#             )

#             if not eta_stops:
#                 continue

#             # ===== SHIFT TIME =====
#             first_dep = datetime.strptime(
#                 eta_stops[0].scheduled_departure, "%H:%M:%S"
#             )

#             first_dep = base_time.replace(
#                 hour=first_dep.hour,
#                 minute=first_dep.minute,
#                 second=first_dep.second
#             )

#             shift = current_time - first_dep

#             for stop in eta_stops:

#                 # scheduled
#                 arr = datetime.strptime(stop.scheduled_arrival, "%H:%M:%S")
#                 dep = datetime.strptime(stop.scheduled_departure, "%H:%M:%S")

#                 arr = base_time.replace(
#                     hour=arr.hour,
#                     minute=arr.minute,
#                     second=arr.second
#                 ) + shift

#                 dep = base_time.replace(
#                     hour=dep.hour,
#                     minute=dep.minute,
#                     second=dep.second
#                 ) + shift

#                 # predicted
#                 pred_arr = datetime.strptime(stop.predicted_arrival, "%H:%M:%S")
#                 pred_dep = datetime.strptime(stop.predicted_departure, "%H:%M:%S")

#                 pred_arr = base_time.replace(
#                     hour=pred_arr.hour,
#                     minute=pred_arr.minute,
#                     second=pred_arr.second
#                 ) + shift

#                 pred_dep = base_time.replace(
#                     hour=pred_dep.hour,
#                     minute=pred_dep.minute,
#                     second=pred_dep.second
#                 ) + shift

#                 stop.scheduled_arrival = arr.strftime("%H:%M:%S")
#                 stop.scheduled_departure = dep.strftime("%H:%M:%S")
#                 stop.predicted_arrival = pred_arr.strftime("%H:%M:%S")
#                 stop.predicted_departure = pred_dep.strftime("%H:%M:%S")

#                 full_eta_stops.append(stop)

#             # update current time
#             last = datetime.strptime(
#                 eta_stops[-1].predicted_arrival, "%H:%M:%S"
#             )

#             current_time = base_time.replace(
#                 hour=last.hour,
#                 minute=last.minute,
#                 second=last.second
#             )

#             instructions.append(
#                 StepInstruction(
#                     step_index=i + 1,
#                     mode=seg.mode,
#                     title=f"Take line {seg.line_id}",
#                     description=f"{seg.from_station_id} → {seg.to_station_id}",
#                     from_station=StationRef(station_id=seg.from_station_id),
#                     to_station=StationRef(station_id=seg.to_station_id),
#                     line_id=seg.line_id,
#                     trip_id=seg.trip_id
#                 )
#             )

#     total_minutes = (current_time - base_time).total_seconds() / 60

#     return RoutePostprocessingRouteOutput(
#         route_id=core_route.route_id,
#         summary="Multi segment route",
#         entry_station=core_route.entry_station,
#         exit_station=core_route.exit_station,

#         transfer_count=sum(1 for s in core_route.segments if s.mode == SegmentMode.TRANSFER),
#         ride_segment_count=sum(1 for s in core_route.segments if s.mode == SegmentMode.RIDE),
#         walk_segment_count=sum(1 for s in core_route.segments if s.mode == SegmentMode.WALK),

#         time_breakdown=TimeBreakdown(
#             total_time_minutes=total_minutes
#         ),

#         instructions=instructions,
#         eta_stops=full_eta_stops
#     )



from __future__ import annotations
from datetime import datetime, timedelta, time
from pydantic import BaseModel, ConfigDict

from app.schemas.algorithm.enums import SegmentMode, RouteStatus
from app.schemas.algorithm.routing_common import Coordinate, RoutePolyline, RouteWarning, StationRef, TimeBreakdown

# --- GIỮ NGUYÊN CÁC CLASS SCHEMA CỦA BẠN ---
class StepInstruction(BaseModel):
    step_index: int 
    mode: SegmentMode 
    title: str 
    description: str 
    from_station: StationRef | None = None 
    to_station: StationRef | None = None 
    line_id: str | None = None 
    trip_id: str | None = None 
    duration_minutes: float | None = None 
    distance_m: float | None = None 
    polyline: RoutePolyline | None = None 
    model_config = ConfigDict(from_attributes=True)

class ETAStopItem(BaseModel):
    station_id: str 
    station_name: str | None = None 
    scheduled_arrival: str | None = None 
    scheduled_departure: str | None = None 
    predicted_arrival: str | None = None 
    predicted_departure: str | None = None 
    delay_minutes: float | None = None 
    model_config = ConfigDict(from_attributes=True)

class RouteEvaluation(BaseModel):
    score: float 
    rank: int 
    fewer_transfers_better: float | None = None 
    shorter_time_better: float | None = None 
    less_walking_better: float | None = None 
    less_disruption_better: float | None = None 
    model_config = ConfigDict(from_attributes=True)

class RoutePostprocessingRouteOutput(BaseModel):
    route_id: str 
    is_selected: bool = True 
    summary: str 
    headsign: str | None = None 
    entry_station: StationRef | None = None 
    exit_station: StationRef | None = None 
    transfer_count: int = 0 
    ride_segment_count: int = 0 
    walk_segment_count: int = 0 
    time_breakdown: TimeBreakdown 
    instructions: list[StepInstruction] 
    eta_stops: list[ETAStopItem] = [] 
    evaluation: RouteEvaluation | None = None 
    full_polyline: RoutePolyline | None = None 
    warnings: list[RouteWarning] = [] 
    model_config = ConfigDict(from_attributes=True)

# --- CÁC HÀM ĐÃ ĐƯỢC TỐI ƯU HÓA ---

def slice_timetable(entries, start_station, end_station):
    entries = sorted(entries, key=lambda x: x.stop_sequence)
    start_idx = next((i for i, e in enumerate(entries) if e.station_id == start_station), None)
    end_idx = next((i for i, e in enumerate(entries) if e.station_id == end_station), None)
    if start_idx is None or end_idx is None:
        return []
    return entries[start_idx:end_idx + 1]

def build_eta_from_timetable(entries, predicted_map=None):
    base = datetime(2000, 1, 1)
    result = []
    cumulative_delay = 0.0 # Khởi tạo delay tích lũy

    for e in entries:
        # Lấy delay cụ thể của ga này (nếu có), nếu không giữ delay từ ga trước
        current_delay = predicted_map.get(e.station_id, 0) if predicted_map else 0
        cumulative_delay = max(cumulative_delay, float(current_delay))

        arr = base.replace(hour=e.scheduled_arrival_time.hour, minute=e.scheduled_arrival_time.minute, second=e.scheduled_arrival_time.second)
        dep = base.replace(hour=e.scheduled_departure_time.hour, minute=e.scheduled_departure_time.minute, second=e.scheduled_departure_time.second)

        result.append(
            ETAStopItem(
                station_id=e.station_id,
                scheduled_arrival=arr.strftime("%H:%M:%S"),
                scheduled_departure=dep.strftime("%H:%M:%S"),
                predicted_arrival=(arr + timedelta(minutes=cumulative_delay)).strftime("%H:%M:%S"),
                predicted_departure=(dep + timedelta(minutes=cumulative_delay)).strftime("%H:%M:%S"),
                delay_minutes=cumulative_delay
            )
        )
    return result

def build_route_from_core(core_route, trip_map, predicted_map=None):
    instructions = []
    full_eta_stops = []
    base_time = datetime(2000, 1, 1, 8, 0)
    current_time = base_time

    for i, seg in enumerate(core_route.segments):
        # --- WALK ---
        if seg.mode == SegmentMode.WALK:
            duration = float(seg.base_travel_minutes or 0)
            instructions.append(
                StepInstruction(
                    step_index=i + 1,
                    mode=seg.mode,
                    title="Walk",
                    description=f"Walk from {seg.from_station_id} to {seg.to_station_id}",
                    duration_minutes=duration
                )
            )
            current_time += timedelta(minutes=duration)

        # --- TRANSFER ---
        elif seg.mode == SegmentMode.TRANSFER:
            duration = float(seg.transfer_minutes or 0)
            instructions.append(
                StepInstruction(
                    step_index=i + 1,
                    mode=seg.mode,
                    title="Transfer",
                    description="Transfer to another line",
                    duration_minutes=duration
                )
            )
            current_time += timedelta(minutes=duration)

        # --- RIDE ---
        elif seg.mode == SegmentMode.RIDE:
            trip = trip_map.get(seg.trip_id)
            if not trip: continue

            eta_stops = slice_timetable(trip.timetable_entries, seg.from_station_id, seg.to_station_id)
            processed_etas = build_eta_from_timetable(eta_stops, predicted_map)
            if not processed_etas: continue

            # Đồng bộ thời gian thực tế vào hành trình (Shift time)
            first_dep_dt = datetime.strptime(processed_etas[0].scheduled_departure, "%H:%M:%S")
            first_dep_dt = base_time.replace(hour=first_dep_dt.hour, minute=first_dep_dt.minute, second=first_dep_dt.second)
            shift = current_time - first_dep_dt

            for stop in processed_etas:
                for attr in ['scheduled_arrival', 'scheduled_departure', 'predicted_arrival', 'predicted_departure']:
                    t_dt = datetime.strptime(getattr(stop, attr), "%H:%M:%S")
                    new_t = (base_time.replace(hour=t_dt.hour, minute=t_dt.minute, second=t_dt.second) + shift).strftime("%H:%M:%S")
                    setattr(stop, attr, new_t)
                full_eta_stops.append(stop)

            # Tính thời gian chặng Ride (từ lúc đi ga đầu đến lúc tới ga cuối)
            ride_start = datetime.strptime(processed_etas[0].predicted_departure, "%H:%M:%S")
            ride_end = datetime.strptime(processed_etas[-1].predicted_arrival, "%H:%M:%S")
            ride_duration = (ride_end - ride_start).total_seconds() / 60
            if ride_duration < 0: ride_duration += 1440 # Xử lý qua đêm

            instructions.append(
                StepInstruction(
                    step_index=i + 1,
                    mode=seg.mode,
                    title=f"Take line {seg.line_id}",
                    description=f"{seg.from_station_id} → {seg.to_station_id}",
                    from_station=StationRef(station_id=seg.from_station_id),
                    to_station=StationRef(station_id=seg.to_station_id),
                    line_id=seg.line_id,
                    trip_id=seg.trip_id,
                    duration_minutes=ride_duration
                )
            )
            current_time = base_time.replace(hour=ride_end.hour, minute=ride_end.minute, second=ride_end.second)

    # --- TÍNH TOÁN CUỐI CÙNG ---
    walking_m = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.WALK)
    riding_m = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.RIDE)
    transfer_m = sum(inst.duration_minutes for inst in instructions if inst.mode == SegmentMode.TRANSFER)
    total_m = walking_m + riding_m + transfer_m

    return RoutePostprocessingRouteOutput(
        route_id=core_route.route_id,
        summary=f"Total: {total_m:.1f} min ({int(riding_m)} min riding)",
        entry_station=core_route.entry_station,
        exit_station=core_route.exit_station,
        transfer_count=sum(1 for s in core_route.segments if s.mode == SegmentMode.TRANSFER),
        ride_segment_count=sum(1 for s in core_route.segments if s.mode == SegmentMode.RIDE),
        walk_segment_count=sum(1 for s in core_route.segments if s.mode == SegmentMode.WALK),
        time_breakdown=TimeBreakdown(
            walking_minutes=walking_m,
            in_vehicle_minutes=riding_m,
            transfer_minutes=transfer_m,
            total_time_minutes=total_m
        ),
        instructions=instructions,
        eta_stops=full_eta_stops
    )

# [Phần Fake Classes để TEST giữ nguyên như cũ của bạn là chạy được]



# ===== TEST =====
class FakeEntry:
    def __init__(self, station_id, seq, h, m):
        self.station_id = station_id
        self.stop_sequence = seq
        self.scheduled_arrival_time = time(h, m)
        self.scheduled_departure_time = time(h, m)
        self.scheduled_arrival_day_offset = 0
        self.scheduled_departure_day_offset = 0


class FakeTrip:
    def __init__(self):
        self.trip_id = "T1"
        self.line_id = "L1"
        self.timetable_entries = [
            FakeEntry("A", 1, 8, 0),
            FakeEntry("B", 2, 8, 5),
            FakeEntry("C", 3, 8, 10),
            FakeEntry("D", 4, 8, 15),
        ]


class FakeSeg:
    def __init__(self, mode, fs, ts, trip_id=None):
        self.mode = mode
        self.from_station_id = fs
        self.to_station_id = ts
        self.trip_id = trip_id
        self.line_id = "L1"
        self.base_travel_minutes = 5
        self.transfer_minutes = 3


class FakeRoute:
    def __init__(self):
        self.route_id = "R1"
        self.segments = [
            FakeSeg(SegmentMode.WALK, "HOME", "B"),
            FakeSeg(SegmentMode.RIDE, "B", "D", "T1")
        ]
        self.entry_station = StationRef(station_id="B")
        self.exit_station = StationRef(station_id="D")


trip_map = {"T1": FakeTrip()}
core_route = FakeRoute()

result = build_route_from_core(core_route, trip_map, {"C": 3})

print(result.model_dump())