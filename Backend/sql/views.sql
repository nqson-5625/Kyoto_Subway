-- ==================================================================================================
-- 1) v_service_dates_base
--
-- Mục đích:
-- - Nở service_calendar thành từng ngày cụ thể theo lịch cơ sở.
-- - View này CHƯA áp service_exceptions.
--
-- Ý nghĩa:
-- - Nếu service weekday chạy từ 2026-05-01 đến 2026-05-31 và bật Monday..Friday,
--   thì view này sẽ tạo ra tất cả các ngày thứ Hai..thứ Sáu trong khoảng đó.
-- ==================================================================================================
CREATE OR REPLACE VIEW v_service_dates_base AS
SELECT
    -- service_id: mã nhóm lịch cơ sở lấy nguyên từ service_calendar.service_id.
    -- Đây là khóa nhận diện service sẽ được áp cho trip ở bảng trips.
    sc.service_id,

    -- service_date: ngày cụ thể được nở ra từ khoảng service_calendar.start_date..end_date.
    -- Chỉ những ngày có thứ trong tuần được bật (monday..sunday) mới xuất hiện ở view này.
    gs.service_date::DATE AS service_date
FROM service_calendar sc
CROSS JOIN LATERAL generate_series(
    sc.start_date,
    sc.end_date,
    INTERVAL '1 day'
) AS gs(service_date)
WHERE
    (
        EXTRACT(ISODOW FROM gs.service_date) = 1 AND sc.monday
    ) OR (
        EXTRACT(ISODOW FROM gs.service_date) = 2 AND sc.tuesday
    ) OR (
        EXTRACT(ISODOW FROM gs.service_date) = 3 AND sc.wednesday
    ) OR (
        EXTRACT(ISODOW FROM gs.service_date) = 4 AND sc.thursday
    ) OR (
        EXTRACT(ISODOW FROM gs.service_date) = 5 AND sc.friday
    ) OR (
        EXTRACT(ISODOW FROM gs.service_date) = 6 AND sc.saturday
    ) OR (
        EXTRACT(ISODOW FROM gs.service_date) = 7 AND sc.sunday
    );

-- ==================================================================================================
-- 2) v_service_dates_active
--
-- Mục đích:
-- - Trả về service nào THẬT SỰ active trong từng ngày sau khi áp service_exceptions.
--
-- Logic:
-- - lấy từ lịch cơ sở
-- - bỏ các dòng removed
-- - cộng thêm các dòng added
--
-- Đây là view rất quan trọng vì:
-- - xử lý đúng holiday rơi vào weekday
-- - BE và algorithm không phải tự resolve service_exceptions nữa
-- ==================================================================================================
CREATE OR REPLACE VIEW v_service_dates_active AS
SELECT
    -- service_id: mã service thực sự còn hiệu lực trong ngày sau khi đã trừ ngoại lệ removed.
    -- Nguồn gốc cuối cùng vẫn là service_calendar.service_id hoặc service_exceptions.service_id.
    base.service_id,

    -- service_date: ngày service thực tế còn active sau khi xét service_exceptions.
    -- Đây là ngày mà BE/algorithm nên dùng khi muốn biết trip có chạy hay không.
    base.service_date
FROM v_service_dates_base base
LEFT JOIN service_exceptions se
       ON se.service_id = base.service_id
      AND se.service_date = base.service_date
WHERE se.service_exception_id IS NULL
   OR se.exception_type <> 'removed'

UNION

SELECT
    se.service_id,  -- mã service được cộng thêm thủ công bởi service_exceptions với exception_type = 'added'.
    se.service_date -- ngày được thêm service ngoài lịch cơ sở.
FROM service_exceptions se
WHERE se.exception_type = 'added';

