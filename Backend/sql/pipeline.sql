-- ==================================================================================================
-- Kyoto Subway operational pipeline
--
-- File này tính lại toàn bộ các bảng current / serving từ:
-- 1) dữ liệu nền đã seed sẵn (lines, stations, edges, trips, timetable, ...)
-- 2) các bảng sự kiện bất thường (*_status_events)
-- 3) một scenario tùy chọn nếu có truyền p_scenario_id
--
-- Thiết kế quan trọng:
-- - station_status_current và line_status_current chỉ giữ MỘT bản current cho mỗi station/line
--   vì schema hiện tại đang dùng PRIMARY KEY lần lượt là station_id và line_id.
-- - next_departures cũng không có cột scenario_id nên cũng chỉ giữ MỘT snapshot hiện hành.
-- - predicted_stop_times và routing_edges_current thì có thể giữ baseline và scenario riêng.
--
-- Vì vậy, khi chạy với p_scenario_id IS NOT NULL:
-- - station_status_current / line_status_current / next_departures sẽ bị ghi đè theo ngữ cảnh scenario đó
-- - predicted_stop_times / routing_edges_current sẽ được tính riêng theo scenario_id
--
-- Quy tắc ưu tiên event:
-- - Nếu chạy baseline (p_scenario_id IS NULL): chỉ dùng event baseline có scenario_id IS NULL
-- - Nếu chạy scenario (p_scenario_id IS NOT NULL): lấy cả baseline + event của scenario đó,
--   nhưng event của scenario sẽ được ưu tiên hơn baseline nếu cùng target
--
-- Quy tắc severity đơn giản dùng trong pipeline:
-- - closed / suspended                          => đóng hoàn toàn
-- - maintenance / partial_suspend / disrupted  => gián đoạn nặng
-- - delayed                                    => chậm nhưng vẫn chạy
-- - normal / recovered / NULL                  => bình thường
-- ==================================================================================================

BEGIN;

-- ==================================================================================================
-- 0) Hàm phụ: trả về mức ưu tiên của status để dễ gom nhóm và so sánh
-- ==================================================================================================

-- Hàm này giúp pipeline chọn trạng thái “nặng” hơn khi nhiều nguồn cùng tác động.
CREATE OR REPLACE FUNCTION fn_status_rank(p_status TEXT)
RETURNS INTEGER
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE COALESCE(p_status, 'normal')
        WHEN 'closed'          THEN 60
        WHEN 'suspended'       THEN 55
        WHEN 'maintenance'     THEN 50
        WHEN 'partial_suspend' THEN 45
        WHEN 'disrupted'       THEN 40
        WHEN 'cancelled'       THEN 35
        WHEN 'delayed'         THEN 20
        WHEN 'recovered'       THEN 5
        WHEN 'normal'          THEN 0
        ELSE 0
    END;
$$;

-- ==================================================================================================
-- 1) station_status_current
-- ==================================================================================================

