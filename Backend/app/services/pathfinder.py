# File: app/services/pathfinder.py
from datetime import datetime
from sqlalchemy.orm import Session
from app.algorithms.graph_builder import build_graph_from_db
from app.algorithms.core_router import process_routing_request
from app.schemas.algorithm.core_routing_output import CoreRoutingRequestEcho, CoreRoutingOutput

class PathfinderService:
    @staticmethod
    async def find_route(db: Session, request: CoreRoutingRequestEcho, request_time: datetime, algorithm: str = "dijkstra") -> CoreRoutingOutput:
        # 1. Xây dựng đồ thị từ DB (có tích hợp thời gian thực)
        graph = build_graph_from_db(db)
        
        # 2. Gọi logic xử lý thuật toán cốt lõi
        routing_output = await process_routing_request(
            request=request,
            graph=graph,
            request_time=request_time,
            db=db,
            algorithm=algorithm
        )
        
        return routing_output

pathfinder_service = PathfinderService()