-- ==================================================================================================
-- 3) v_active_trip_stop_times
--
-- Mục đích:
-- - Đây là view quan trọng nhất cho BE.
-- - Mỗi dòng là một stop của một trip trong MỘT NGÀY THỰC TẾ mà trip đó thực sự chạy.
--
-- View này giúp trả lời trực tiếp:
-- - ngày X trip nào chạy
-- - trip đó tới ga nào lúc mấy giờ
-- - trip đó rời ga nào lúc mấy giờ
--
-- Ghi chú:
-- - scheduled_arrival_at / scheduled_departure_at là timestamp tuyệt đối local,
--   được ghép từ service_date + TIME + day_offset
-- - có giữ cả service_name, service_type, holiday flag để BE hiển thị dễ hơn
-- ==================================================================================================
CREATE OR REPLACE VIEW v_active_trip_stop_times AS
SELECT
    -- service_date: ngày service thực tế mà trip chạy, lấy từ v_service_dates_active.
    -- Đây là mốc ngày để ghép với TIME + day_offset trong timetable thành timestamp tuyệt đối.
    vsda.service_date,

    tr.trip_id,     -- mã chuyến tàu từ trips.trip_id.
    tr.line_id,     -- mã tuyến mà trip thuộc về, lấy từ trips.line_id.
    l.line_name,    -- tên tuyến đọc từ lines.line_name để BE hiển thị mà không cần join thêm.
    l.line_code,    -- mã ngắn của tuyến từ lines.line_code, ví dụ K hoặc T.
    tr.service_id,  -- mã nhóm lịch áp cho trip, lấy từ trips.service_id.
    sc.service_name,-- tên mô tả của nhóm lịch từ service_calendar.service_name.
    sc.service_type,-- loại lịch từ service_calendar.service_type, ví dụ weekday / saturday / holiday.
    tr.direction_id,-- hướng chuẩn mức số của trip từ trips.direction_id.
    tr.direction_name,    -- nhãn hướng chuẩn để hiển thị, lấy từ trips.direction_name.
    tr.origin_station_id, -- ga đầu hành trình của trip, lấy từ trips.origin_station_id.
    
    -- tên ga đầu hành trình, join từ stations.station_name theo origin_station_id.
    os.station_name AS origin_station_name,
    
    -- ga cuối hành trình của trip, lấy từ trips.destination_station_id.
    tr.destination_station_id,

    -- tên ga cuối hành trình, join từ stations.station_name theo destination_station_id.
    ds.station_name AS destination_station_name,
    
    tr.headsign,    -- nhãn đích đến/ngữ cảnh hiển thị của chuyến, lấy từ trips.headsign.

    tt.timetable_id,-- mã dòng timetable gốc, định danh duy nhất một stop của trip trong bảng timetable.
    tt.station_id,  -- mã ga của stop hiện tại, lấy từ timetable.station_id.
    s.station_name, -- tên ga của stop hiện tại, join từ stations.station_name.
    
    -- line_station_order: vị trí ga này trên tuyến, lấy từ timetable.line_station_order.
    -- Giá trị này bám theo station_lines.station_order của đúng station trên đúng line.
    tt.line_station_order,

    tt.stop_sequence,-- thứ tự điểm dừng của ga này trong chính trip, lấy từ timetable.stop_sequence.

    -- scheduled_arrival_day_offset: số ngày cộng thêm vào service_date để ra ngày đến theo lịch.
    -- Hữu ích cho chuyến qua nửa đêm, lấy từ timetable.scheduled_arrival_day_offset.
    tt.scheduled_arrival_day_offset,

    -- giờ đến theo lịch trong ngày service, lấy từ timetable.scheduled_arrival_time.
    tt.scheduled_arrival_time,

    -- số ngày cộng thêm vào service_date để ra ngày rời theo lịch.
    tt.scheduled_departure_day_offset,

    -- giờ rời theo lịch trong ngày service, lấy từ timetable.scheduled_departure_time.
    tt.scheduled_departure_time,

    -- scheduled_arrival_at: thời điểm đến theo lịch ở dạng timestamptz tuyệt đối.
    -- Công thức: service_date + scheduled_arrival_day_offset + scheduled_arrival_time.
    (
        (vsda.service_date + tt.scheduled_arrival_day_offset)
        + tt.scheduled_arrival_time
    )::timestamptz AS scheduled_arrival_at,

    -- scheduled_departure_at: thời điểm rời theo lịch ở dạng timestamptz tuyệt đối.
    -- Công thức: service_date + scheduled_departure_day_offset + scheduled_departure_time.
    (
        (vsda.service_date + tt.scheduled_departure_day_offset)
        + tt.scheduled_departure_time
    )::timestamptz AS scheduled_departure_at,

    tt.pickup_allowed,  -- cờ cho biết stop này có cho phép hành khách lên tàu hay không, lấy từ timetable.pickup_allowed.
    tt.dropoff_allowed, -- cờ cho biết stop này có cho phép hành khách xuống tàu hay không, lấy từ timetable.dropoff_allowed.

    -- is_holiday: true nếu service_date trùng một ngày trong holiday_dates.holiday_date.
    -- Cột này là cờ suy diễn để BE/algorithm biết hôm đó là ngày nghỉ lễ hay không.
    (hd.holiday_date IS NOT NULL) AS is_holiday