-- Procedure này tính trạng thái hiện hành của mọi ga.
-- Nó dùng dữ liệu nền từ stations và overlay event từ station_status_events.
-- Nếu chạy scenario, event của scenario sẽ override baseline event trên cùng ga.
CREATE OR REPLACE PROCEDURE sp_refresh_station_status_current(
    p_scenario_id TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Vì bảng station_status_current chỉ có 1 dòng / station_id nên mỗi lần refresh
    -- ta xóa toàn bộ và ghi lại đúng ngữ cảnh hiện hành.
    TRUNCATE TABLE station_status_current;

    INSERT INTO station_status_current (
        station_id,
        status,
        reason,
        is_boarding_allowed,
        is_alighting_allowed,
        scenario_id,
        updated_at
    )
    WITH candidate_events AS (
        -- Lấy các event đang hiệu lực cho đúng ngữ cảnh cần chạy.
        -- Baseline: chỉ lấy scenario_id IS NULL.
        -- Scenario: lấy cả baseline + scenario để scenario có thể override baseline.
        SELECT
            sse.station_id,
            sse.status,
            sse.event_category,
            sse.reason_code,
            sse.reason_text,
            sse.delay_min,
            sse.recorded_at,
            sse.effective_from,
            sse.station_status_event_id,
            sse.scenario_id,
            CASE
                WHEN p_scenario_id IS NOT NULL AND sse.scenario_id = p_scenario_id THEN 2
                WHEN sse.scenario_id IS NULL THEN 1
                ELSE 0
            END AS source_priority
        FROM station_status_events sse
        WHERE sse.effective_from <= now()
          AND (sse.effective_to IS NULL OR sse.effective_to >= now())
          AND (
                (p_scenario_id IS NULL AND sse.scenario_id IS NULL)
             OR (p_scenario_id IS NOT NULL AND (sse.scenario_id IS NULL OR sse.scenario_id = p_scenario_id))
          )
    ),
    latest_event AS (
        -- Chọn đúng 1 event cuối cùng cho mỗi ga theo thứ tự ưu tiên:
        -- 1) event của scenario
        -- 2) event baseline
        -- 3) effective_from mới hơn
        -- 4) recorded_at mới hơn
        -- 5) id lớn hơn để phá hòa
        SELECT DISTINCT ON (ce.station_id)
            ce.station_id,
            ce.status,
            ce.event_category,
            ce.reason_code,
            ce.reason_text,
            ce.delay_min,
            ce.scenario_id
        FROM candidate_events ce
        ORDER BY
            ce.station_id,
            ce.source_priority DESC,
            ce.effective_from DESC,
            ce.recorded_at DESC,
            ce.station_status_event_id DESC
    )
    SELECT
        s.station_id,
        -- Nếu không có event thì ga ở trạng thái normal.
        COALESCE(
            CASE WHEN le.status = 'recovered' THEN 'normal' ELSE le.status END,
            'normal'
        ) AS status,
        -- Lý do ưu tiên reason_text rồi reason_code rồi event_category.
        CASE
            WHEN le.station_id IS NULL THEN NULL
            ELSE COALESCE(le.reason_text, le.reason_code, le.event_category)
        END AS reason,
        -- Boarding bị cấm khi ga đóng / tạm dừng / bảo trì nặng.
        CASE
            WHEN COALESCE(CASE WHEN le.status = 'recovered' THEN 'normal' ELSE le.status END, 'normal')
                 IN ('closed', 'suspended', 'maintenance') THEN FALSE
            ELSE TRUE
        END AS is_boarding_allowed,
        -- Alighting dùng cùng rule với boarding trong mô hình hiện tại.
        CASE
            WHEN COALESCE(CASE WHEN le.status = 'recovered' THEN 'normal' ELSE le.status END, 'normal')
                 IN ('closed', 'suspended', 'maintenance') THEN FALSE
            ELSE TRUE
        END AS is_alighting_allowed,
        -- scenario_id của bảng current biểu diễn “ngữ cảnh hiện hành đang được dựng”.
        p_scenario_id AS scenario_id,
        now() AS updated_at
    FROM stations s
    LEFT JOIN latest_event le
      ON le.station_id = s.station_id
    WHERE s.is_active = TRUE;
END;
$$;

-- ==================================================================================================
-- 2) line_status_current
-- ==================================================================================================

