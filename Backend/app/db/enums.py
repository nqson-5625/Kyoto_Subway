from enum import IntEnum, StrEnum


class TransferType(StrEnum):
    SAME_STATION_INTERCHANGE = "same_station_interchange"
    WALK_TRANSFER = "walk_transfer"


class ServiceType(StrEnum):
    WEEKDAY = "weekday"
    SATURDAY = "saturday"
    SUNDAY = "sunday"
    HOLIDAY = "holiday"
    SPECIAL = "special"


class ServiceExceptionType(StrEnum):
    ADDED = "added"
    REMOVED = "removed"


class ServiceExceptionCategory(StrEnum):
    HOLIDAY = "holiday"
    SPECIAL_OPERATION = "special_operation"
    MAINTENANCE = "maintenance"
    EVENT = "event"
    EMERGENCY = "emergency"


class DirectionId(IntEnum):
    OUTBOUND = 0
    INBOUND = 1


class ScenarioType(StrEnum):
    DELAY = "delay"
    MAINTENANCE = "maintenance"
    CLOSURE = "closure"
    MIXED = "mixed"


class InfrastructureStatus(StrEnum):
    NORMAL = "normal"
    DELAYED = "delayed"
    CLOSED = "closed"
    MAINTENANCE = "maintenance"
    SUSPENDED = "suspended"
    PARTIAL_SUSPEND = "partial_suspend"
    DISRUPTED = "disrupted"
    RECOVERED = "recovered"


class TripStatus(StrEnum):
    NORMAL = "normal"
    DELAYED = "delayed"
    CLOSED = "closed"
    MAINTENANCE = "maintenance"
    SUSPENDED = "suspended"
    PARTIAL_SUSPEND = "partial_suspend"
    DISRUPTED = "disrupted"
    CANCELLED = "cancelled"
    RECOVERED = "recovered"


class CurrentStatus(StrEnum):
    NORMAL = "normal"
    DELAYED = "delayed"
    CLOSED = "closed"
    MAINTENANCE = "maintenance"
    SUSPENDED = "suspended"
    DISRUPTED = "disrupted"


class EventCategory(StrEnum):
    INCIDENT = "incident"
    DELAY = "delay"
    MAINTENANCE = "maintenance"
    SERVICE_CHANGE = "service_change"
    RECOVERY = "recovery"
    MANUAL_OVERRIDE = "manual_override"


class ImpactLevel(StrEnum):
    INFO = "info"
    MINOR = "minor"
    MODERATE = "moderate"
    MAJOR = "major"
    SEVERE = "severe"


class SourceType(StrEnum):
    MANUAL = "manual"
    OPS_FEED = "ops_feed"
    ETL_RULE = "etl_rule"
    SCENARIO = "scenario"
    SYSTEM = "system"


class PredictionStatus(StrEnum):
    ON_TIME = "on_time"
    DELAYED = "delayed"
    SKIPPED = "skipped"
    CANCELLED = "cancelled"


class PredictionSource(StrEnum):
    SIMULATION_ENGINE = "simulation_engine"
    REALTIME_FEED = "realtime_feed"
    MANUAL_OVERRIDE = "manual_override"


class RoutingStatusSource(StrEnum):
    NORMAL = "normal"
    DELAY_EVENT = "delay_event"
    MAINTENANCE = "maintenance"
    MANUAL_OVERRIDE = "manual_override"
    SCENARIO = "scenario"


class RouteRequestResultStatus(StrEnum):
    SUCCESS = "success"
    NO_PATH = "no_path"
    INVALID_REQUEST = "invalid_request"
    ERROR = "error"
    TIMEOUT = "timeout"


class RoutingEdgeType(StrEnum):
    RIDE = "ride"
    TRANSFER = "transfer"