FROM v_service_dates_active vsda
JOIN trips tr
  ON tr.service_id = vsda.service_id
 AND tr.is_active = TRUE
JOIN timetable tt
  ON tt.trip_id = tr.trip_id
 AND tt.line_id = tr.line_id
JOIN service_calendar sc
  ON sc.service_id = tr.service_id
JOIN lines l
  ON l.line_id = tr.line_id
JOIN stations s
  ON s.station_id = tt.station_id
LEFT JOIN stations os
  ON os.station_id = tr.origin_station_id
LEFT JOIN stations ds
  ON ds.station_id = tr.destination_station_id
LEFT JOIN holiday_dates hd
  ON hd.holiday_date = vsda.service_date;

-- ==================================================================================================
-- 4) v_active_trip_segments
--
-- Mục đích:
-- - View này dành chủ yếu cho 2 algorithm.
-- - Mỗi dòng là một đoạn ride giữa 2 stop liên tiếp của cùng một trip trong một ngày thực tế.
--
-- View này giúp:
-- - dựng segment theo ngày
-- - tính travel_seconds
-- - không phải tự join stop_sequence + 1 ở code
-- ==================================================================================================
CREATE OR REPLACE VIEW v_active_trip_segments AS
SELECT
    a.service_date, -- ngày service thực tế của segment, kế thừa từ v_active_trip_stop_times.

    a.trip_id,      -- mã chuyến mà segment này thuộc về.
    a.line_id,      -- mã tuyến của trip/segment.
    a.line_name,    -- tên tuyến để hiển thị thuận tiện.
    a.line_code,    -- mã ngắn của tuyến.
    a.service_id,   -- mã nhóm lịch áp cho trip.
    a.service_name, -- tên nhóm lịch lấy từ service_calendar qua view stop_times.
    a.service_type, -- loại lịch của service.
    a.direction_id, -- hướng chuẩn mức số của trip.
    a.direction_name,   -- nhãn hướng của trip.
    a.headsign,     -- nhãn đích đến của trip.

    -- timetable_id của stop xuất phát trong segment.
    a.timetable_id AS from_timetable_id,

    -- mã ga xuất phát của segment, thực chất là timetable.station_id của stop trước.
    a.station_id AS from_station_id,

    -- tên ga xuất phát của segment.
    a.station_name AS from_station_name,

    -- vị trí ga xuất phát trên tuyến.
    a.line_station_order AS from_line_station_order,

    -- thứ tự stop xuất phát trong trip.
    a.stop_sequence AS from_stop_sequence,

    -- thời điểm rời ga xuất phát theo lịch tuyệt đối, lấy từ stop trước.
    a.scheduled_departure_at AS departure_at,

    -- timetable_id của stop đích trong segment.
    b.timetable_id AS to_timetable_id,

    -- mã ga đích của segment, là station_id của stop kế tiếp.
    b.station_id AS to_station_id,

    -- tên ga đích của segment.
    b.station_name AS to_station_name,

    -- vị trí ga đích trên tuyến.
    b.line_station_order AS to_line_station_order,
    
    -- thứ tự stop đích trong trip.
    b.stop_sequence AS to_stop_sequence,
    
    -- thời điểm đến ga đích theo lịch tuyệt đối, lấy từ stop kế tiếp.
    b.scheduled_arrival_at AS arrival_at,

    -- travel_seconds: thời gian chạy giữa 2 stop liên tiếp tính bằng giây.
    -- Công thức = arrival_at của stop sau - departure_at của stop trước.
    EXTRACT(EPOCH FROM (b.scheduled_arrival_at - a.scheduled_departure_at))::INTEGER AS travel_seconds