-- Procedure này tính trạng thái hiện hành của từng tuyến.
-- Nó ưu tiên event trực tiếp trên line.
-- Nếu không có line event thì suy từ các trip event đang hiệu lực trên tuyến đó.
CREATE OR REPLACE PROCEDURE sp_refresh_line_status_current(
    p_scenario_id TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Bảng line_status_current cũng chỉ có 1 dòng / line_id nên refresh toàn phần.
    TRUNCATE TABLE line_status_current;

    INSERT INTO line_status_current (
        line_id,
        status,
        delay_min_avg,
        reason,
        scenario_id,
        updated_at
    )
    WITH candidate_line_events AS (
        -- Gom line event theo ngữ cảnh đang chạy.
        SELECT
            lse.line_id,
            lse.status,
            lse.event_category,
            lse.reason_code,
            lse.reason_text,
            lse.delay_min,
            lse.recorded_at,
            lse.effective_from,
            lse.line_status_event_id,
            lse.scenario_id,
            CASE
                WHEN p_scenario_id IS NOT NULL AND lse.scenario_id = p_scenario_id THEN 2
                WHEN lse.scenario_id IS NULL THEN 1
                ELSE 0
            END AS source_priority
        FROM line_status_events lse
        WHERE lse.effective_from <= now()
          AND (lse.effective_to IS NULL OR lse.effective_to >= now())
          AND (
                (p_scenario_id IS NULL AND lse.scenario_id IS NULL)
             OR (p_scenario_id IS NOT NULL AND (lse.scenario_id IS NULL OR lse.scenario_id = p_scenario_id))
          )
    ),
    latest_line_event AS (
        -- Chọn event trực tiếp trên tuyến có ưu tiên cao nhất.
        SELECT DISTINCT ON (cle.line_id)
            cle.line_id,
            cle.status,
            cle.event_category,
            cle.reason_code,
            cle.reason_text,
            cle.delay_min,
            cle.scenario_id
        FROM candidate_line_events cle
        ORDER BY
            cle.line_id,
            cle.source_priority DESC,
            cle.effective_from DESC,
            cle.recorded_at DESC,
            cle.line_status_event_id DESC
    ),
    candidate_trip_events AS (
        -- Lấy trip event đang hiệu lực và map trip -> line.
        SELECT
            t.line_id,
            tse.trip_id,
            tse.status,
            tse.delay_min,
            tse.reason_code,
            tse.reason_text,
            tse.event_category,
            tse.recorded_at,
            tse.effective_from,
            tse.trip_status_event_id,
            tse.scenario_id,
            CASE
                WHEN p_scenario_id IS NOT NULL AND tse.scenario_id = p_scenario_id THEN 2
                WHEN tse.scenario_id IS NULL THEN 1
                ELSE 0
            END AS source_priority
        FROM trip_status_events tse
        JOIN trips t
          ON t.trip_id = tse.trip_id
        WHERE t.is_active = TRUE
          AND tse.effective_from <= now()
          AND (tse.effective_to IS NULL OR tse.effective_to >= now())
          AND (
                (p_scenario_id IS NULL AND tse.scenario_id IS NULL)
             OR (p_scenario_id IS NOT NULL AND (tse.scenario_id IS NULL OR tse.scenario_id = p_scenario_id))
          )
    ),
    latest_trip_event_per_trip AS (
        -- Chọn event mới nhất / ưu tiên nhất cho từng trip.
        SELECT DISTINCT ON (cte.trip_id)
            cte.line_id,
            cte.trip_id,
            cte.status,
            cte.delay_min,
            cte.reason_code,
            cte.reason_text,
            cte.event_category
        FROM candidate_trip_events cte
        ORDER BY
            cte.trip_id,
            cte.source_priority DESC,
            cte.effective_from DESC,
            cte.recorded_at DESC,
            cte.trip_status_event_id DESC
    ),
    trip_rollup AS (
        -- Từ trip event, gom về mức tuyến.
        SELECT
            lt.line_id,
            AVG(COALESCE(lt.delay_min, 0))::numeric(8,2) AS delay_min_avg,
            MAX(fn_status_rank(CASE WHEN lt.status = 'recovered' THEN 'normal' ELSE lt.status END)) AS max_status_rank,
            COUNT(*) FILTER (WHERE COALESCE(lt.delay_min, 0) > 0 OR lt.status = 'delayed') AS delayed_trip_count
        FROM latest_trip_event_per_trip lt
        GROUP BY lt.line_id
    )
    SELECT
        l.line_id,
        -- Ưu tiên line event.
        -- Nếu không có line event thì suy từ trip_rollup.
        COALESCE(
            CASE
                WHEN lle.status = 'recovered' THEN 'normal'
                ELSE lle.status
            END,
            CASE
                WHEN COALESCE(tr.max_status_rank, 0) >= fn_status_rank('maintenance') THEN 'disrupted'
                WHEN COALESCE(tr.max_status_rank, 0) >= fn_status_rank('delayed') OR COALESCE(tr.delay_min_avg, 0) > 0 THEN 'delayed'
                ELSE 'normal'
            END,
            'normal'
        ) AS status,
        -- delay_min_avg lấy từ line event nếu line event là delayed; nếu không thì lấy từ trip rollup.
        COALESCE(
            CASE
                WHEN lle.status = 'delayed' THEN COALESCE(lle.delay_min, 0)::numeric(8,2)
                ELSE NULL
            END,
            tr.delay_min_avg,
            0::numeric(8,2)
        ) AS delay_min_avg,
        -- reason ưu tiên event trực tiếp của line.
        -- Nếu không có thì dùng reason suy từ trip event theo tuyến.
        COALESCE(
            CASE WHEN lle.line_id IS NOT NULL THEN COALESCE(lle.reason_text, lle.reason_code, lle.event_category) END,
            CASE
                WHEN COALESCE(tr.max_status_rank, 0) >= fn_status_rank('maintenance') THEN 'derived_from_trip_events'
                WHEN COALESCE(tr.max_status_rank, 0) >= fn_status_rank('delayed') THEN 'derived_from_trip_events'
                ELSE NULL
            END
        ) AS reason,
        p_scenario_id AS scenario_id,
        now() AS updated_at
    FROM lines l
    LEFT JOIN latest_line_event lle
      ON lle.line_id = l.line_id
    LEFT JOIN trip_rollup tr
      ON tr.line_id = l.line_id
    WHERE l.is_active = TRUE;
END;
$$;

-- ==================================================================================================
-- 3) routing_edges_current
-- ==================================================================================================

