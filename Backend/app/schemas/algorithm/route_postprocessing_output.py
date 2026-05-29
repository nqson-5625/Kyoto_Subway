from __future__ import annotations

from pydantic import BaseModel, ConfigDict

from app.schemas.algorithm.enums import SegmentMode, RouteStatus
from app.schemas.algorithm.routing_common import Coordinate, RoutePolyline, RouteWarning, StationRef, TimeBreakdown


# Mô tả từng instruction/step cho FE hoặc API consumer
class StepInstruction(BaseModel):
    step_index: int # Thứ tự step trong route 
    mode: SegmentMode # Loại step: walk / ride / transfer

    title: str # Tiêu đề ngắn, ví dụ: "Walk to Karasuma Oike Station"
    description: str # Mô tả chi tiết cho FE hiển thị

    from_station: StationRef | None = None # Ga bắt đầu của step
    to_station: StationRef | None = None # Ga kết thúc của step 

    line_id: str | None = None # Tuyến dùng trong step ride 
    trip_id: str | None = None # Trip cụ thể 

    duration_minutes: float | None = None # Thời lượng step
    distance_m: float | None = None # Quãng đường step theo mét 

    polyline: RoutePolyline | None = None # Polyline riêng của step

    model_config = ConfigDict(from_attributes=True)



# Schema ETA theo từng ga/stop Route PostProcessing trả chi tiết
class ETAStopItem(BaseModel):
    station_id: str # Mã ga
    station_name: str | None = None # Tên ga

    scheduled_arrival: str | None = None # Giờ đến theo lịch
    scheduled_departure: str | None = None # Giờ rời theo lịch

    predicted_arrival: str | None = None # Giờ đến dự đoán nếu có realtime
    predicted_departure: str | None = None # Giờ rời dự đoán nếu có realtime

    delay_minutes: float | None = None # Delay tính bằng phút 

    model_config = ConfigDict(from_attributes=True)

# Schema phục vụ evaluation/scoring route 
# Hữu ích nếu có nhiều candidate route và muốn explain score
class RouteEvaluation(BaseModel):
    score: float # Tổng score cuối cùng
    rank: int # Xếp hạng của route

    fewer_transfers_better: float | None = None # Điểm theo tiêu chí ít transfer hơn là tốt hơn
    shorter_time_better: float | None = None # Điểm theo tiêu chí thời gian ngắn hơn là tốt hơn
    less_walking_better: float | None = None # Điểm theo tiêu chí đi bộ ít hơn là tốt hơn
    less_disruption_better: float | None = None # Điểm theo tiêu chí ít bị ảnh hưởng disruption hơn

    model_config = ConfigDict(from_attributes=True)


# Output route hoàn thiện, là object mà API trả về cho frontend
class RoutePostprocessingRouteOutput(BaseModel):
    route_id: str # ID route tương ứng với route_id từ core-routing
    is_selected: bool = True # Route này có phải route được chọn cuối cùng không

    summary: str # Summary ngắn gọn cho FE, ví dụ: "Walk 3 min, take Karasuma Line to K11, transfer once"
    headsign: str | None = None # Headsign chính để hiển thị nếu cần

    entry_station: StationRef | None = None # Ga vào subway
    exit_station: StationRef | None = None # Ga ra subway

    transfer_count: int = 0 # Số lần transfer
    ride_segment_count: int = 0 # Số segment ride
    walk_segment_count: int = 0 # Số segment walk
    time_breakdown: TimeBreakdown # Breakdown thời gian hoàn chỉnh

    instructions: list[StepInstruction] # Danh sách instruction để FE render step-by-step
    eta_stops: list[ETAStopItem] = [] # ETA chi tiết theo stop nếu có
    evaluation: RouteEvaluation | None = None # Evaluation/score nếu có
    full_polyline: RoutePolyline | None = None # Polyline đầy đủ của toàn route

    warnings: list[RouteWarning] = [] # Warning riêng của route

    model_config = ConfigDict(from_attributes=True)


# Output tổng cuối cùng 
class RoutePostprocessingOutput(BaseModel):
    status: RouteStatus # Trạng thái chung của kết quả

    origin: Coordinate # Tọa độ điểm đầu
    destination: Coordinate # Tọa độ điểm cuối

    generated_at: str | None = None # Timestamp lúc output được tạo ra

    selected_route_id: str | None = None # Route được chọn cuối cùng
    routes: list[RoutePostprocessingRouteOutput] = [] # Danh sách routes hoàn chỉnh

    warnings: list[RouteWarning] = [] # Warning mức toàn response

    model_config = ConfigDict(from_attributes=True)