FROM v_active_trip_stop_times a
JOIN v_active_trip_stop_times b
  ON b.service_date = a.service_date
 AND b.trip_id = a.trip_id
 AND b.line_id = a.line_id
 AND b.stop_sequence = a.stop_sequence + 1;

-- ==================================================================================================
-- 5) v_routing_edges_active
--
-- Mục đích:
-- - Đây là view downstream quan trọng nhất cho team algorithm.
-- - Gộp 2 loại edge:
--   + ride edge: đi tàu giữa 2 stop liên tiếp
--   + transfer edge: đi bộ/trung chuyển giữa 2 ga
--
-- Ý nghĩa:
-- - algorithm chỉ cần đọc một view là đã có graph theo ngày thực tế
-- - ride edge có departure_at / arrival_at
-- - transfer edge có travel_seconds
--
-- Ghi chú:
-- - transfer edge được nở theo service_date để graph theo ngày luôn đầy đủ
-- ==================================================================================================
CREATE OR REPLACE VIEW v_routing_edges_active AS
SELECT
    -- service_date: ngày service thực tế của cạnh trong graph.
    -- Với ride edge, đây là ngày mà segment tàu thực sự chạy.
    seg.service_date,

    -- edge_type: loại cạnh trong graph routing.
    -- 'ride' = di chuyển bằng tàu giữa 2 stop liên tiếp; 'transfer' = đi bộ/trung chuyển giữa 2 ga.
    'ride'::TEXT AS edge_type,

    seg.trip_id,    -- mã chuyến áp dụng cho ride edge; transfer edge sẽ để NULL.
    seg.line_id,    -- mã tuyến của ride edge; transfer edge không thuộc một tuyến cụ thể nên để NULL.
    seg.direction_id,   -- hướng chuẩn mức số của trip cho ride edge; transfer edge để NULL.
    seg.direction_name, -- nhãn hướng của trip cho ride edge; transfer edge để NULL.
    seg.headsign,   -- nhãn đích đến của trip cho ride edge; transfer edge để NULL.

    seg.from_station_id,    -- mã ga đầu của cạnh.
    seg.from_station_name,  -- tên ga đầu của cạnh.
    seg.from_stop_sequence, -- stop_sequence của ga đầu trên trip đối với ride edge; transfer edge để NULL.
    seg.departure_at,       -- thời điểm rời ga đầu đối với ride edge; transfer edge không có giờ cố định nên để NULL.

    seg.to_station_id,      -- mã ga cuối của cạnh.
    seg.to_station_name,    -- tên ga cuối của cạnh.
    seg.to_stop_sequence,   -- stop_sequence của ga cuối trên trip đối với ride edge; transfer edge để NULL.
    seg.arrival_at,         -- thời điểm đến ga cuối đối với ride edge; transfer edge để NULL.

    -- travel_seconds: thời gian đi của cạnh tính bằng giây.
    -- Với ride edge lấy từ segment; với transfer edge tính từ transfers.transfer_time_min * 60.
    seg.travel_seconds,

    seg.from_timetable_id,
    seg.to_timetable_id
FROM v_active_trip_segments seg

UNION ALL

SELECT
    d.service_date, -- transfer edge được nở cho mọi service_date đang active để graph theo ngày luôn đầy đủ.
    'transfer'::TEXT AS edge_type,  -- đánh dấu đây là cạnh trung chuyển.

    NULL::TEXT AS trip_id,  -- transfer không gắn với trip cụ thể nên để NULL.
    NULL::TEXT AS line_id,  -- transfer không gắn với tuyến cụ thể nên để NULL.
    NULL::SMALLINT AS direction_id, -- transfer không có hướng chuẩn của trip nên để NULL.
    NULL::TEXT AS direction_name,   -- transfer không có nhãn hướng trip nên để NULL.
    NULL::TEXT AS headsign, -- transfer không có headsign nên để NULL.

    trf.from_station_id,    -- ga bắt đầu trung chuyển, lấy từ transfers.from_station_id.
    
    -- tên ga bắt đầu trung chuyển, join từ stations.station_name.
    s1.station_name AS from_station_name,

    -- transfer không thuộc một stop_sequence của trip nên để NULL.
    NULL::INTEGER AS from_stop_sequence,

    -- transfer không có giờ rời cố định trong lịch nên để NULL.
    NULL::timestamptz AS departure_at,

    trf.to_station_id,  -- ga kết thúc trung chuyển, lấy từ transfers.to_station_id.

    -- tên ga kết thúc trung chuyển, join từ stations.station_name.
    s2.station_name AS to_station_name,

    -- transfer không thuộc stop_sequence của trip nên để NULL.
    NULL::INTEGER AS to_stop_sequence,

    -- thời gian trung chuyển tính bằng giây, suy ra từ transfers.transfer_time_min.
    NULL::timestamptz AS arrival_at,

    trf.transfer_time_min * 60 AS travel_seconds,

    NULL::BIGINT AS from_timetable_id,
    NULL::BIGINT AS to_timetable_id