-- Procedure này tính lại graph hiện hành cho routing.
-- Nó kết hợp:
-- - edge base trong edges
-- - trạng thái hiện hành của station và line
-- - edge event trực tiếp
-- Khi chạy scenario thì vẫn có thể giữ song song baseline và scenario trong bảng này
-- nhờ unique index theo (base_edge_id, scenario_id).
CREATE OR REPLACE PROCEDURE sp_refresh_routing_edges_current(
    p_scenario_id TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Chỉ xóa đúng partition logic mà ta sắp ghi lại.
    IF p_scenario_id IS NULL THEN
        DELETE FROM routing_edges_current
        WHERE scenario_id IS NULL;
    ELSE
        DELETE FROM routing_edges_current
        WHERE scenario_id = p_scenario_id;
    END IF;

    INSERT INTO routing_edges_current (
        base_edge_id,
        from_station_id,
        to_station_id,
        line_id,
        base_travel_time_min,
        adjusted_travel_time_min,
        is_available,
        status_source,
        reason,
        scenario_id,
        calculated_at,
        created_at
    )
    WITH candidate_edge_events AS (
        -- Lấy edge event đúng ngữ cảnh.
        SELECT
            ese.edge_id,
            ese.status,
            ese.delay_min,
            ese.reason_code,
            ese.reason_text,
            ese.event_category,
            ese.recorded_at,
            ese.effective_from,
            ese.edge_status_event_id,
            ese.scenario_id,
            CASE
                WHEN p_scenario_id IS NOT NULL AND ese.scenario_id = p_scenario_id THEN 2
                WHEN ese.scenario_id IS NULL THEN 1
                ELSE 0
            END AS source_priority
        FROM edge_status_events ese
        WHERE ese.effective_from <= now()
          AND (ese.effective_to IS NULL OR ese.effective_to >= now())
          AND (
                (p_scenario_id IS NULL AND ese.scenario_id IS NULL)
             OR (p_scenario_id IS NOT NULL AND (ese.scenario_id IS NULL OR ese.scenario_id = p_scenario_id))
          )
    ),
    latest_edge_event AS (
        -- Chọn edge event cuối cùng cho từng cạnh.
        SELECT DISTINCT ON (cee.edge_id)
            cee.edge_id,
            cee.status,
            cee.delay_min,
            cee.reason_code,
            cee.reason_text,
            cee.event_category
        FROM candidate_edge_events cee
        ORDER BY
            cee.edge_id,
            cee.source_priority DESC,
            cee.effective_from DESC,
            cee.recorded_at DESC,
            cee.edge_status_event_id DESC
    )
    SELECT
        e.edge_id AS base_edge_id,
        e.from_station_id,
        e.to_station_id,
        e.line_id,
        e.travel_time_min AS base_travel_time_min,
        -- adjusted_travel_time_min phản ánh thời gian đi hiện hành sau khi áp bất thường.
        CASE
            -- Nếu cạnh bị đóng / suspend / maintenance nặng thì coi travel time = 0 vì không dùng được.
            WHEN COALESCE(lee.status, lsc.status, 'normal') IN ('closed', 'suspended', 'maintenance') THEN 0
            -- Nếu một trong hai ga đầu/cuối không mở boarding/alighting thì cạnh cũng bị vô hiệu.
            WHEN COALESCE(ss_from.is_boarding_allowed, TRUE) = FALSE THEN 0
            WHEN COALESCE(ss_to.is_alighting_allowed, TRUE) = FALSE THEN 0
            -- Nếu edge hoặc line bị delayed thì cộng thêm delay.
            WHEN COALESCE(lee.status, 'normal') = 'delayed' THEN e.travel_time_min + COALESCE(lee.delay_min, 0)
            WHEN COALESCE(lsc.status, 'normal') = 'delayed' THEN e.travel_time_min + CEIL(COALESCE(lsc.delay_min_avg, 0))::INTEGER
            -- Nếu line đang disrupted / partial suspend nhưng edge chưa bị đóng, vẫn giữ cạnh nhưng phạt thêm một hệ số nhẹ.
            WHEN COALESCE(lee.status, 'normal') IN ('partial_suspend', 'disrupted') THEN e.travel_time_min + GREATEST(COALESCE(lee.delay_min, 0), 3)
            WHEN COALESCE(lsc.status, 'normal') = 'disrupted' THEN e.travel_time_min + GREATEST(CEIL(COALESCE(lsc.delay_min_avg, 0))::INTEGER, 3)
            -- Nếu không có bất thường thì giữ nguyên base travel time.
            ELSE e.travel_time_min
        END AS adjusted_travel_time_min,
        -- is_available cho biết cạnh còn dùng được cho routing hay không.
        CASE
            WHEN COALESCE(lee.status, lsc.status, 'normal') IN ('closed', 'suspended', 'maintenance') THEN FALSE
            WHEN COALESCE(ss_from.is_boarding_allowed, TRUE) = FALSE THEN FALSE
            WHEN COALESCE(ss_to.is_alighting_allowed, TRUE) = FALSE THEN FALSE
            ELSE TRUE
        END AS is_available,
        -- status_source chỉ ra nguồn override chính.
        CASE
            WHEN lee.edge_id IS NOT NULL THEN 'edge_event'
            WHEN lsc.status <> 'normal' THEN 'line_current'
            WHEN COALESCE(ss_from.is_boarding_allowed, TRUE) = FALSE OR COALESCE(ss_to.is_alighting_allowed, TRUE) = FALSE THEN 'station_current'
            WHEN p_scenario_id IS NOT NULL THEN 'scenario'
            ELSE 'normal'
        END AS status_source,
        -- reason ưu tiên edge event rồi tới line current rồi station current.
        COALESCE(
            COALESCE(lee.reason_text, lee.reason_code, lee.event_category),
            lsc.reason,
            CASE
                WHEN COALESCE(ss_from.is_boarding_allowed, TRUE) = FALSE THEN CONCAT('from_station_', ss_from.status)
                WHEN COALESCE(ss_to.is_alighting_allowed, TRUE) = FALSE THEN CONCAT('to_station_', ss_to.status)
                ELSE NULL
            END
        ) AS reason,
        p_scenario_id AS scenario_id,
        now() AS calculated_at,
        now() AS created_at
    FROM edges e
    LEFT JOIN latest_edge_event lee
      ON lee.edge_id = e.edge_id
    LEFT JOIN line_status_current lsc
      ON lsc.line_id = e.line_id
    LEFT JOIN station_status_current ss_from
      ON ss_from.station_id = e.from_station_id
    LEFT JOIN station_status_current ss_to
      ON ss_to.station_id = e.to_station_id
    WHERE e.is_active = TRUE;
END;
$$;

-- ==================================================================================================
-- 4) predicted_stop_times
-- ==================================================================================================

