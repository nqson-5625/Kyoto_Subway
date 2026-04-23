# Cho phép forward reference an toàn hơn.
from __future__ import annotations

# BaseModel là lớp gốc của Pydantic.
# ConfigDict để bật from_attributes=True cho từng model.
from pydantic import BaseModel, ConfigDict

from app.schemas.algorithm.enums import SegmentMode, RouteStatus
from app.schemas.algorithm.routing_common import CostBreakdown, GraphNodeRef, RoutePolyline, RouteWarning, StationRef


# Schema dùng để echo lại request đầu vào của core-routing
class CoreRoutingRequestEcho(BaseModel):
    # tuple[float, float] = (lon, lat)
    origin: tuple[float, float] # Tọa độ đầu vào điểm xuất phát
    destination: tuple[float, float] # Tọa độ đầu vào điểm đích
    scenario_id: str | None = None # Scenario đang áp dụng 
    optimize_for: str = "time" # Tiêu chí tối ưu hóa: "time", "fewest_transfers", "least_walking", ...

    model_config = ConfigDict(from_attributes=True)


# Endpoint ánh xạ 1 graph_note gần nhất của 1 station
class WalkEndpoint(BaseModel): 
    graph_node: GraphNodeRef # Node graph dùng làm mốc trong walking graph
    station: StationRef | None = None # Ga gắn với endpoint này

    model_config = ConfigDict(from_attributes=True)


# Mô tả từng segment thô trong route
class CoreRoutingSegment(BaseModel):
    segment_index: int # Thứ tự segment trong route
    mode: SegmentMode # Loại segment: walk / ride / transfer

    from_node_id: int | str | None = None # Node bắt đầu của segment trong graph
    to_node_id: int | str | None = None # Node kết thúc của segment trong graph

    from_station_id: str | None = None # Ga bắt đầu của segment 
    to_station_id: str | None = None # Ga kết thúc của segment

    line_id: str | None = None # Tuyến liên quan nếu segment là ride
    trip_id: str | None = None # Trip liên quan nếu đã chọn được trip 

   
    direction_id: int | None = None # Hướng ride (1-chiều tăng STT ga, 0-chiều giảm STT ga)
    distance_m: float | None = None # Chiều dài segment theo mét

    base_travel_minutes: float | None = None # Thời gian di chuyển cơ sở của segment: đi bộ 4 phút, ride 8 phút, ...
    transfer_minutes: float | None = None # Nếu segment là transfer, thời gian transfer ở đây

   
    edge_ids: list[int] = [] # Danh sách edge_id của subway edge đi qua nếu có
    transfer_ids: list[int] = []  # Danh sách transfer_id nếu segment này là transfer
    path_node_ids: list[int | str] = [] # Danh sách node id mà path đi qua (walking graph)
 
    polyline: RoutePolyline | None = None # Polyline thô của segment nếu đã dựng được

    model_config = ConfigDict(from_attributes=True)


# cấu trúc mỗi route mà Core Routing sinh ra 
# Một request có thể sinh 1 hoặc nhiều candidate routes.
class CoreRoutingRoute(BaseModel):
    route_id: str # ID logic của route
    rank: int = 1 # Thứ hạng route trong danh sách candidate

    entry_station: StationRef | None = None  # Ga vào hệ subway
    exit_station: StationRef | None = None # Ga ra khỏi hệ subway
 
    origin_walk_target: WalkEndpoint | None = None # Endpoint đi bộ phía đầu hành trình
    destination_walk_source: WalkEndpoint | None = None # Endpoint đi bộ phía cuối hành trình
 
    segments: list[CoreRoutingSegment] # Danh sách segment tạo thành route

    visited_station_ids: list[str] = [] # Danh sách station_id mà route đi qua
    visited_line_ids: list[str] = [] # Danh sách line_id mà route đi qua

    cost_breakdown: CostBreakdown # Breakdown cost cho route 

    warnings: list[RouteWarning] = [] # Cảnh báo riêng của route 

    model_config = ConfigDict(from_attributes=True)


# Output tổng của Core-Routing = input của Route-PostProcessing
class CoreRoutingOutput(BaseModel):
    status: RouteStatus # Trạng thái chung của request routing

    request: CoreRoutingRequestEcho # Echo lại request đầu vào để trace/debug

    routes: list[CoreRoutingRoute] = [] # Danh sách route candidates

    computed_candidate_count: int = 0 # Số candidate đã tính ra được

    selected_route_id: str | None = None  # Route ID được chọn làm best route

    # Khu vực debug mở rộng.
    # Cho phép chứa dữ liệu linh hoạt như:
    # candidate station list, search stats, explored nodes...
    debug: dict[str, object] | None = None

    warnings: list[RouteWarning] = [] # Warning mức toàn request

    model_config = ConfigDict(from_attributes=True)