FROM (
    SELECT DISTINCT service_date
    FROM v_service_dates_active
) d
JOIN transfers trf
  ON trf.is_active = TRUE
JOIN stations s1
  ON s1.station_id = trf.from_station_id
JOIN stations s2
  ON s2.station_id = trf.to_station_id;

-- ==================================================================================================
-- 6) v_latest_predicted_stop_times
--
-- Mục đích:
-- - View read-only cho BE khi cần realtime theo stop của trip.
-- - Mỗi stop chỉ giữ bản dự đoán mới nhất theo:
--   service_date + timetable_id + scenario_id
--
-- Vì sao cần:
-- - predicted_stop_times là bảng time-series, có thể có nhiều snapshot
-- - BE thường chỉ cần bản mới nhất
--
-- Ghi chú:
-- - DISTINCT ON là cách ngắn gọn và rất tiện trong PostgreSQL cho bài toán "bản ghi mới nhất"
-- ==================================================================================================
CREATE OR REPLACE VIEW v_latest_predicted_stop_times AS
SELECT DISTINCT ON (
    pst.service_date,
    pst.timetable_id,
    COALESCE(pst.scenario_id, '__baseline__')
)
    pst.service_date,   -- ngày service thực tế của stop dự đoán, lấy từ predicted_stop_times.service_date.

    -- scenario_id: mã kịch bản giả lập áp cho snapshot dự đoán này.
    -- NULL được hiểu là baseline/không áp scenario.
    pst.scenario_id,

    -- updated_at: thời điểm snapshot dự đoán được ghi nhận.
    -- View giữ bản mới nhất theo (service_date, timetable_id, scenario_id).
    pst.updated_at,

    -- mã bản ghi snapshot trong predicted_stop_times.
    pst.predicted_stop_time_id,

    pst.timetable_id,   -- dòng timetable gốc mà dự đoán bám vào.
    pst.trip_id,    -- mã chuyến của stop được dự đoán.
    pst.line_id,    -- mã tuyến của trip/stop được dự đoán.
    l.line_name,    -- tên tuyến join từ lines.line_name.
    l.line_code,    -- mã ngắn tuyến join từ lines.line_code.
    pst.station_id, -- mã ga của stop được dự đoán.
    s.station_name, -- tên ga của stop được dự đoán, join từ stations.station_name.
    
    -- line_station_order: vị trí ga trên tuyến, lấy từ predicted_stop_times.line_station_order.
    -- Giá trị này bám theo timetable gốc của stop.
    pst.line_station_order,

    pst.stop_sequence,  -- thứ tự stop trong trip, lấy từ predicted_stop_times.stop_sequence.

    pst.scheduled_arrival_time,         -- giờ đến theo lịch gốc trong ngày service.
    pst.scheduled_arrival_day_offset,   -- độ lệch ngày của giờ đến theo lịch gốc.
    pst.scheduled_departure_time,       -- giờ rời theo lịch gốc trong ngày service.
    pst.scheduled_departure_day_offset, -- độ lệch ngày của giờ rời theo lịch gốc.

    pst.predicted_arrival_time,         -- giờ đến dự đoán trong ngày service.
    pst.predicted_arrival_day_offset,   -- độ lệch ngày của giờ đến dự đoán.
    pst.predicted_departure_time,       -- giờ rời dự đoán trong ngày service.
    pst.predicted_departure_day_offset, -- độ lệch ngày của giờ rời dự đoán.
    pst.predicted_arrival_at,   -- thời điểm đến dự đoán tuyệt đối ở dạng timestamptz.
    pst.predicted_departure_at, -- thời điểm rời dự đoán tuyệt đối ở dạng timestamptz.

    pst.delay_min,  -- độ trễ phút của stop dự đoán, lấy từ predicted_stop_times.delay_min.
    pst.status,     -- trạng thái dự đoán của stop, ví dụ on_time / delayed / skipped / cancelled.
    pst.prediction_source   -- nguồn sinh ra dự đoán, ví dụ simulation / realtime / manual_adjustment.