-- Procedure này tạo dự đoán stop-level.
-- Dữ liệu nền lấy từ v_active_trip_stop_times.
-- Overlay bất thường lấy từ trip_status_events + line_status_current + station_status_current.
-- predicted_stop_times có scenario_id nên có thể lưu baseline và scenario song song.
CREATE OR REPLACE PROCEDURE sp_refresh_predicted_stop_times(
    p_service_date DATE DEFAULT CURRENT_DATE,
    p_scenario_id TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Chỉ xóa đúng phân vùng logic sắp được tính lại.
    IF p_scenario_id IS NULL THEN
        DELETE FROM predicted_stop_times
        WHERE service_date = p_service_date
          AND scenario_id IS NULL;
    ELSE
        DELETE FROM predicted_stop_times
        WHERE service_date = p_service_date
          AND scenario_id = p_scenario_id;
    END IF;

    INSERT INTO predicted_stop_times (
        updated_at,
        service_date,
        timetable_id,
        trip_id,
        line_id,
        station_id,
        line_station_order,
        stop_sequence,
        scheduled_arrival_time,
        scheduled_arrival_day_offset,
        scheduled_departure_time,
        scheduled_departure_day_offset,
        predicted_arrival_time,
        predicted_arrival_day_offset,
        predicted_departure_time,
        predicted_departure_day_offset,
        predicted_arrival_at,
        predicted_departure_at,
        delay_min,
        status,
        prediction_source,
        scenario_id,
        created_at
    )
    WITH candidate_trip_events AS (
        -- Lấy trip event đúng ngữ cảnh.
        SELECT
            tse.trip_id,
            tse.status,
            tse.delay_min,
            tse.reason_code,
            tse.reason_text,
            tse.event_category,
            tse.recorded_at,
            tse.effective_from,
            tse.trip_status_event_id,
            tse.scenario_id,
            CASE
                WHEN p_scenario_id IS NOT NULL AND tse.scenario_id = p_scenario_id THEN 2
                WHEN tse.scenario_id IS NULL THEN 1
                ELSE 0
            END AS source_priority
        FROM trip_status_events tse
        WHERE tse.effective_from <= now()
          AND (tse.effective_to IS NULL OR tse.effective_to >= now())
          AND (
                (p_scenario_id IS NULL AND tse.scenario_id IS NULL)
             OR (p_scenario_id IS NOT NULL AND (tse.scenario_id IS NULL OR tse.scenario_id = p_scenario_id))
          )
    ),
    latest_trip_event AS (
        -- Chọn đúng một trip event cuối cùng cho mỗi trip.
        SELECT DISTINCT ON (cte.trip_id)
            cte.trip_id,
            cte.status,
            cte.delay_min,
            cte.reason_code,
            cte.reason_text,
            cte.event_category
        FROM candidate_trip_events cte
        ORDER BY
            cte.trip_id,
            cte.source_priority DESC,
            cte.effective_from DESC,
            cte.recorded_at DESC,
            cte.trip_status_event_id DESC
    ),
    stop_src AS (
        -- Lấy toàn bộ stop nền của ngày service cần tính.
        SELECT
            v.service_date,
            v.timetable_id,
            v.trip_id,
            v.line_id,
            v.station_id,
            v.line_station_order,
            v.stop_sequence,
            v.scheduled_arrival_time,
            v.scheduled_arrival_day_offset,
            v.scheduled_departure_time,
            v.scheduled_departure_day_offset,
            v.scheduled_arrival_at,
            v.scheduled_departure_at,
            lte.status AS trip_status,
            COALESCE(lte.delay_min, 0) AS trip_delay_min,
            lsc.status AS line_status,
            COALESCE(lsc.delay_min_avg, 0) AS line_delay_min_avg,
            ssc.status AS station_status,
            ssc.is_boarding_allowed,
            ssc.is_alighting_allowed
        FROM v_active_trip_stop_times v
        LEFT JOIN latest_trip_event lte
          ON lte.trip_id = v.trip_id
        LEFT JOIN line_status_current lsc
          ON lsc.line_id = v.line_id
        LEFT JOIN station_status_current ssc
          ON ssc.station_id = v.station_id
        WHERE v.service_date = p_service_date
    ),
    calc AS (
        -- Ở đây áp rule dự đoán chính.
        SELECT
            s.*,
            -- applied_delay_min ưu tiên trip delay; nếu không có thì dùng delay của line.
            CASE
                WHEN COALESCE(CASE WHEN s.trip_status = 'recovered' THEN 'normal' ELSE s.trip_status END, 'normal') = 'delayed'
                    THEN GREATEST(COALESCE(s.trip_delay_min, 0), 0)
                WHEN COALESCE(s.line_status, 'normal') = 'delayed'
                    THEN GREATEST(CEIL(COALESCE(s.line_delay_min_avg, 0))::INTEGER, 0)
                WHEN COALESCE(s.line_status, 'normal') = 'disrupted'
                    THEN GREATEST(CEIL(COALESCE(s.line_delay_min_avg, 0))::INTEGER, 3)
                ELSE 0
            END AS applied_delay_min,
            -- final_status map về tập trạng thái hợp lệ của predicted_stop_times.
            CASE
                -- Nếu trip bị cancel / đóng / suspend thì coi stop bị cancel.
                WHEN COALESCE(CASE WHEN s.trip_status = 'recovered' THEN 'normal' ELSE s.trip_status END, 'normal') IN ('cancelled', 'closed', 'suspended')
                    THEN 'cancelled'
                -- Nếu line hiện hành đang đóng / suspend / maintenance thì cũng coi trip stop bị cancel.
                WHEN COALESCE(s.line_status, 'normal') IN ('closed', 'suspended', 'maintenance')
                    THEN 'cancelled'
                -- Nếu ga hiện hành không cho boarding/alighting thì stop này bị skip.
                WHEN COALESCE(s.station_status, 'normal') IN ('closed', 'suspended', 'maintenance')
                    THEN 'skipped'
                -- Nếu có delay ở trip hoặc line thì đánh dấu delayed.
                WHEN COALESCE(CASE WHEN s.trip_status = 'recovered' THEN 'normal' ELSE s.trip_status END, 'normal') = 'delayed'
                    THEN 'delayed'
                WHEN COALESCE(s.line_status, 'normal') IN ('delayed', 'disrupted')
                    THEN 'delayed'
                -- Mặc định đúng giờ.
                ELSE 'on_time'
            END AS final_status
        FROM stop_src s
    )
    SELECT
        now() AS updated_at,
        c.service_date,
        c.timetable_id,
        c.trip_id,
        c.line_id,
        c.station_id,
        c.line_station_order,
        c.stop_sequence,
        c.scheduled_arrival_time,
        c.scheduled_arrival_day_offset,
        c.scheduled_departure_time,
        c.scheduled_departure_day_offset,
        -- predicted_arrival_time = time component của timestamp dự đoán.
        CASE
            WHEN c.final_status = 'cancelled' THEN c.scheduled_arrival_time
            ELSE (c.scheduled_arrival_at + make_interval(mins => c.applied_delay_min))::time
        END AS predicted_arrival_time,
        -- day offset dự đoán được tính lại từ timestamp tuyệt đối.
        CASE
            WHEN c.final_status = 'cancelled' THEN c.scheduled_arrival_day_offset
            ELSE GREATEST(((c.scheduled_arrival_at + make_interval(mins => c.applied_delay_min))::date - c.service_date), 0)::smallint
        END AS predicted_arrival_day_offset,
        -- predicted_departure_time = time component của timestamp dự đoán.
        CASE
            WHEN c.final_status = 'cancelled' THEN c.scheduled_departure_time
            ELSE (c.scheduled_departure_at + make_interval(mins => c.applied_delay_min))::time
        END AS predicted_departure_time,
        -- day offset departure dự đoán.
        CASE
            WHEN c.final_status = 'cancelled' THEN c.scheduled_departure_day_offset
            ELSE GREATEST(((c.scheduled_departure_at + make_interval(mins => c.applied_delay_min))::date - c.service_date), 0)::smallint
        END AS predicted_departure_day_offset,
        -- Timestamp tuyệt đối cho arrival.
        CASE
            WHEN c.final_status = 'cancelled' THEN c.scheduled_arrival_at
            ELSE c.scheduled_arrival_at + make_interval(mins => c.applied_delay_min)
        END AS predicted_arrival_at,
        -- Timestamp tuyệt đối cho departure.
        CASE
            WHEN c.final_status = 'cancelled' THEN c.scheduled_departure_at
            ELSE c.scheduled_departure_at + make_interval(mins => c.applied_delay_min)
        END AS predicted_departure_at,
        c.applied_delay_min AS delay_min,
        c.final_status AS status,
        -- prediction_source phân biệt baseline realtime và scenario simulation.
        CASE
            WHEN p_scenario_id IS NOT NULL THEN 'simulation_engine'
            ELSE 'realtime_feed'
        END AS prediction_source,
        p_scenario_id AS scenario_id,
        now() AS created_at
    FROM calc c;
END;
$$;

-- ==================================================================================================
-- 5) next_departures
-- ==================================================================================================

-- Procedure này tạo snapshot các chuyến sắp rời để BE/FE đọc nhanh.
-- Vì bảng next_departures không có scenario_id trong schema hiện tại,
-- nên mỗi lần chạy chỉ giữ một “ngữ cảnh active” duy nhất.
--
-- Để tránh phụ thuộc mơ hồ vào v_latest_predicted_stop_times,
-- procedure này tự chọn bản predicted mới nhất đúng theo p_scenario_id.
CREATE OR REPLACE PROCEDURE sp_refresh_next_departures(
    p_service_date DATE DEFAULT CURRENT_DATE,
    p_scenario_id TEXT DEFAULT NULL,
    p_station_id TEXT DEFAULT NULL,
    p_minutes_ahead INTEGER DEFAULT 60
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Xóa snapshot hiện có theo ngày / ga cần refresh.
    DELETE FROM next_departures
    WHERE service_date = p_service_date
      AND (p_station_id IS NULL OR station_id = p_station_id);

    INSERT INTO next_departures (
        next_departure_id,
        updated_at,
        service_date,
        station_id,
        line_id,
        direction_id,
        direction_label,
        trip_id,
        timetable_id,
        line_station_order,
        stop_sequence,
        headsign,
        predicted_departure_time,
        predicted_departure_day_offset,
        predicted_departure_at,
        delay_min,
        status,
        created_at
    )
    WITH latest_prediction AS (
        -- Chọn bản predicted mới nhất cho mỗi stop của đúng ngữ cảnh cần đọc.
        SELECT DISTINCT ON (pst.service_date, pst.timetable_id)
            pst.service_date,
            pst.timetable_id,
            pst.trip_id,
            pst.line_id,
            pst.station_id,
            pst.line_station_order,
            pst.stop_sequence,
            pst.predicted_departure_time,
            pst.predicted_departure_day_offset,
            pst.predicted_departure_at,
            pst.delay_min,
            pst.status,
            pst.updated_at,
            pst.scenario_id
        FROM predicted_stop_times pst
        WHERE pst.service_date = p_service_date
          AND (
                (p_scenario_id IS NULL AND pst.scenario_id IS NULL)
             OR (p_scenario_id IS NOT NULL AND pst.scenario_id = p_scenario_id)
          )
        ORDER BY
            pst.service_date,
            pst.timetable_id,
            pst.updated_at DESC,
            pst.created_at DESC
    )
    SELECT
        -- Dùng sequence thật của bảng để sinh id.
        nextval(pg_get_serial_sequence('next_departures', 'next_departure_id')) AS next_departure_id,
        now() AS updated_at,
        lp.service_date,
        lp.station_id,
        lp.line_id,
        tr.direction_id,
        COALESCE(tr.direction_name, tr.headsign, 'unknown') AS direction_label,
        lp.trip_id,
        lp.timetable_id,
        lp.line_station_order,
        lp.stop_sequence,
        tr.headsign,
        lp.predicted_departure_time,
        lp.predicted_departure_day_offset,
        lp.predicted_departure_at,
        lp.delay_min,
        lp.status,
        now() AS created_at
    FROM latest_prediction lp
    JOIN trips tr
      ON tr.trip_id = lp.trip_id
     AND tr.line_id = lp.line_id
    JOIN station_status_current ssc
      ON ssc.station_id = lp.station_id
    WHERE (p_station_id IS NULL OR lp.station_id = p_station_id)
      -- Snapshot chỉ lấy những chuyến còn rời trong khoảng thời gian nhìn trước.
      AND lp.predicted_departure_at IS NOT NULL
      AND lp.predicted_departure_at >= now()
      AND lp.predicted_departure_at < now() + make_interval(mins => p_minutes_ahead)
      -- FE thường chỉ cần các chuyến còn chạy được.
      AND lp.status IN ('on_time', 'delayed')
      -- Chỉ giữ các ga còn cho phép boarding.
      AND ssc.is_boarding_allowed = TRUE;
END;
$$;

-- ==================================================================================================
-- 6) master procedure
-- ==================================================================================================