FROM predicted_stop_times pst
JOIN lines l
  ON l.line_id = pst.line_id
JOIN stations s
  ON s.station_id = pst.station_id
ORDER BY
    pst.service_date,
    pst.timetable_id,
    COALESCE(pst.scenario_id, '__baseline__'),
    pst.updated_at DESC,
    pst.predicted_stop_time_id DESC;

-- ==================================================================================================
-- 7) v_station_departure_board
--
-- Mục đích:
-- - Đây là view rất hữu ích cho BE.
-- - Hiển thị "board" các chuyến sắp rời ga:
--   ưu tiên realtime mới nhất từ next_departures,
--   nếu không có thì vẫn có thể đọc planned từ v_active_trip_stop_times bằng query khác.
--
-- Ở view này:
-- - mỗi dòng là snapshot mới nhất của một chuyến tại một ga trong một ngày
-- - cực phù hợp để làm API departure board
-- ==================================================================================================
DROP VIEW IF EXISTS v_station_departure_board;

CREATE OR REPLACE VIEW v_station_departure_board AS
SELECT DISTINCT ON (
    nd.service_date,    
    nd.station_id,
    nd.trip_id
)
    nd.service_date,    -- ngày service thực tế của chuyến sắp rời, lấy từ next_departures.service_date.

    -- updated_at: thời điểm snapshot departure board được ghi nhận.
    -- View giữ bản mới nhất theo (service_date, station_id, trip_id).
    nd.updated_at,

    nd.next_departure_id,   -- mã bản ghi snapshot trong next_departures.
    nd.timetable_id,    -- dòng timetable gốc mà snapshot này bám vào.
    nd.station_id,      -- mã ga nơi board đang hiển thị chuyến sắp rời.
    s.station_name,     -- tên ga tương ứng, join từ stations.station_name.

    nd.line_id, -- mã tuyến của chuyến sắp rời.
    l.line_name,-- tên tuyến, join từ lines.line_name.
    l.line_code,-- mã ngắn của tuyến, join từ lines.line_code.

    nd.trip_id,             -- mã chuyến sắp rời.
    nd.direction_id,        -- hướng chuẩn mức số của chuyến, nên khớp với trips.direction_id.
    nd.direction_label,     -- nhãn hướng hiển thị nhanh cho BE/FE, lấy từ next_departures.direction_label.
    nd.line_station_order,  -- vị trí ga trên tuyến của stop này, lấy từ next_departures.line_station_order.
    nd.stop_sequence,       -- thứ tự stop của ga này trong trip.
    nd.headsign,            -- nhãn đích đến để hiển thị trên departure board.

    nd.predicted_departure_time,        -- giờ rời dự đoán trong ngày service.
    nd.predicted_departure_day_offset,  -- độ lệch ngày của giờ rời dự đoán.
    nd.predicted_departure_at,          -- thời điểm rời dự đoán tuyệt đối ở dạng timestamptz.
    nd.delay_min,   -- số phút trễ của chuyến sắp rời.
    nd.status       -- trạng thái dự đoán của chuyến sắp rời, ví dụ on_time / delayed / skipped / cancelled.
FROM next_departures nd
JOIN stations s
  ON s.station_id = nd.station_id
JOIN lines l
  ON l.line_id = nd.line_id
ORDER BY
    nd.service_date,
    nd.station_id,
    nd.trip_id,
    nd.updated_at DESC,
    nd.next_departure_id DESC;