CREATE OR REPLACE PROCEDURE sp_run_operational_etl(
    p_service_date DATE DEFAULT CURRENT_DATE,
    p_scenario_id TEXT DEFAULT NULL,
    p_minutes_ahead INTEGER DEFAULT 1440
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_error_message TEXT;
    v_error_detail  TEXT;
    v_error_hint    TEXT;
    v_error_context TEXT;
BEGIN
    -- STEP 1: refresh station status
    BEGIN
        CALL sp_refresh_station_status_current(p_scenario_id);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_error_message = MESSAGE_TEXT,
            v_error_detail  = PG_EXCEPTION_DETAIL,
            v_error_hint    = PG_EXCEPTION_HINT,
            v_error_context = PG_EXCEPTION_CONTEXT;

        RAISE EXCEPTION
            'ETL failed at step sp_refresh_station_status_current. message=%, detail=%, hint=%',
            v_error_message, COALESCE(v_error_detail, ''), COALESCE(v_error_hint, '');
    END;

    -- STEP 2: refresh line status
    BEGIN
        CALL sp_refresh_line_status_current(p_scenario_id);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_error_message = MESSAGE_TEXT,
            v_error_detail  = PG_EXCEPTION_DETAIL,
            v_error_hint    = PG_EXCEPTION_HINT,
            v_error_context = PG_EXCEPTION_CONTEXT;

        RAISE EXCEPTION
            'ETL failed at step sp_refresh_line_status_current. message=%, detail=%, hint=%',
            v_error_message, COALESCE(v_error_detail, ''), COALESCE(v_error_hint, '');
    END;

    -- STEP 3: refresh routing edges
    BEGIN
        CALL sp_refresh_routing_edges_current(p_scenario_id);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_error_message = MESSAGE_TEXT,
            v_error_detail  = PG_EXCEPTION_DETAIL,
            v_error_hint    = PG_EXCEPTION_HINT,
            v_error_context = PG_EXCEPTION_CONTEXT;

        RAISE EXCEPTION
            'ETL failed at step sp_refresh_routing_edges_current. message=%, detail=%, hint=%',
            v_error_message, COALESCE(v_error_detail, ''), COALESCE(v_error_hint, '');
    END;

    -- STEP 4: refresh predicted stop times
    BEGIN
        CALL sp_refresh_predicted_stop_times(p_service_date, p_scenario_id);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_error_message = MESSAGE_TEXT,
            v_error_detail  = PG_EXCEPTION_DETAIL,
            v_error_hint    = PG_EXCEPTION_HINT,
            v_error_context = PG_EXCEPTION_CONTEXT;

        RAISE EXCEPTION
            'ETL failed at step sp_refresh_predicted_stop_times. message=%, detail=%, hint=%',
            v_error_message, COALESCE(v_error_detail, ''), COALESCE(v_error_hint, '');
    END;

    -- STEP 5: refresh next departures
    BEGIN
        CALL sp_refresh_next_departures(p_service_date, p_scenario_id, NULL, p_minutes_ahead);
    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_error_message = MESSAGE_TEXT,
            v_error_detail  = PG_EXCEPTION_DETAIL,
            v_error_hint    = PG_EXCEPTION_HINT,
            v_error_context = PG_EXCEPTION_CONTEXT;

        RAISE EXCEPTION
            'ETL failed at step sp_refresh_next_departures. message=%, detail=%, hint=%',
            v_error_message, COALESCE(v_error_detail, ''), COALESCE(v_error_hint, '');
    END;
END;
$$;

COMMIT;
