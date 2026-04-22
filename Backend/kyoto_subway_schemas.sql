BEGIN;

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS timescaledb;
CREATE EXTENSION IF NOT EXISTS btree_gist; -- Hỗ trợ exclusion constraint nếu sau này cần siết chặt hơn các khoảng thời gian

-- ==================================================================================================
-- 1) Danh mục tuyến
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS lines (
    line_id TEXT PRIMARY KEY, -- Mã tuyến duy nhất, ví dụ karasuma, tozai
    line_code TEXT, -- Mã ngắn của tuyến, ví dụ K, T
    line_name TEXT NOT NULL, -- Tên tuyến bằng tiếng Anh
    operator_name TEXT NOT NULL, -- Tên đơn vị vận hành
    color_hex TEXT, -- Màu hiển thị của tuyến theo dạng #RRGGBB
    is_active BOOLEAN NOT NULL DEFAULT TRUE, -- Tuyến còn hoạt động hay không
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm cập nhật bản ghi gần nhất
    CONSTRAINT lines_code_unique UNIQUE (line_code), -- Nếu có khai báo mã ngắn thì mỗi tuyến phải có mã riêng
    CONSTRAINT lines_color_hex_chk CHECK (color_hex IS NULL OR color_hex ~ '^#[0-9A-Fa-f]{6}$'), -- Chỉ chấp nhận mã màu hợp lệ
    CONSTRAINT lines_name_not_blank_chk CHECK (btrim(line_name) <> ''), -- Tên tuyến không được rỗng sau khi trim
    CONSTRAINT lines_operator_name_not_blank_chk CHECK (btrim(operator_name) <> '') -- Tên đơn vị vận hành không được rỗng sau khi trim
);

-- ==================================================================================================
-- 2) Danh mục ga
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS stations (
    station_id TEXT PRIMARY KEY, -- Mã ga duy nhất trong hệ thống
    station_name TEXT NOT NULL, -- Tên ga bằng tiếng Anh
    geom geometry(Point, 4326), -- Tọa độ ga theo PostGIS, hệ WGS84
    is_transfer_station BOOLEAN NOT NULL DEFAULT FALSE, -- Ga có phải ga trung chuyển hay không
    is_active BOOLEAN NOT NULL DEFAULT TRUE, -- Ga còn hoạt động hay không
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm cập nhật bản ghi gần nhất
    CONSTRAINT stations_name_not_blank_chk CHECK (btrim(station_name) <> '') -- Tên ga không được rỗng sau khi trim
);

-- ==================================================================================================
-- 3) Quan hệ ga - tuyến
--
-- Bảng này là xương sống để hiểu một ga thuộc những tuyến nào và đứng ở vị trí nào trên tuyến đó.
-- Mỗi dòng = một ga nằm trên một tuyến.
--
-- Ví dụ:
-- - ga karasuma_oike có thể có 2 dòng:
--   + (karasuma_oike, karasuma, station_order = ...)
--   + (karasuma_oike, tozai, station_order = ...)
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS station_lines (
    station_line_id BIGSERIAL PRIMARY KEY, -- Khóa chính tự tăng cho quan hệ ga - tuyến
    station_id TEXT NOT NULL REFERENCES stations(station_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Mã ga
    line_id TEXT NOT NULL REFERENCES lines(line_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Mã tuyến
    station_order INTEGER NOT NULL, -- Thứ tự ga trên tuyến, bắt đầu từ 1
    is_terminal BOOLEAN NOT NULL DEFAULT FALSE, -- Có phải ga đầu hoặc ga cuối tuyến hay không
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm cập nhật bản ghi gần nhất
    CONSTRAINT station_lines_unique UNIQUE (station_id, line_id), -- Không cho trùng một ga trên cùng một tuyến
    CONSTRAINT station_lines_line_order_unique UNIQUE (line_id, station_order), -- Trên một tuyến, mỗi vị trí chỉ thuộc về đúng một ga
    CONSTRAINT station_lines_line_order_station_unique UNIQUE (line_id, station_order, station_id), -- Khóa ba cột này được thêm để các bảng khác có thể khóa chặt một ga đúng tại đúng vị trí trên tuyến
    CONSTRAINT station_lines_order_positive_chk CHECK (station_order > 0) -- Thứ tự ga phải lớn hơn 0
);

-- ==================================================================================================
-- 4) Cạnh cơ sở của đồ thị subway
--
-- Mỗi dòng biểu diễn một cạnh có hướng trên một tuyến.
-- Nếu đoạn A <-> B chạy 2 chiều, nên lưu 2 dòng:
-- - A -> B
-- - B -> A
--
-- Bảng này phục vụ tốt cho team thuật toán vì có thể dùng trực tiếp làm graph base.
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS edges (
    edge_id BIGSERIAL PRIMARY KEY, -- Khóa chính tự tăng cho cạnh
    line_id TEXT NOT NULL REFERENCES lines(line_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Mã tuyến của cạnh
    from_station_id TEXT NOT NULL, -- Ga bắt đầu của cạnh
    from_station_order INTEGER NOT NULL, -- Thứ tự ga bắt đầu trên tuyến; lưu rõ để đảm bảo cạnh nằm đúng trên tuyến
    to_station_id TEXT NOT NULL, -- Ga kết thúc của cạnh
    to_station_order INTEGER NOT NULL, -- Thứ tự ga kết thúc trên tuyến; lưu rõ để đảm bảo cạnh nối đúng 2 ga kề nhau
    travel_time_min INTEGER NOT NULL, -- Thời gian đi cơ sở tính bằng phút
    distance_km NUMERIC(8,3), -- Khoảng cách cơ sở tính bằng km
    geom geometry(LineString, 4326), -- Hình học đoạn tuyến theo PostGIS
    is_active BOOLEAN NOT NULL DEFAULT TRUE, -- Cạnh còn hoạt động hay không
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm cập nhật bản ghi gần nhất
    CONSTRAINT edges_from_station_position_fk FOREIGN KEY (line_id, from_station_order, from_station_id) REFERENCES station_lines(line_id, station_order, station_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Khóa chặt ga bắt đầu phải đúng chính ga đang đứng ở đúng vị trí đó trên tuyến, tránh mâu thuẫn station_id và station_order
    CONSTRAINT edges_to_station_position_fk FOREIGN KEY (line_id, to_station_order, to_station_id) REFERENCES station_lines(line_id, station_order, station_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Khóa chặt ga kết thúc phải đúng chính ga đang đứng ở đúng vị trí đó trên tuyến
    CONSTRAINT edges_distinct_stations_chk CHECK (from_station_id <> to_station_id), -- Ga đầu và ga cuối phải khác nhau
    CONSTRAINT edges_distinct_orders_chk CHECK (from_station_order <> to_station_order), -- Thứ tự ga đầu và ga cuối phải khác nhau
    CONSTRAINT edges_adjacent_orders_chk CHECK (ABS(to_station_order - from_station_order) = 1), -- Trong mô hình đơn giản này, một edge chỉ nối 2 ga kề nhau trên cùng tuyến
    CONSTRAINT edges_travel_time_positive_chk CHECK (travel_time_min > 0), -- Thời gian đi phải lớn hơn 0
    CONSTRAINT edges_distance_nonnegative_chk CHECK (distance_km IS NULL OR distance_km >= 0), -- Khoảng cách không được âm
    CONSTRAINT edges_unique UNIQUE (line_id, from_station_id, to_station_id), -- Không cho trùng cạnh trên cùng tuyến
    CONSTRAINT edges_unique_orders UNIQUE (line_id, from_station_order, to_station_order) -- Không cho trùng cạnh nếu nhìn theo thứ tự ga trên tuyến
);

-- ==================================================================================================
-- 5) Quan hệ trung chuyển giữa các ga
--
-- Mỗi dòng là một quan hệ trung chuyển có hướng.
-- Nếu muốn cho phép đi bộ hai chiều giữa 2 ga, nên lưu 2 dòng:
-- - ga A -> ga B
-- - ga B -> ga A
--
-- Cách lưu có hướng giúp biểu diễn các trường hợp thời gian chuyển 2 chiều khác nhau.
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS transfers (
    transfer_id BIGSERIAL PRIMARY KEY, -- Khóa chính tự tăng cho quan hệ trung chuyển
    from_station_id TEXT NOT NULL REFERENCES stations(station_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Ga bắt đầu trung chuyển
    to_station_id TEXT NOT NULL REFERENCES stations(station_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Ga kết thúc trung chuyển
    transfer_time_min INTEGER NOT NULL, -- Thời gian trung chuyển tính bằng phút
    is_active BOOLEAN NOT NULL DEFAULT TRUE, -- Trung chuyển còn dùng được hay không
    transfer_type TEXT NOT NULL DEFAULT 'same_station_interchange', -- Loại trung chuyển
    note TEXT, -- Ghi chú nghiệp vụ
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm cập nhật bản ghi gần nhất
    CONSTRAINT transfers_distinct_stations_chk CHECK (from_station_id <> to_station_id), -- Không cho trung chuyển tới chính mình
    CONSTRAINT transfers_time_positive_chk CHECK (transfer_time_min > 0), -- Thời gian trung chuyển phải lớn hơn 0
    CONSTRAINT transfers_type_chk CHECK (transfer_type IN ('same_station_interchange', 'walk_transfer')), -- Chỉ chấp nhận các loại trung chuyển đã định nghĩa
    CONSTRAINT transfers_unique UNIQUE (from_station_id, to_station_id) -- Không cho trùng quan hệ trung chuyển
);

-- ==================================================================================================
-- 6) Lịch cơ sở theo thứ trong tuần
--
-- Đây là lịch cơ sở, chưa phải kết quả cuối cùng cho từng ngày.
-- Kết quả cuối cùng của một ngày cụ thể phải xét thêm service_exceptions.
--
-- Ví dụ:
-- - weekday_service: monday..friday = TRUE
-- - saturday_service: saturday = TRUE
-- - sunday_service: sunday = TRUE
-- - holiday_service: không bắt buộc phải gắn với thứ nào; thường dùng qua service_exceptions
--
-- Bản v5 gộp sunday_holiday làm một loại. Bản v7 tách rõ hơn để holiday rơi vào weekday xử lý minh bạch.
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS service_calendar (
    service_id TEXT PRIMARY KEY, -- Mã nhóm lịch chạy
    service_name TEXT NOT NULL, -- Tên dễ đọc của nhóm lịch chạy
    service_type TEXT NOT NULL, -- Loại lịch chạy để nghiệp vụ dễ hiểu hơn
    monday BOOLEAN NOT NULL DEFAULT FALSE, -- Có chạy thứ Hai hay không
    tuesday BOOLEAN NOT NULL DEFAULT FALSE, -- Có chạy thứ Ba hay không
    wednesday BOOLEAN NOT NULL DEFAULT FALSE, -- Có chạy thứ Tư hay không
    thursday BOOLEAN NOT NULL DEFAULT FALSE, -- Có chạy thứ Năm hay không
    friday BOOLEAN NOT NULL DEFAULT FALSE, -- Có chạy thứ Sáu hay không
    saturday BOOLEAN NOT NULL DEFAULT FALSE, -- Có chạy thứ Bảy hay không
    sunday BOOLEAN NOT NULL DEFAULT FALSE, -- Có chạy Chủ nhật hay không
    start_date DATE NOT NULL, -- Ngày bắt đầu hiệu lực của lịch cơ sở
    end_date DATE NOT NULL, -- Ngày kết thúc hiệu lực của lịch cơ sở
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm cập nhật bản ghi gần nhất
    CONSTRAINT service_calendar_type_chk CHECK (service_type IN ('weekday', 'saturday', 'sunday', 'holiday', 'special')), -- Chỉ chấp nhận các loại lịch chạy đã định nghĩa
    CONSTRAINT service_calendar_name_not_blank_chk CHECK (btrim(service_name) <> ''), -- Tên service không được rỗng sau khi trim
    CONSTRAINT service_calendar_date_range_chk CHECK (start_date <= end_date), -- Ngày bắt đầu không được lớn hơn ngày kết thúc
    CONSTRAINT service_calendar_days_present_chk CHECK ( -- Với service không phải holiday/special thì phải bật ít nhất một thứ trong tuần
        service_type IN ('holiday', 'special')
        OR monday OR tuesday OR wednesday OR thursday OR friday OR saturday OR sunday
    )
);

-- ==================================================================================================
-- 7) Danh sách ngày lễ thực tế
--
-- Bảng này chỉ trả lời câu hỏi: ngày nào là ngày lễ.
-- Bảng này không tự động bật hoặc tắt trip.
-- Việc ngày lễ đó dùng service nào sẽ được quyết định ở service_exceptions.
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS holiday_dates (
    holiday_date DATE PRIMARY KEY, -- Ngày lễ thực tế
    holiday_name TEXT NOT NULL, -- Tên ngày lễ để dễ kiểm tra nghiệp vụ
    is_public_holiday BOOLEAN NOT NULL DEFAULT TRUE, -- Có phải ngày nghỉ lễ công cộng hay không
    note TEXT, -- Ghi chú thêm
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm cập nhật bản ghi gần nhất
    CONSTRAINT holiday_dates_name_not_blank_chk CHECK (btrim(holiday_name) <> '') -- Tên ngày lễ không được rỗng sau khi trim
);

-- ==================================================================================================
-- 8) Ngoại lệ lịch chạy theo ngày cụ thể
--
-- Đây là bảng rất quan trọng để xử lý các case mà lịch cơ sở theo thứ trong tuần không đủ.
-- Mỗi dòng áp cho đúng một service_id tại đúng một ngày cụ thể.
--
-- exception_type = 'added'
-- - Bật service này cho ngày đó, kể cả khi lịch cơ sở theo thứ không bật.
--
-- exception_type = 'removed'
-- - Tắt service này cho ngày đó, kể cả khi lịch cơ sở theo thứ đang bật.
--
-- Cách dùng chuẩn cho holiday rơi vào weekday:
-- - service weekday: removed
-- - service holiday: added
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS service_exceptions (
    service_exception_id BIGSERIAL PRIMARY KEY, -- Khóa chính tự tăng cho ngoại lệ lịch chạy
    service_id TEXT NOT NULL REFERENCES service_calendar(service_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Mã nhóm lịch chạy bị thêm hoặc bị gỡ trong ngày cụ thể
    service_date DATE NOT NULL, -- Ngày áp ngoại lệ
    exception_type TEXT NOT NULL, -- Loại ngoại lệ: added hoặc removed
    exception_category TEXT NOT NULL DEFAULT 'special_operation', -- Phân loại ngoại lệ để nghiệp vụ dễ đọc hơn
    reason TEXT, -- Lý do nghiệp vụ ngắn gọn, ví dụ public_holiday, festival_day, severe_weather
    note TEXT, -- Ghi chú thêm để team dữ liệu dễ kiểm tra
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm cập nhật bản ghi gần nhất
    CONSTRAINT service_exceptions_type_chk CHECK (exception_type IN ('added', 'removed')), -- Chỉ chấp nhận 2 loại ngoại lệ chuẩn
    CONSTRAINT service_exceptions_category_chk CHECK (exception_category IN ('holiday', 'special_operation', 'maintenance', 'event', 'emergency')), -- Giữ reason tự do nhưng vẫn chuẩn hóa được nhóm ngoại lệ chính
    CONSTRAINT service_exceptions_reason_not_blank_chk CHECK (reason IS NULL OR btrim(reason) <> ''), -- Nếu có nhập lý do thì không được là chuỗi rỗng
    CONSTRAINT service_exceptions_unique UNIQUE (service_id, service_date) -- Mỗi service chỉ có tối đa một ngoại lệ trên một ngày
);

-- ==================================================================================================
-- 9) Chuyến tàu
--
-- Một trip thuộc đúng một tuyến và đúng một service_id.
-- Trip dùng service_id để biết trip này chạy trong các ngày nào.
--
-- Ví dụ:
-- - trip K_001 thuộc line karasuma
-- - trip K_001 dùng service_id = weekday_main
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS trips (
    trip_id TEXT PRIMARY KEY, -- Mã chuyến tàu duy nhất
    line_id TEXT NOT NULL REFERENCES lines(line_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Tuyến của chuyến tàu
    service_id TEXT NOT NULL REFERENCES service_calendar(service_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Nhóm lịch chạy áp dụng cho chuyến tàu
    direction_id SMALLINT NOT NULL, -- Hướng chạy; quy ước nghiệp vụ nên được giữ cố định toàn hệ thống, ví dụ 0 = theo chiều station_order tăng, 1 = theo chiều station_order giảm
    direction_name TEXT, -- Nhãn dễ đọc cho hướng chạy, ví dụ inbound / outbound, northbound / southbound
    origin_station_id TEXT REFERENCES stations(station_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Ga đầu chuyến ở mức nghiệp vụ; giúp BE và team thuật toán đọc trip dễ hơn
    destination_station_id TEXT REFERENCES stations(station_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Ga cuối chuyến ở mức nghiệp vụ; giúp hiển thị hành trình rõ hơn
    headsign TEXT NOT NULL, -- Nhãn đích đến hoặc hướng đi
    is_active BOOLEAN NOT NULL DEFAULT TRUE, -- Chuyến còn hoạt động hay không
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm cập nhật bản ghi gần nhất
    CONSTRAINT trips_direction_chk CHECK (direction_id IN (0, 1)), -- Chỉ chấp nhận 2 hướng chuẩn
    CONSTRAINT trips_headsign_not_blank_chk CHECK (btrim(headsign) <> ''), -- Headsign không được rỗng sau khi trim
    CONSTRAINT trips_direction_name_not_blank_chk CHECK (direction_name IS NULL OR btrim(direction_name) <> ''), -- Nếu có nhãn hướng thì không được là chuỗi rỗng
    CONSTRAINT trips_terminal_distinct_chk CHECK (origin_station_id IS NULL OR destination_station_id IS NULL OR origin_station_id <> destination_station_id), -- Nếu có khai báo ga đầu và ga cuối thì chúng phải khác nhau
    CONSTRAINT trips_origin_station_line_fk FOREIGN KEY (origin_station_id, line_id) REFERENCES station_lines(station_id, line_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Nếu có khai báo ga đầu thì ga đó phải thật sự nằm trên tuyến của trip
    CONSTRAINT trips_destination_station_line_fk FOREIGN KEY (destination_station_id, line_id) REFERENCES station_lines(station_id, line_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Nếu có khai báo ga cuối thì ga đó phải thật sự nằm trên tuyến của trip
    CONSTRAINT trips_trip_line_unique UNIQUE (trip_id, line_id) -- Phục vụ cho các khóa ngoại phức hợp từ timetable và bảng realtime
);

-- ==================================================================================================
-- 10) Giờ biểu theo từng điểm dừng của chuyến
--
-- Bảng này đã được làm rõ hơn v5 bằng cách lưu cả line_id.
-- Lý do thêm line_id:
-- - Để khóa ngoại có thể kiểm tra trip này thật sự thuộc tuyến nào.
-- - Để khóa ngoại có thể kiểm tra station này thật sự nằm trên tuyến nào.
-- - Nhìn dữ liệu cũng dễ hiểu hơn khi debug.
--
-- arrival_day_offset / departure_day_offset giúp xử lý chuyến qua nửa đêm nhưng vẫn giữ TIME giống v5.
-- Ví dụ:
-- - 23:58 cùng ngày service => day_offset = 0, time = 23:58
-- - 00:03 sáng hôm sau => day_offset = 1, time = 00:03
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS timetable (
    timetable_id BIGSERIAL PRIMARY KEY, -- Khóa chính tự tăng cho dòng giờ biểu
    trip_id TEXT NOT NULL, -- Mã chuyến tàu
    line_id TEXT NOT NULL, -- Tuyến của chuyến tàu, được lưu lại để ràng buộc dữ liệu chặt hơn
    station_id TEXT NOT NULL, -- Mã ga của điểm dừng
    line_station_order INTEGER NOT NULL, -- Thứ tự ga của điểm dừng này trên tuyến; lưu thêm để downstream và ETL dễ kiểm tra trip có đi đúng theo tuyến hay không
    stop_sequence INTEGER NOT NULL, -- Thứ tự điểm dừng trong chuyến
    scheduled_arrival_time TIME NOT NULL, -- Giờ đến theo lịch trong ngày service
    scheduled_arrival_day_offset SMALLINT NOT NULL DEFAULT 0, -- Độ lệch ngày của giờ đến so với ngày service, thường là 0 hoặc 1
    scheduled_departure_time TIME NOT NULL, -- Giờ rời theo lịch trong ngày service
    scheduled_departure_day_offset SMALLINT NOT NULL DEFAULT 0, -- Độ lệch ngày của giờ rời so với ngày service, thường là 0 hoặc 1
    pickup_allowed BOOLEAN NOT NULL DEFAULT TRUE, -- Có cho phép lên tàu tại ga này hay không
    dropoff_allowed BOOLEAN NOT NULL DEFAULT TRUE, -- Có cho phép xuống tàu tại ga này hay không
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm cập nhật bản ghi gần nhất
    CONSTRAINT timetable_trip_fk FOREIGN KEY (trip_id, line_id) REFERENCES trips(trip_id, line_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Đảm bảo trip_id và line_id thật sự đi cùng nhau
    CONSTRAINT timetable_station_position_fk FOREIGN KEY (line_id, line_station_order, station_id) REFERENCES station_lines(line_id, station_order, station_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Khóa chặt ga của stop phải đúng chính ga đang đứng ở đúng vị trí đó trên tuyến, tránh mâu thuẫn station_id và line_station_order
    CONSTRAINT timetable_stop_sequence_positive_chk CHECK (stop_sequence > 0), -- Thứ tự điểm dừng phải lớn hơn 0
    CONSTRAINT timetable_line_station_order_positive_chk CHECK (line_station_order > 0), -- Thứ tự ga trên tuyến phải lớn hơn 0
    CONSTRAINT timetable_arrival_day_offset_chk CHECK (scheduled_arrival_day_offset >= 0), -- Độ lệch ngày không được âm
    CONSTRAINT timetable_departure_day_offset_chk CHECK (scheduled_departure_day_offset >= 0), -- Độ lệch ngày không được âm
    CONSTRAINT timetable_time_order_chk CHECK (
        scheduled_departure_day_offset > scheduled_arrival_day_offset
        OR (
            scheduled_departure_day_offset = scheduled_arrival_day_offset
            AND scheduled_departure_time >= scheduled_arrival_time
        )
    ), -- Giờ rời không được sớm hơn giờ đến nếu xét cả độ lệch ngày
    CONSTRAINT timetable_trip_sequence_unique UNIQUE (trip_id, stop_sequence), -- Mỗi chuyến không được có 2 dòng cùng stop_sequence
    CONSTRAINT timetable_trip_station_unique UNIQUE (trip_id, station_id), -- Mỗi chuyến chỉ có tối đa 1 dòng cho mỗi ga trong mô hình đơn giản này
    CONSTRAINT timetable_trip_line_sequence_unique UNIQUE (trip_id, line_id, stop_sequence), -- Phục vụ khóa ngoại rõ ràng cho bảng dự đoán và snapshot
    CONSTRAINT timetable_trip_line_station_unique UNIQUE (trip_id, line_id, station_id), -- Phục vụ khóa ngoại rõ ràng cho bảng dự đoán và snapshot
    CONSTRAINT timetable_trip_line_station_order_unique UNIQUE (trip_id, line_id, line_station_order), -- Mỗi chuyến chỉ đi qua tối đa một vị trí ga trên tuyến trong mô hình đơn giản này
    CONSTRAINT timetable_row_identity_unique UNIQUE (timetable_id, trip_id, line_id, station_id, line_station_order, stop_sequence) -- Khóa nhận diện đầy đủ một stop của trip; dùng để các bảng realtime bám vào đúng một dòng timetable gốc duy nhất
);

-- ==================================================================================================
-- 11) Tình huống giả lập
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS scenarios (
    scenario_id TEXT PRIMARY KEY, -- Mã tình huống giả lập
    scenario_name TEXT NOT NULL UNIQUE, -- Tên duy nhất của tình huống
    scenario_type TEXT NOT NULL, -- Loại tình huống
    description TEXT, -- Mô tả chi tiết
    is_active BOOLEAN NOT NULL DEFAULT FALSE, -- Tình huống có đang bật hay không
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm cập nhật bản ghi gần nhất
    CONSTRAINT scenarios_type_chk CHECK (scenario_type IN ('delay', 'maintenance', 'closure', 'mixed')), -- Chỉ chấp nhận các loại tình huống đã quy định
    CONSTRAINT scenarios_name_not_blank_chk CHECK (btrim(scenario_name) <> '') -- Tên tình huống không được rỗng sau khi trim
);

-- ==================================================================================================
-- 12) Các bảng status_events đã được mở rộng để trở thành nơi lưu mọi sự kiện vận hành quan trọng
--
-- Từ v7.5 trở đi, schema không còn tách riêng delay_events và *_maintenance_windows.
-- Thay vào đó, mọi trạng thái như delayed, maintenance, closed, suspended... đều đi vào *_status_events.
--
-- Ý nghĩa các cột mới được chuẩn hóa như sau:
-- - recorded_at: thời điểm hệ thống ghi nhận event này
-- - effective_from / effective_to: khoảng thời gian trạng thái này có hiệu lực nghiệp vụ
-- - event_category: nhóm sự kiện để downstream hiểu đây là delay, maintenance hay incident khác
-- - impact_level: mức độ ảnh hưởng
-- - delay_min: số phút trễ, chỉ bắt buộc khi status = delayed hoặc event_category = delay
-- - reason_code / reason_text: lý do chuẩn hóa và mô tả tự do
-- - source_type / source_ref: vết nguồn sinh ra event, giúp ETL và audit dễ truy vết
--
-- Nhờ cách này, dữ liệu gọn hơn và không còn rủi ro cùng một sự kiện bị ghi lệch ở nhiều bảng khác nhau.
-- ==================================================================================================

-- ==================================================================================================
-- 13) Sự kiện trạng thái tuyến
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS line_status_events (
    line_status_event_id BIGSERIAL NOT NULL, -- Mã sự kiện trạng thái tuyến
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm hệ thống ghi nhận event này; đây cũng là cột thời gian cho hypertable
    line_id TEXT NOT NULL REFERENCES lines(line_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Tuyến bị áp trạng thái
    status TEXT NOT NULL, -- Trạng thái chuẩn hóa của tuyến
    event_category TEXT NOT NULL DEFAULT 'incident', -- Nhóm sự kiện: delay, maintenance, incident, recovery...
    impact_level TEXT NOT NULL DEFAULT 'minor', -- Mức độ ảnh hưởng để BE/FE dễ hiển thị mức nghiêm trọng
    effective_from TIMESTAMPTZ NOT NULL, -- Thời điểm bắt đầu có hiệu lực nghiệp vụ
    effective_to TIMESTAMPTZ, -- Thời điểm kết thúc hiệu lực; NULL nếu chưa biết hoặc còn đang mở
    delay_min INTEGER, -- Số phút trễ; chỉ dùng khi đây là status/event liên quan delay
    reason_code TEXT, -- Mã lý do ngắn gọn, ví dụ signal_issue, scheduled_maintenance
    reason_text TEXT, -- Mô tả tự do dễ đọc hơn cho người vận hành
    source_type TEXT NOT NULL DEFAULT 'manual', -- Nguồn tạo event: manual, ops_feed, etl_rule, scenario
    source_ref TEXT, -- Khóa tham chiếu bên ngoài hoặc id nguồn nếu có
    scenario_id TEXT REFERENCES scenarios(scenario_id) ON UPDATE CASCADE ON DELETE SET NULL, -- Tình huống giả lập gắn với trạng thái
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi

    CONSTRAINT line_status_events_pk PRIMARY KEY (line_status_event_id, recorded_at), -- Khóa chính gồm mã sự kiện và thời gian ghi nhận
    CONSTRAINT line_status_events_status_chk CHECK (status IN ('normal', 'delayed', 'closed', 'maintenance', 'suspended', 'partial_suspend', 'disrupted', 'recovered')), -- Tập trạng thái chuẩn hóa ở cấp tuyến
    CONSTRAINT line_status_events_event_category_chk CHECK (event_category IN ('incident', 'delay', 'maintenance', 'service_change', 'recovery', 'manual_override')), -- Phân loại event để thống nhất cách dùng
    CONSTRAINT line_status_events_impact_level_chk CHECK (impact_level IN ('info', 'minor', 'moderate', 'major', 'severe')), -- Chuẩn hóa mức độ ảnh hưởng
    CONSTRAINT line_status_events_source_type_chk CHECK (source_type IN ('manual', 'ops_feed', 'etl_rule', 'scenario', 'system')), -- Chuẩn hóa nguồn phát sinh event
    CONSTRAINT line_status_events_delay_nonnegative_chk CHECK (delay_min IS NULL OR delay_min >= 0), -- Nếu có số phút trễ thì không được âm
    CONSTRAINT line_status_events_delay_required_chk CHECK (NOT (status = 'delayed' OR event_category = 'delay') OR delay_min IS NOT NULL), -- Delay event phải có số phút trễ
    CONSTRAINT line_status_events_reason_code_not_blank_chk CHECK (reason_code IS NULL OR btrim(reason_code) <> ''), -- Nếu có mã lý do thì không được là chuỗi rỗng
    CONSTRAINT line_status_events_reason_text_not_blank_chk CHECK (reason_text IS NULL OR btrim(reason_text) <> ''), -- Nếu có mô tả lý do thì không được là chuỗi rỗng
    CONSTRAINT line_status_events_effective_range_chk CHECK (effective_to IS NULL OR effective_to >= effective_from) -- Khoảng hiệu lực phải hợp lệ
);

-- ==================================================================================================
-- 14) Sự kiện trạng thái ga
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS station_status_events (
    station_status_event_id BIGSERIAL NOT NULL, -- Mã sự kiện trạng thái ga
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm hệ thống ghi nhận event này; đây cũng là cột thời gian cho hypertable
    station_id TEXT NOT NULL REFERENCES stations(station_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Ga bị áp trạng thái
    status TEXT NOT NULL, -- Trạng thái chuẩn hóa của ga
    event_category TEXT NOT NULL DEFAULT 'incident', -- Nhóm sự kiện: delay, maintenance, incident, recovery...
    impact_level TEXT NOT NULL DEFAULT 'minor', -- Mức độ ảnh hưởng
    effective_from TIMESTAMPTZ NOT NULL, -- Thời điểm bắt đầu có hiệu lực nghiệp vụ
    effective_to TIMESTAMPTZ, -- Thời điểm kết thúc hiệu lực
    delay_min INTEGER, -- Số phút trễ nếu ga bị delayed
    reason_code TEXT, -- Mã lý do ngắn gọn
    reason_text TEXT, -- Mô tả lý do
    source_type TEXT NOT NULL DEFAULT 'manual', -- Nguồn tạo event
    source_ref TEXT, -- Khóa tham chiếu nguồn nếu có
    scenario_id TEXT REFERENCES scenarios(scenario_id) ON UPDATE CASCADE ON DELETE SET NULL, -- Tình huống giả lập gắn với trạng thái
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi

    CONSTRAINT station_status_events_pk PRIMARY KEY (station_status_event_id, recorded_at), -- Khóa chính gồm mã sự kiện và thời gian ghi nhận
    CONSTRAINT station_status_events_status_chk CHECK (status IN ('normal', 'delayed', 'closed', 'maintenance', 'suspended', 'partial_suspend', 'disrupted', 'recovered')), -- Tập trạng thái chuẩn hóa ở cấp ga
    CONSTRAINT station_status_events_event_category_chk CHECK (event_category IN ('incident', 'delay', 'maintenance', 'service_change', 'recovery', 'manual_override')), -- Phân loại event
    CONSTRAINT station_status_events_impact_level_chk CHECK (impact_level IN ('info', 'minor', 'moderate', 'major', 'severe')), -- Mức độ ảnh hưởng
    CONSTRAINT station_status_events_source_type_chk CHECK (source_type IN ('manual', 'ops_feed', 'etl_rule', 'scenario', 'system')), -- Chuẩn hóa nguồn tạo event
    CONSTRAINT station_status_events_delay_nonnegative_chk CHECK (delay_min IS NULL OR delay_min >= 0), -- Nếu có số phút trễ thì không được âm
    CONSTRAINT station_status_events_delay_required_chk CHECK (NOT (status = 'delayed' OR event_category = 'delay') OR delay_min IS NOT NULL), -- Delay event phải có số phút trễ
    CONSTRAINT station_status_events_reason_code_not_blank_chk CHECK (reason_code IS NULL OR btrim(reason_code) <> ''), -- Nếu có mã lý do thì không được là chuỗi rỗng
    CONSTRAINT station_status_events_reason_text_not_blank_chk CHECK (reason_text IS NULL OR btrim(reason_text) <> ''), -- Nếu có mô tả lý do thì không được là chuỗi rỗng
    CONSTRAINT station_status_events_effective_range_chk CHECK (effective_to IS NULL OR effective_to >= effective_from) -- Khoảng hiệu lực phải hợp lệ
);

-- ==================================================================================================
-- 15) Sự kiện trạng thái cạnh
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS edge_status_events (
    edge_status_event_id BIGSERIAL NOT NULL, -- Mã sự kiện trạng thái cạnh
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm hệ thống ghi nhận event này; đây cũng là cột thời gian cho hypertable
    edge_id BIGINT NOT NULL REFERENCES edges(edge_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Cạnh bị áp trạng thái
    status TEXT NOT NULL, -- Trạng thái chuẩn hóa của cạnh
    event_category TEXT NOT NULL DEFAULT 'incident', -- Nhóm sự kiện: delay, maintenance, incident, recovery...
    impact_level TEXT NOT NULL DEFAULT 'minor', -- Mức độ ảnh hưởng
    effective_from TIMESTAMPTZ NOT NULL, -- Thời điểm bắt đầu có hiệu lực nghiệp vụ
    effective_to TIMESTAMPTZ, -- Thời điểm kết thúc hiệu lực
    delay_min INTEGER, -- Số phút trễ nếu cạnh bị delayed
    reason_code TEXT, -- Mã lý do ngắn gọn
    reason_text TEXT, -- Mô tả lý do
    source_type TEXT NOT NULL DEFAULT 'manual', -- Nguồn tạo event
    source_ref TEXT, -- Khóa tham chiếu nguồn nếu có
    scenario_id TEXT REFERENCES scenarios(scenario_id) ON UPDATE CASCADE ON DELETE SET NULL, -- Tình huống giả lập gắn với trạng thái
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi

    CONSTRAINT edge_status_events_pk PRIMARY KEY (edge_status_event_id, recorded_at), -- Khóa chính gồm mã sự kiện và thời gian ghi nhận
    CONSTRAINT edge_status_events_status_chk CHECK (status IN ('normal', 'delayed', 'closed', 'maintenance', 'suspended', 'partial_suspend', 'disrupted', 'recovered')), -- Tập trạng thái chuẩn hóa ở cấp cạnh
    CONSTRAINT edge_status_events_event_category_chk CHECK (event_category IN ('incident', 'delay', 'maintenance', 'service_change', 'recovery', 'manual_override')), -- Phân loại event
    CONSTRAINT edge_status_events_impact_level_chk CHECK (impact_level IN ('info', 'minor', 'moderate', 'major', 'severe')), -- Mức độ ảnh hưởng
    CONSTRAINT edge_status_events_source_type_chk CHECK (source_type IN ('manual', 'ops_feed', 'etl_rule', 'scenario', 'system')), -- Chuẩn hóa nguồn tạo event
    CONSTRAINT edge_status_events_delay_nonnegative_chk CHECK (delay_min IS NULL OR delay_min >= 0), -- Nếu có số phút trễ thì không được âm
    CONSTRAINT edge_status_events_delay_required_chk CHECK (NOT (status = 'delayed' OR event_category = 'delay') OR delay_min IS NOT NULL), -- Delay event phải có số phút trễ
    CONSTRAINT edge_status_events_reason_code_not_blank_chk CHECK (reason_code IS NULL OR btrim(reason_code) <> ''), -- Nếu có mã lý do thì không được là chuỗi rỗng
    CONSTRAINT edge_status_events_reason_text_not_blank_chk CHECK (reason_text IS NULL OR btrim(reason_text) <> ''), -- Nếu có mô tả lý do thì không được là chuỗi rỗng
    CONSTRAINT edge_status_events_effective_range_chk CHECK (effective_to IS NULL OR effective_to >= effective_from) -- Khoảng hiệu lực phải hợp lệ
);

-- ==================================================================================================
-- 16) Sự kiện trạng thái chuyến
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS trip_status_events (
    trip_status_event_id BIGSERIAL NOT NULL, -- Mã sự kiện trạng thái chuyến
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm hệ thống ghi nhận event này; đây cũng là cột thời gian cho hypertable
    trip_id TEXT NOT NULL REFERENCES trips(trip_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Chuyến bị áp trạng thái
    status TEXT NOT NULL, -- Trạng thái chuẩn hóa của chuyến
    event_category TEXT NOT NULL DEFAULT 'incident', -- Nhóm sự kiện: delay, maintenance, incident, recovery...
    impact_level TEXT NOT NULL DEFAULT 'minor', -- Mức độ ảnh hưởng
    effective_from TIMESTAMPTZ NOT NULL, -- Thời điểm bắt đầu có hiệu lực nghiệp vụ
    effective_to TIMESTAMPTZ, -- Thời điểm kết thúc hiệu lực
    delay_min INTEGER, -- Số phút trễ nếu chuyến bị delayed
    reason_code TEXT, -- Mã lý do ngắn gọn
    reason_text TEXT, -- Mô tả lý do
    source_type TEXT NOT NULL DEFAULT 'manual', -- Nguồn tạo event
    source_ref TEXT, -- Khóa tham chiếu nguồn nếu có
    scenario_id TEXT REFERENCES scenarios(scenario_id) ON UPDATE CASCADE ON DELETE SET NULL, -- Tình huống giả lập gắn với trạng thái
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi

    CONSTRAINT trip_status_events_pk PRIMARY KEY (trip_status_event_id, recorded_at), -- Khóa chính gồm mã sự kiện và thời gian ghi nhận
    CONSTRAINT trip_status_events_status_chk CHECK (status IN ('normal', 'delayed', 'closed', 'maintenance', 'suspended', 'partial_suspend', 'disrupted', 'cancelled', 'recovered')), -- Tập trạng thái chuẩn hóa ở cấp chuyến
    CONSTRAINT trip_status_events_event_category_chk CHECK (event_category IN ('incident', 'delay', 'maintenance', 'service_change', 'recovery', 'manual_override')), -- Phân loại event
    CONSTRAINT trip_status_events_impact_level_chk CHECK (impact_level IN ('info', 'minor', 'moderate', 'major', 'severe')), -- Mức độ ảnh hưởng
    CONSTRAINT trip_status_events_source_type_chk CHECK (source_type IN ('manual', 'ops_feed', 'etl_rule', 'scenario', 'system')), -- Chuẩn hóa nguồn tạo event
    CONSTRAINT trip_status_events_delay_nonnegative_chk CHECK (delay_min IS NULL OR delay_min >= 0), -- Nếu có số phút trễ thì không được âm
    CONSTRAINT trip_status_events_delay_required_chk CHECK (NOT (status = 'delayed' OR event_category = 'delay') OR delay_min IS NOT NULL), -- Delay event phải có số phút trễ
    CONSTRAINT trip_status_events_reason_code_not_blank_chk CHECK (reason_code IS NULL OR btrim(reason_code) <> ''), -- Nếu có mã lý do thì không được là chuỗi rỗng
    CONSTRAINT trip_status_events_reason_text_not_blank_chk CHECK (reason_text IS NULL OR btrim(reason_text) <> ''), -- Nếu có mô tả lý do thì không được là chuỗi rỗng
    CONSTRAINT trip_status_events_effective_range_chk CHECK (effective_to IS NULL OR effective_to >= effective_from) -- Khoảng hiệu lực phải hợp lệ
);

-- ==================================================================================================
-- 21) Dự đoán giờ đến / giờ rời theo từng điểm dừng
--
-- Bảng này bám sát v5 nhưng được làm chặt hơn bằng line_id và khóa ngoại về timetable.
-- Nhờ vậy dữ liệu dự đoán không bị lệch khỏi lịch gốc.
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS predicted_stop_times (
    predicted_stop_time_id BIGSERIAL NOT NULL, -- Mã bản ghi dự đoán
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tính dự đoán, cũng là cột thời gian cho hypertable
    service_date DATE NOT NULL, -- Ngày service thực tế mà bản dự đoán này đang áp dụng; cột này giúp BE và FE không phải tự suy luận ngày
    timetable_id BIGINT NOT NULL, -- Dòng timetable gốc mà bản dự đoán này bám vào; đây là mỏ neo row-level để tránh các FK rời rạc chỉ hợp lệ từng phần
    trip_id TEXT NOT NULL, -- Mã chuyến tàu
    line_id TEXT NOT NULL, -- Tuyến của chuyến tàu
    station_id TEXT NOT NULL, -- Mã ga
    line_station_order INTEGER NOT NULL, -- Vị trí ga trên tuyến; giúp so khớp rõ hơn với timetable gốc và hỗ trợ debug theo chiều tuyến
    stop_sequence INTEGER NOT NULL, -- Thứ tự điểm dừng trong chuyến

    scheduled_arrival_time TIME NOT NULL, -- Giờ đến gốc theo lịch trong ngày service
    scheduled_arrival_day_offset SMALLINT NOT NULL DEFAULT 0, -- Độ lệch ngày của giờ đến gốc
    scheduled_departure_time TIME NOT NULL, -- Giờ rời gốc theo lịch trong ngày service
    scheduled_departure_day_offset SMALLINT NOT NULL DEFAULT 0, -- Độ lệch ngày của giờ rời gốc

    predicted_arrival_time TIME NOT NULL, -- Giờ đến dự đoán trong ngày service
    predicted_arrival_day_offset SMALLINT NOT NULL DEFAULT 0, -- Độ lệch ngày của giờ đến dự đoán
    predicted_departure_time TIME NOT NULL, -- Giờ rời dự đoán trong ngày service
    predicted_departure_day_offset SMALLINT NOT NULL DEFAULT 0, -- Độ lệch ngày của giờ rời dự đoán

    predicted_arrival_at TIMESTAMPTZ, -- Thời điểm đến dự đoán tuyệt đối; dùng cho API và FE khi muốn hiển thị theo mốc thời gian thật
    predicted_departure_at TIMESTAMPTZ, -- Thời điểm rời dự đoán tuyệt đối; dùng cho API và FE khi muốn hiển thị theo mốc thời gian thật

    delay_min INTEGER NOT NULL DEFAULT 0, -- Số phút trễ tại thời điểm dự đoán
    status TEXT NOT NULL DEFAULT 'on_time', -- Trạng thái dự đoán
    prediction_source TEXT NOT NULL DEFAULT 'simulation_engine', -- Nguồn sinh ra bản ghi dự đoán
    scenario_id TEXT REFERENCES scenarios(scenario_id) ON UPDATE CASCADE ON DELETE SET NULL, -- Tình huống giả lập gắn với dự đoán
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi

    CONSTRAINT predicted_stop_times_pk PRIMARY KEY (predicted_stop_time_id, updated_at), -- Khóa chính gồm mã dự đoán và thời gian tính
    CONSTRAINT predicted_stop_times_trip_fk FOREIGN KEY (trip_id, line_id) REFERENCES trips(trip_id, line_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Đảm bảo trip và line khớp nhau
    CONSTRAINT predicted_stop_times_timetable_row_fk FOREIGN KEY (timetable_id, trip_id, line_id, station_id, line_station_order, stop_sequence) REFERENCES timetable(timetable_id, trip_id, line_id, station_id, line_station_order, stop_sequence) ON UPDATE CASCADE ON DELETE CASCADE, -- Buộc tất cả thông tin trip/ga/vị trí/sequence phải cùng chỉ tới đúng một stop gốc trong timetable, thay vì chỉ đúng từng FK rời rạc
    CONSTRAINT predicted_stop_times_seq_positive_chk CHECK (stop_sequence > 0), -- Thứ tự điểm dừng phải lớn hơn 0
    CONSTRAINT predicted_stop_times_line_station_order_positive_chk CHECK (line_station_order > 0), -- Thứ tự ga trên tuyến phải lớn hơn 0
    CONSTRAINT predicted_stop_times_delay_nonnegative_chk CHECK (delay_min >= 0), -- Số phút trễ không được âm
    CONSTRAINT predicted_stop_times_absolute_time_order_chk CHECK (predicted_departure_at IS NULL OR predicted_arrival_at IS NULL OR predicted_departure_at >= predicted_arrival_at), -- Nếu có timestamp tuyệt đối thì giờ rời không được sớm hơn giờ đến
    CONSTRAINT predicted_stop_times_status_chk CHECK (status IN ('on_time', 'delayed', 'skipped', 'cancelled')), -- Chỉ chấp nhận các trạng thái dự đoán đã quy định
    CONSTRAINT predicted_stop_times_source_chk CHECK (prediction_source IN ('simulation_engine', 'realtime_feed', 'manual_override')), -- Chuẩn hóa nguồn sinh dự đoán để downstream không phải đoán bằng text tự do
    CONSTRAINT predicted_stop_times_sched_time_order_chk CHECK (
        scheduled_departure_day_offset > scheduled_arrival_day_offset
        OR (
            scheduled_departure_day_offset = scheduled_arrival_day_offset
            AND scheduled_departure_time >= scheduled_arrival_time
        )
    ), -- Giờ rời gốc không được sớm hơn giờ đến gốc nếu xét cả độ lệch ngày
    CONSTRAINT predicted_stop_times_pred_time_order_chk CHECK (
        predicted_departure_day_offset > predicted_arrival_day_offset
        OR (
            predicted_departure_day_offset = predicted_arrival_day_offset
            AND predicted_departure_time >= predicted_arrival_time
        )
    ) -- Giờ rời dự đoán không được sớm hơn giờ đến dự đoán nếu xét cả độ lệch ngày
);

-- ==================================================================================================
-- 22) Cạnh hiện hành phục vụ định tuyến

-- - dùng 2 unique index riêng ở phía dưới file
-- - *_current không lưu song song nhiều scenario
-- - 1 index cho trường hợp scenario_id IS NULL
-- - 1 index cho trường hợp scenario_id IS NOT NULL
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS routing_edges_current (
    routing_edge_id BIGSERIAL PRIMARY KEY, -- Mã bản ghi cạnh phục vụ định tuyến
    base_edge_id BIGINT NOT NULL REFERENCES edges(edge_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Mã cạnh cơ sở
    from_station_id TEXT NOT NULL REFERENCES stations(station_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Ga bắt đầu
    to_station_id TEXT NOT NULL REFERENCES stations(station_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Ga kết thúc
    line_id TEXT NOT NULL REFERENCES lines(line_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Tuyến của cạnh
    base_travel_time_min INTEGER NOT NULL, -- Thời gian đi cơ sở
    adjusted_travel_time_min INTEGER NOT NULL, -- Thời gian đi sau điều chỉnh
    is_available BOOLEAN NOT NULL DEFAULT TRUE, -- Cạnh có thể dùng để định tuyến hay không
    status_source TEXT NOT NULL DEFAULT 'normal', -- Nguồn làm thay đổi cạnh
    reason TEXT, -- Lý do cụ thể nếu cạnh bị thay đổi
    scenario_id TEXT REFERENCES scenarios(scenario_id) ON UPDATE CASCADE ON DELETE SET NULL, -- Tình huống giả lập đang áp dụng, NULL nghĩa là baseline hiện hành
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tính lại cạnh phục vụ
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi

    CONSTRAINT routing_edges_current_distinct_stations_chk CHECK (from_station_id <> to_station_id), -- Ga đầu và ga cuối của cạnh current phải khác nhau
    CONSTRAINT routing_edges_current_status_source_chk CHECK (status_source IN ('normal', 'delay_event', 'maintenance', 'manual_override', 'scenario')), -- Chuẩn hóa nguồn sinh trạng thái current của cạnh
    CONSTRAINT routing_edges_current_time_nonnegative_chk CHECK (base_travel_time_min > 0 AND adjusted_travel_time_min >= 0) -- Thời gian đi phải hợp lệ
);

-- ==================================================================================================
-- 23) Trạng thái hiện hành của ga
--
-- Giữ nguyên mô hình gần giống v5:
-- - Mỗi ga chỉ có 1 trạng thái current tại một thời điểm.
-- - scenario_id chỉ dùng để ghi nhận trạng thái current này được tính dưới scenario nào; bảng này không dùng để lưu song song nhiều current state cho nhiều scenario.
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS station_status_current (
    station_id TEXT PRIMARY KEY REFERENCES stations(station_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Mã ga và cũng là khóa chính
    status TEXT NOT NULL, -- Trạng thái hiện hành của ga
    reason TEXT, -- Lý do của trạng thái
    is_boarding_allowed BOOLEAN NOT NULL DEFAULT TRUE, -- Có cho phép lên tàu tại ga này hay không
    is_alighting_allowed BOOLEAN NOT NULL DEFAULT TRUE, -- Có cho phép xuống tàu tại ga này hay không
    scenario_id TEXT REFERENCES scenarios(scenario_id) ON UPDATE CASCADE ON DELETE SET NULL, -- Tình huống giả lập đang áp dụng cho bản current này
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm cập nhật trạng thái hiện hành
    CONSTRAINT station_status_current_status_chk CHECK (status IN ('normal', 'delayed', 'closed', 'maintenance', 'suspended', 'disrupted')), -- Chỉ chấp nhận các trạng thái đã quy định
    CONSTRAINT station_status_current_reason_not_blank_chk CHECK (reason IS NULL OR btrim(reason) <> '') -- Nếu có lý do thì không được là chuỗi rỗng
);

-- ==================================================================================================
-- 24) Trạng thái hiện hành của tuyến
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS line_status_current (
    line_id TEXT PRIMARY KEY REFERENCES lines(line_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Mã tuyến và cũng là khóa chính
    status TEXT NOT NULL, -- Trạng thái hiện hành của tuyến
    delay_min_avg NUMERIC(8,2) NOT NULL DEFAULT 0, -- Độ trễ trung bình hiện hành
    reason TEXT, -- Lý do của trạng thái
    scenario_id TEXT REFERENCES scenarios(scenario_id) ON UPDATE CASCADE ON DELETE SET NULL, -- Tình huống giả lập đang áp dụng cho bản current này
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm cập nhật trạng thái hiện hành
    CONSTRAINT line_status_current_status_chk CHECK (status IN ('normal', 'delayed', 'closed', 'maintenance', 'suspended', 'disrupted')), -- Chỉ chấp nhận các trạng thái đã quy định
    CONSTRAINT line_status_current_reason_not_blank_chk CHECK (reason IS NULL OR btrim(reason) <> ''), -- Nếu có lý do thì không được là chuỗi rỗng
    CONSTRAINT line_status_current_delay_avg_nonnegative_chk CHECK (delay_min_avg >= 0) -- Độ trễ trung bình không được âm
);

-- ==================================================================================================
-- 25) Snapshot các chuyến sắp rời ga
--
-- Bảng này để phục vụ BE/FE hiển thị nhanh.
-- So với v5, bảng này được thêm stop_sequence và line_id để bám chặt hơn vào timetable.
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS next_departures (
    next_departure_id BIGSERIAL NOT NULL, -- Mã bản ghi snapshot chuyến sắp rời
    updated_at TIMESTAMPTZ NOT NULL, -- Thời điểm chụp snapshot, cũng là cột thời gian cho hypertable
    service_date DATE NOT NULL, -- Ngày service thực tế của chuyến sắp rời; nhờ đó BE có thể đọc trực tiếp mà không phải tự suy ra ngày
    station_id TEXT NOT NULL, -- Mã ga
    line_id TEXT NOT NULL, -- Mã tuyến
    direction_id SMALLINT, -- Hướng chuẩn ở mức số; nên khớp với trips.direction_id
    direction_label TEXT NOT NULL, -- Nhãn hướng đi để hiển thị nhanh cho FE/BE
    trip_id TEXT NOT NULL, -- Mã chuyến tàu
    timetable_id BIGINT NOT NULL, -- Dòng timetable gốc mà snapshot này bám vào; dùng để khóa chặt row-level giống predicted_stop_times
    line_station_order INTEGER NOT NULL, -- Vị trí ga trên tuyến; giúp đối chiếu nhanh với timetable gốc và thuận tiện cho debug theo chiều tuyến
    stop_sequence INTEGER NOT NULL, -- Thứ tự điểm dừng của ga này trong chuyến
    headsign TEXT NOT NULL, -- Nhãn đích đến để FE hoặc BE hiển thị nhanh mà không cần join thêm trips

    predicted_departure_time TIME NOT NULL, -- Giờ rời dự đoán trong ngày service
    predicted_departure_day_offset SMALLINT NOT NULL DEFAULT 0, -- Độ lệch ngày của giờ rời dự đoán
    predicted_departure_at TIMESTAMPTZ, -- Thời điểm rời dự đoán tuyệt đối; hữu ích cho API next departures và sorting trực tiếp

    delay_min INTEGER NOT NULL DEFAULT 0, -- Số phút trễ
    status TEXT NOT NULL DEFAULT 'on_time', -- Trạng thái dự đoán của chuyến sắp rời
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm tạo bản ghi

    CONSTRAINT next_departures_pk PRIMARY KEY (next_departure_id, updated_at), -- Khóa chính gồm mã bản ghi và thời gian snapshot
    CONSTRAINT next_departures_trip_fk FOREIGN KEY (trip_id, line_id) REFERENCES trips(trip_id, line_id) ON UPDATE CASCADE ON DELETE CASCADE, -- Đảm bảo trip và line khớp nhau
    CONSTRAINT next_departures_timetable_row_fk FOREIGN KEY (timetable_id, trip_id, line_id, station_id, line_station_order, stop_sequence) REFERENCES timetable(timetable_id, trip_id, line_id, station_id, line_station_order, stop_sequence) ON UPDATE CASCADE ON DELETE CASCADE, -- Buộc snapshot phải bám vào đúng một stop gốc trong timetable thay vì đúng rời rạc theo nhiều khóa khác nhau
    CONSTRAINT next_departures_direction_id_chk CHECK (direction_id IS NULL OR direction_id IN (0, 1)), -- Nếu có hướng chuẩn thì chỉ nhận 0 hoặc 1
    CONSTRAINT next_departures_direction_label_not_blank_chk CHECK (btrim(direction_label) <> ''), -- Nhãn hướng không được rỗng sau khi trim
    CONSTRAINT next_departures_headsign_not_blank_chk CHECK (btrim(headsign) <> ''), -- Headsign không được rỗng sau khi trim
    CONSTRAINT next_departures_line_station_order_positive_chk CHECK (line_station_order > 0), -- Thứ tự ga trên tuyến phải lớn hơn 0
    CONSTRAINT next_departures_departure_day_offset_chk CHECK (predicted_departure_day_offset >= 0), -- Độ lệch ngày không được âm
    CONSTRAINT next_departures_delay_nonnegative_chk CHECK (delay_min >= 0), -- Số phút trễ không được âm
    CONSTRAINT next_departures_status_chk CHECK (status IN ('on_time', 'delayed', 'skipped', 'cancelled')) -- Chỉ chấp nhận các trạng thái dự đoán đã quy định
);

-- ==================================================================================================
-- 26) Log yêu cầu tìm đường
-- ==================================================================================================
CREATE TABLE IF NOT EXISTS route_request_logs (
    request_id BIGSERIAL NOT NULL, -- Mã yêu cầu tìm đường
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(), -- Thời điểm ghi nhận yêu cầu, cũng là cột thời gian cho hypertable
    origin_station_id TEXT NOT NULL REFERENCES stations(station_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Ga xuất phát
    destination_station_id TEXT NOT NULL REFERENCES stations(station_id) ON UPDATE CASCADE ON DELETE RESTRICT, -- Ga đích
    departure_time TIMESTAMPTZ NOT NULL, -- Thời điểm người dùng muốn xuất phát
    scenario_id TEXT REFERENCES scenarios(scenario_id) ON UPDATE CASCADE ON DELETE SET NULL, -- Tình huống giả lập áp dụng khi xử lý
    algorithm_version TEXT NOT NULL, -- Phiên bản thuật toán được dùng
    execution_ms INTEGER, -- Thời gian chạy thuật toán tính bằng mili giây
    result_status TEXT NOT NULL, -- Trạng thái kết quả xử lý
    result_payload JSONB, -- Dữ liệu kết quả hoặc thông tin chẩn đoán ở dạng JSON
    CONSTRAINT route_request_logs_pk PRIMARY KEY (request_id, created_at), -- Khóa chính gồm mã yêu cầu và thời điểm tạo
    CONSTRAINT route_request_logs_execution_ms_chk CHECK (execution_ms IS NULL OR execution_ms >= 0), -- Thời gian chạy không được âm
    CONSTRAINT route_request_logs_result_status_chk CHECK (result_status IN ('success', 'no_path', 'invalid_request', 'error', 'timeout')), -- Chuẩn hóa trạng thái kết quả để dễ thống kê và alert
    CONSTRAINT route_request_logs_distinct_stations_chk CHECK (origin_station_id <> destination_station_id) -- Ga xuất phát và ga đích phải khác nhau
);



-- ==================================================================================================
-- 27) View hỗ trợ đọc dữ liệu dễ hơn cho BE và team thuật toán
-- ==================================================================================================

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

-- ==================================================================================================
-- 28) Index
-- ==================================================================================================
CREATE INDEX IF NOT EXISTS idx_stations_geom ON stations USING GIST (geom); -- Index không gian cho tọa độ ga
CREATE INDEX IF NOT EXISTS idx_edges_geom ON edges USING GIST (geom); -- Index không gian cho hình học đoạn tuyến
CREATE INDEX IF NOT EXISTS idx_station_lines_line_order ON station_lines (line_id, station_order); -- Tăng tốc truy vấn thứ tự ga theo tuyến
CREATE INDEX IF NOT EXISTS idx_station_lines_station_line ON station_lines (station_id, line_id); -- Tăng tốc kiểm tra ga có thuộc tuyến hay không
CREATE INDEX IF NOT EXISTS idx_edges_line ON edges (line_id); -- Tăng tốc truy vấn cạnh theo tuyến
CREATE INDEX IF NOT EXISTS idx_edges_from_station ON edges (from_station_id); -- Tăng tốc truy vấn cạnh đi ra từ ga
CREATE INDEX IF NOT EXISTS idx_edges_to_station ON edges (to_station_id); -- Tăng tốc truy vấn cạnh đi vào ga
CREATE INDEX IF NOT EXISTS idx_edges_line_from_order ON edges (line_id, from_station_order); -- Tăng tốc truy vấn cạnh theo thứ tự ga bắt đầu trên tuyến
CREATE INDEX IF NOT EXISTS idx_edges_line_to_order ON edges (line_id, to_station_order); -- Tăng tốc truy vấn cạnh theo thứ tự ga kết thúc trên tuyến
CREATE INDEX IF NOT EXISTS idx_transfers_from_station ON transfers (from_station_id); -- Tăng tốc truy vấn trung chuyển từ ga
CREATE INDEX IF NOT EXISTS idx_transfers_to_station ON transfers (to_station_id); -- Tăng tốc truy vấn trung chuyển tới ga
CREATE INDEX IF NOT EXISTS idx_service_calendar_date_range ON service_calendar (start_date, end_date); -- Tăng tốc lọc lịch cơ sở theo khoảng ngày
CREATE INDEX IF NOT EXISTS idx_holiday_dates_date ON holiday_dates (holiday_date); -- Tăng tốc tra cứu ngày lễ
CREATE INDEX IF NOT EXISTS idx_service_exceptions_date ON service_exceptions (service_date); -- Tăng tốc tra cứu ngoại lệ theo ngày
CREATE INDEX IF NOT EXISTS idx_service_exceptions_service_date ON service_exceptions (service_id, service_date); -- Tăng tốc tra cứu ngoại lệ theo service và ngày
CREATE INDEX IF NOT EXISTS idx_service_exceptions_date_category ON service_exceptions (service_date, exception_category); -- Tăng tốc phân tích ngoại lệ theo ngày và nhóm ngoại lệ
CREATE INDEX IF NOT EXISTS idx_timetable_trip_sequence ON timetable (trip_id, stop_sequence); -- Tăng tốc truy vấn giờ biểu theo chuyến và thứ tự dừng
CREATE INDEX IF NOT EXISTS idx_timetable_line_station ON timetable (line_id, station_id); -- Tăng tốc truy vấn giờ biểu theo tuyến và ga
CREATE INDEX IF NOT EXISTS idx_timetable_station ON timetable (station_id); -- Tăng tốc truy vấn giờ biểu theo ga
CREATE INDEX IF NOT EXISTS idx_trips_line_service_direction ON trips (line_id, service_id, direction_id); -- Tăng tốc truy vấn chuyến theo tuyến, lịch chạy và hướng
CREATE INDEX IF NOT EXISTS idx_trips_origin_station ON trips (origin_station_id); -- Tăng tốc truy vấn chuyến theo ga đầu
CREATE INDEX IF NOT EXISTS idx_trips_destination_station ON trips (destination_station_id); -- Tăng tốc truy vấn chuyến theo ga cuối
CREATE INDEX IF NOT EXISTS idx_routing_edges_current_base_edge ON routing_edges_current (base_edge_id); -- Tăng tốc tra cứu cạnh hiện hành theo cạnh cơ sở
CREATE INDEX IF NOT EXISTS idx_routing_edges_current_from_to ON routing_edges_current (from_station_id, to_station_id); -- Tăng tốc truy vấn cạnh phục vụ định tuyến
CREATE UNIQUE INDEX IF NOT EXISTS idx_routing_edges_current_base_edge_null_scenario_unique ON routing_edges_current (base_edge_id) WHERE scenario_id IS NULL; -- Đảm bảo mỗi cạnh cơ sở chỉ có một bản current baseline khi scenario_id là NULL
CREATE UNIQUE INDEX IF NOT EXISTS idx_routing_edges_current_base_edge_scenario_unique ON routing_edges_current (base_edge_id, scenario_id) WHERE scenario_id IS NOT NULL; -- Đảm bảo mỗi cạnh cơ sở chỉ có một bản current cho mỗi scenario cụ thể
CREATE INDEX IF NOT EXISTS idx_station_status_current_status ON station_status_current (status); -- Tăng tốc lọc trạng thái ga hiện hành
CREATE INDEX IF NOT EXISTS idx_line_status_current_status ON line_status_current (status); -- Tăng tốc lọc trạng thái tuyến hiện hành
CREATE INDEX IF NOT EXISTS idx_line_status_events_line_time ON line_status_events (line_id, recorded_at DESC); -- Tăng tốc truy vấn trạng thái mới nhất theo tuyến
CREATE INDEX IF NOT EXISTS idx_line_status_events_line_effective ON line_status_events (line_id, effective_from DESC); -- Tăng tốc lọc các event đang hoặc sắp có hiệu lực theo tuyến
CREATE INDEX IF NOT EXISTS idx_line_status_events_category_time ON line_status_events (event_category, recorded_at DESC); -- Tăng tốc phân tích sự kiện theo nhóm như delay hay maintenance
CREATE INDEX IF NOT EXISTS idx_station_status_events_station_time ON station_status_events (station_id, recorded_at DESC); -- Tăng tốc truy vấn trạng thái mới nhất theo ga
CREATE INDEX IF NOT EXISTS idx_station_status_events_station_effective ON station_status_events (station_id, effective_from DESC); -- Tăng tốc lọc event hiệu lực theo ga
CREATE INDEX IF NOT EXISTS idx_edge_status_events_edge_time ON edge_status_events (edge_id, recorded_at DESC); -- Tăng tốc truy vấn trạng thái mới nhất theo cạnh
CREATE INDEX IF NOT EXISTS idx_edge_status_events_edge_effective ON edge_status_events (edge_id, effective_from DESC); -- Tăng tốc lọc event hiệu lực theo cạnh
CREATE INDEX IF NOT EXISTS idx_trip_status_events_trip_time ON trip_status_events (trip_id, recorded_at DESC); -- Tăng tốc truy vấn trạng thái mới nhất theo chuyến
CREATE INDEX IF NOT EXISTS idx_trip_status_events_trip_effective ON trip_status_events (trip_id, effective_from DESC); -- Tăng tốc lọc event hiệu lực theo chuyến
CREATE INDEX IF NOT EXISTS idx_predicted_stop_times_trip_station_time ON predicted_stop_times (trip_id, station_id, updated_at DESC); -- Tăng tốc truy vấn dự đoán mới nhất theo chuyến và ga
CREATE INDEX IF NOT EXISTS idx_predicted_stop_times_service_date_station ON predicted_stop_times (service_date, station_id, updated_at DESC); -- Tăng tốc query dự đoán theo ngày service và ga
CREATE INDEX IF NOT EXISTS idx_next_departures_station_line_time ON next_departures (station_id, line_id, updated_at DESC); -- Tăng tốc truy vấn chuyến sắp rời theo ga và tuyến
CREATE INDEX IF NOT EXISTS idx_next_departures_service_date_station ON next_departures (service_date, station_id, updated_at DESC); -- Tăng tốc query chuyến sắp rời theo ngày service và ga
CREATE INDEX IF NOT EXISTS idx_next_departures_departure_at ON next_departures (predicted_departure_at); -- Tăng tốc sắp xếp và lọc theo giờ rời tuyệt đối
CREATE INDEX IF NOT EXISTS idx_route_request_logs_created_at ON route_request_logs (created_at DESC); -- Tăng tốc phân tích log theo thời gian

-- ==================================================================================================
-- 29) Chuyển các bảng time-series thành hypertable
-- ==================================================================================================
SELECT create_hypertable('line_status_events', 'recorded_at', if_not_exists => TRUE, migrate_data => TRUE); -- Chuyển bảng line_status_events thành hypertable theo recorded_at
SELECT create_hypertable('station_status_events', 'recorded_at', if_not_exists => TRUE, migrate_data => TRUE); -- Chuyển bảng station_status_events thành hypertable theo recorded_at
SELECT create_hypertable('edge_status_events', 'recorded_at', if_not_exists => TRUE, migrate_data => TRUE); -- Chuyển bảng edge_status_events thành hypertable theo recorded_at
SELECT create_hypertable('trip_status_events', 'recorded_at', if_not_exists => TRUE, migrate_data => TRUE); -- Chuyển bảng trip_status_events thành hypertable theo recorded_at
SELECT create_hypertable('predicted_stop_times', 'updated_at', if_not_exists => TRUE, migrate_data => TRUE); -- Chuyển bảng predicted_stop_times thành hypertable theo updated_at
SELECT create_hypertable('next_departures', 'updated_at', if_not_exists => TRUE, migrate_data => TRUE); -- Chuyển bảng next_departures thành hypertable theo updated_at
SELECT create_hypertable('route_request_logs', 'created_at', if_not_exists => TRUE, migrate_data => TRUE); -- Chuyển bảng route_request_logs thành hypertable theo created_at


-- ========================
-- 30) Tự động updated_at
-- ========================

-- Hàm tự động cập nhật thời gian
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE OR REPLACE TRIGGER trg_lines_updated_at
BEFORE UPDATE ON lines
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trg_stations_updated_at
BEFORE UPDATE ON stations
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trg_station_lines_updated_at
BEFORE UPDATE ON station_lines
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trg_edges_updated_at
BEFORE UPDATE ON edges
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trg_transfers_updated_at
BEFORE UPDATE ON transfers
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trg_service_calendar_updated_at
BEFORE UPDATE ON service_calendar
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trg_holiday_dates_updated_at
BEFORE UPDATE ON holiday_dates
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trg_service_exceptions_updated_at
BEFORE UPDATE ON service_exceptions
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trg_trips_updated_at
BEFORE UPDATE ON trips
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trg_timetable_updated_at
BEFORE UPDATE ON timetable
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trg_scenarios_updated_at
BEFORE UPDATE ON scenarios
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trg_station_status_current_updated_at
BEFORE UPDATE ON station_status_current
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trg_line_status_current_updated_at
BEFORE UPDATE ON line_status_current
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


COMMIT;

-- =====================
-- INSERT DATA
-- =====================

--INSERT INTO lines (line_id, line_code, line_name, operator_name, color_hex, is_active) 
--VALUES
--    ('karasuma', 'K', 'Karasuma Line', 'Kyoto Municipal Transportation Bureau', '#4CAF50', TRUE),
--    ('tozai',    'T', 'Tozai Line',    'Kyoto Municipal Transportation Bureau', '#E60012', TRUE);


--INSERT INTO stations (station_id, station_name, geom, is_transfer_station, is_active) 
--VALUES
--    ('K01', 'Kokusaikaikan', 	ST_SetSRID(ST_MakePoint(135.785171, 35.063612), 4326), FALSE, TRUE),
--    ('K02', 'Matsugasaki', 		ST_SetSRID(ST_MakePoint(135.775158, 35.051656), 4326), FALSE, TRUE),
--    ('K03', 'Kitayama', 		ST_SetSRID(ST_MakePoint(135.765209, 35.051243), 4326), FALSE, TRUE),
--    ('K04', 'Kitaoji', 			ST_SetSRID(ST_MakePoint(135.758709, 35.044573), 4326), FALSE, TRUE),
--    ('K05', 'Kuramaguchi', 		ST_SetSRID(ST_MakePoint(135.759303, 35.037182), 4326), FALSE, TRUE),
--    ('K06', 'Imadegawa', 		ST_SetSRID(ST_MakePoint(135.759369, 35.029394), 4326), FALSE, TRUE),
--    ('K07', 'Marutamachi', 		ST_SetSRID(ST_MakePoint(135.759553, 35.016288), 4326), FALSE, TRUE),
--    ('K08', 'Karasuma Oike', 	ST_SetSRID(ST_MakePoint(135.759646, 35.010824), 4326), TRUE,  TRUE),
--    ('K09', 'Shijo', 			ST_SetSRID(ST_MakePoint(135.759653, 35.002469), 4326), FALSE, TRUE),
--    ('K10', 'Gojo', 			ST_SetSRID(ST_MakePoint(135.759714, 34.994940), 4326), FALSE, TRUE),
--    ('K11', 'Kyoto', 			ST_SetSRID(ST_MakePoint(135.758505, 34.987082), 4326), FALSE, TRUE),
--    ('K12', 'Kujo', 			ST_SetSRID(ST_MakePoint(135.759723, 34.979173), 4326), FALSE, TRUE),
--    ('K13', 'Jujo', 			ST_SetSRID(ST_MakePoint(135.752433, 34.973728), 4326), FALSE, TRUE),
--    ('K14', 'Kuinabashi', 		ST_SetSRID(ST_MakePoint(135.757046, 34.962281), 4326), FALSE, TRUE),
--    ('K15', 'Takeda', 			ST_SetSRID(ST_MakePoint(135.756489, 34.957164), 4326), FALSE, TRUE),
--    
--    ('T01', 'Rokujizo', 		ST_SetSRID(ST_MakePoint(135.793342, 34.931953), 4326), FALSE, TRUE),
--    ('T02', 'Ishida', 			ST_SetSRID(ST_MakePoint(135.804006, 34.940626), 4326), FALSE, TRUE),
--    ('T03', 'Daigo', 			ST_SetSRID(ST_MakePoint(135.810651, 34.950669), 4326), FALSE, TRUE),
--    ('T04', 'Ono', 				ST_SetSRID(ST_MakePoint(135.812689, 34.961145), 4326), FALSE, TRUE),
--    ('T05', 'Nagitsuji', 		ST_SetSRID(ST_MakePoint(135.814901, 34.972709), 4326), FALSE, TRUE),
--    ('T06', 'Higashino', 		ST_SetSRID(ST_MakePoint(135.816675, 34.981957), 4326), FALSE, TRUE),
--    ('T07', 'Yamashina', 		ST_SetSRID(ST_MakePoint(135.817237, 34.992636), 4326), FALSE, TRUE),
--    ('T08', 'Misasagi', 		ST_SetSRID(ST_MakePoint(135.801768, 34.996060), 4326), FALSE, TRUE),
--    ('T09', 'Keage', 			ST_SetSRID(ST_MakePoint(135.790557, 35.007597), 4326), FALSE, TRUE),
--    ('T10', 'Higashiyama', 		ST_SetSRID(ST_MakePoint(135.779778, 35.009434), 4326), FALSE, TRUE),
--    ('T11', 'Sanjo Keihan', 	ST_SetSRID(ST_MakePoint(135.772605, 35.008151), 4326), FALSE, TRUE),
--    ('T12', 'Kyoto Shiyakusho-mae', ST_SetSRID(ST_MakePoint(135.768870, 35.010899), 4326), FALSE, TRUE),
--    ('T13', 'Karasuma Oike', 	ST_SetSRID(ST_MakePoint(135.759646, 35.010824), 4326), TRUE,  TRUE),
--    ('T14', 'Nijojo-mae', 		ST_SetSRID(ST_MakePoint(135.750281, 35.011890), 4326), FALSE, TRUE),
--    ('T15', 'Nijo', 			ST_SetSRID(ST_MakePoint(135.741730, 35.011028), 4326), FALSE, TRUE),
--    ('T16', 'Nishioji Oike', 	ST_SetSRID(ST_MakePoint(135.730634, 35.010945), 4326), FALSE, TRUE),
--    ('T17', 'Uzumasa Tenjingawa', ST_SetSRID(ST_MakePoint(135.715634, 35.010813), 4326), FALSE, TRUE);


--INSERT INTO station_lines ( line_id, station_order, station_id, is_terminal) 
--VALUES
--    ('karasuma', 1,  'K01', TRUE),
--    ('karasuma', 2,  'K02', FALSE),
--    ('karasuma', 3,  'K03', FALSE),
--    ('karasuma', 4,  'K04', FALSE),
--    ('karasuma', 5,  'K05', FALSE),
--    ('karasuma', 6,  'K06', FALSE),
--    ('karasuma', 7,  'K07', FALSE),
--    ('karasuma', 8,  'K08', FALSE),
--    ('karasuma', 9,  'K09', FALSE),
--    ('karasuma', 10, 'K10', FALSE),
--    ('karasuma', 11, 'K11', FALSE),
--    ('karasuma', 12, 'K12', FALSE),
--    ('karasuma', 13, 'K13', FALSE),
--    ('karasuma', 14, 'K14', FALSE),
--    ('karasuma', 15, 'K15', TRUE),
--
--    ('tozai', 1,  'T01', TRUE),
--    ('tozai', 2,  'T02', FALSE),
--    ('tozai', 3,  'T03', FALSE),
--    ('tozai', 4,  'T04', FALSE),
--    ('tozai', 5,  'T05', FALSE),
--    ('tozai', 6,  'T06', FALSE),
--    ('tozai', 7,  'T07', FALSE),
--    ('tozai', 8,  'T08', FALSE),
--    ('tozai', 9,  'T09', FALSE),
--    ('tozai', 10, 'T10', FALSE),
--    ('tozai', 11, 'T11', FALSE),
--    ('tozai', 12, 'T12', FALSE),
--    ('tozai', 13, 'T13', FALSE),
--    ('tozai', 14, 'T14', FALSE),
--    ('tozai', 15, 'T15', FALSE),
--    ('tozai', 16, 'T16', FALSE),
--    ('tozai', 17, 'T17', TRUE);


--INSERT INTO edges (line_id, from_station_id, from_station_order, to_station_id, to_station_order, travel_time_min, distance_km, geom, is_active)
--SELECT
--    v.line_id,
--    v.from_station_id,
--    v.from_station_order,
--    v.to_station_id,
--    v.to_station_order,
--    v.travel_time_min,
--    ROUND((ST_Length(ST_MakeLine(sf.geom, st.geom)::geography) / 1000.0)::numeric, 3) AS distance_km,
--    ST_MakeLine(sf.geom, st.geom) AS geom,
--    TRUE AS is_active
--FROM (
--    VALUES
--        -- Karasuma Line: forward
--        ('karasuma', 'K01',  1, 'K02',  2, 2),
--        ('karasuma', 'K02',  2, 'K03',  3, 2),
--        ('karasuma', 'K03',  3, 'K04',  4, 2),
--        ('karasuma', 'K04',  4, 'K05',  5, 2),
--        ('karasuma', 'K05',  5, 'K06',  6, 2),
--        ('karasuma', 'K06',  6, 'K07',  7, 2),
--        ('karasuma', 'K07',  7, 'K08',  8, 2),
--        ('karasuma', 'K08',  8, 'K09',  9, 2),
--        ('karasuma', 'K09',  9, 'K10', 10, 2),
--        ('karasuma', 'K10', 10, 'K11', 11, 2),
--        ('karasuma', 'K11', 11, 'K12', 12, 1),
--        ('karasuma', 'K12', 12, 'K13', 13, 2),
--        ('karasuma', 'K13', 13, 'K14', 14, 2),
--        ('karasuma', 'K14', 14, 'K15', 15, 1),
--
--        -- Karasuma Line: backward
--        ('karasuma', 'K02',  2, 'K01',  1, 2),
--        ('karasuma', 'K03',  3, 'K02',  2, 2),
--        ('karasuma', 'K04',  4, 'K03',  3, 2),
--        ('karasuma', 'K05',  5, 'K04',  4, 2),
--        ('karasuma', 'K06',  6, 'K05',  5, 2),
--        ('karasuma', 'K07',  7, 'K06',  6, 2),
--        ('karasuma', 'K08',  8, 'K07',  7, 2),
--        ('karasuma', 'K09',  9, 'K08',  8, 2),
--        ('karasuma', 'K10', 10, 'K09',  9, 2),
--        ('karasuma', 'K11', 11, 'K10', 10, 2),
--        ('karasuma', 'K12', 12, 'K11', 11, 1),
--        ('karasuma', 'K13', 13, 'K12', 12, 2),
--        ('karasuma', 'K14', 14, 'K13', 13, 2),
--        ('karasuma', 'K15', 15, 'K14', 14, 1),
--
--        -- Tozai Line: forward
--        ('tozai', 'T01',  1, 'T02',  2, 3),
--        ('tozai', 'T02',  2, 'T03',  3, 2),
--        ('tozai', 'T03',  3, 'T04',  4, 2),
--        ('tozai', 'T04',  4, 'T05',  5, 2),
--        ('tozai', 'T05',  5, 'T06',  6, 2),
--        ('tozai', 'T06',  6, 'T07',  7, 2),
--        ('tozai', 'T07',  7, 'T08',  8, 3),
--        ('tozai', 'T08',  8, 'T09',  9, 3),
--        ('tozai', 'T09',  9, 'T10', 10, 2),
--        ('tozai', 'T10', 10, 'T11', 11, 2),
--        ('tozai', 'T11', 11, 'T12', 12, 1),
--        ('tozai', 'T12', 12, 'T13', 13, 2),
--        ('tozai', 'T13', 13, 'T14', 14, 2),
--        ('tozai', 'T14', 14, 'T15', 15, 2),
--        ('tozai', 'T15', 15, 'T16', 16, 2),
--        ('tozai', 'T16', 16, 'T17', 17, 2),
--
--        -- Tozai Line: backward
--        ('tozai', 'T02',  2, 'T01',  1, 3),
--        ('tozai', 'T03',  3, 'T02',  2, 2),
--        ('tozai', 'T04',  4, 'T03',  3, 2),
--        ('tozai', 'T05',  5, 'T04',  4, 2),
--        ('tozai', 'T06',  6, 'T05',  5, 2),
--        ('tozai', 'T07',  7, 'T06',  6, 2),
--        ('tozai', 'T08',  8, 'T07',  7, 3),
--        ('tozai', 'T09',  9, 'T08',  8, 3),
--        ('tozai', 'T10', 10, 'T09',  9, 2),
--        ('tozai', 'T11', 11, 'T10', 10, 2),
--        ('tozai', 'T12', 12, 'T11', 11, 1),
--        ('tozai', 'T13', 13, 'T12', 12, 2),
--        ('tozai', 'T14', 14, 'T13', 13, 2),
--        ('tozai', 'T15', 15, 'T14', 14, 2),
--        ('tozai', 'T16', 16, 'T15', 15, 2),
--        ('tozai', 'T17', 17, 'T16', 16, 2)
--) AS v(line_id, from_station_id, from_station_order, to_station_id, to_station_order, travel_time_min)
--JOIN stations sf
--  ON sf.station_id = v.from_station_id
--JOIN stations st
--  ON st.station_id = v.to_station_id;

-- source: https://www2.city.kyoto.lg.jp/kotsu/webguide/en/tika/travel_time.html


--INSERT INTO transfers (from_station_id, to_station_id, transfer_time_min, is_active, transfer_type, note) 
--VALUES
--    ('K08', 'T13', 4, TRUE, 'same_station_interchange', 'Transfer between Karasuma Line and Tozai Line at Karasuma Oike'),
--    ('T13', 'K08', 4, TRUE, 'same_station_interchange', 'Transfer between Tozai Line and Karasuma Line at Karasuma Oike');


--INSERT INTO service_calendar (service_id, service_name, service_type, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date) 
--VALUES
--    ('weekday_service', 'Weekday Service', 'weekday', TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, DATE '2025-01-01', DATE '2030-12-31'),
--    ('saturday_service', 'Saturday Service', 'saturday', FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, DATE '2025-01-01', DATE '2030-12-31'),
--    ('sunday_service', 'Sunday Service', 'sunday', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, DATE '2025-01-01', DATE '2030-12-31'),
--    ('holiday_service', 'Holiday Service', 'holiday', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, DATE '2025-01-01', DATE '2030-12-31'),
--    ('special_service', 'Special Service', 'special', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, DATE '2025-01-01', DATE '2030-12-31');   


--INSERT INTO holiday_dates (holiday_date, holiday_name, is_public_holiday, note) 
--VALUES
--    ('2026-01-01', 'New Year''s Day', 			TRUE, NULL),
--    ('2026-01-12', 'Coming of Age Day', 		TRUE, NULL),
--    ('2026-02-11', 'National Foundation Day', 	TRUE, NULL),
--    ('2026-02-23', 'Emperor''s Birthday', 		TRUE, NULL),
--    ('2026-03-20', 'Vernal Equinox Day', 		TRUE, NULL),
--    ('2026-04-29', 'Showa Day', 				TRUE, NULL),
--    ('2026-05-03', 'Constitution Memorial Day', TRUE, NULL),
--    ('2026-05-04', 'Greenery Day', 				TRUE, NULL),
--    ('2026-05-05', 'Children''s Day', 			TRUE, NULL),
--    ('2026-05-06', 'Holiday', 					TRUE, 'Substitute holiday'),
--    ('2026-07-20', 'Marine Day', 				TRUE, NULL),
--    ('2026-08-11', 'Mountain Day', 				TRUE, NULL),
--    ('2026-09-21', 'Respect for the Aged Day', 	TRUE, NULL),
--    ('2026-09-22', 'Holiday', 					TRUE, 'Citizen''s holiday'),
--    ('2026-09-23', 'Autumnal Equinox Day', 		TRUE, NULL),
--    ('2026-10-12', 'Sports Day', 				TRUE, NULL),
--    ('2026-11-03', 'Culture Day', 				TRUE, NULL),
--    ('2026-11-23', 'Labor Thanksgiving Day', 	TRUE, NULL),
--
--    ('2027-01-01', 'New Year''s Day', 			TRUE, NULL),
--    ('2027-01-11', 'Coming of Age Day', 		TRUE, NULL),
--    ('2027-02-11', 'National Foundation Day', 	TRUE, NULL),
--    ('2027-02-23', 'Emperor''s Birthday', 		TRUE, NULL),
--    ('2027-03-21', 'Vernal Equinox Day', 		TRUE, NULL),
--    ('2027-03-22', 'Holiday', 					TRUE, 'Substitute holiday'),
--    ('2027-04-29', 'Showa Day', 				TRUE, NULL),
--    ('2027-05-03', 'Constitution Memorial Day', TRUE, NULL),
--    ('2027-05-04', 'Greenery Day', 				TRUE, NULL),
--    ('2027-05-05', 'Children''s Day', 			TRUE, NULL),
--    ('2027-07-19', 'Marine Day', 				TRUE, NULL),
--    ('2027-08-11', 'Mountain Day', 				TRUE, NULL),
--    ('2027-09-20', 'Respect for the Aged Day', 	TRUE, NULL),
--    ('2027-09-23', 'Autumnal Equinox Day', 		TRUE, NULL),
--    ('2027-10-11', 'Sports Day', 				TRUE, NULL),
--    ('2027-11-03', 'Culture Day', 				TRUE, NULL),
--    ('2027-11-23', 'Labor Thanksgiving Day', 	TRUE, NULL);
    
-- Source: https://www8.cao.go.jp/chosei/shukujitsu/gaiyou.html


--INSERT INTO service_exceptions (service_id, service_date, exception_type, exception_category, reason, note) 
--VALUES
--    ('weekday_service', '2026-01-01', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2026-01-01', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-01-12', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2026-01-12', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-02-11', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2026-02-11', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-02-23', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2026-02-23', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-03-20', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2026-03-20', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-04-29', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2026-04-29', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('sunday_service', '2026-05-03', 'removed', 'holiday', 'public_holiday', 'Switch from Sunday service to holiday service'),
--    ('holiday_service', '2026-05-03', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-05-04', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2026-05-04', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-05-05', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2026-05-05', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-05-06', 'removed', 'holiday', 'public_holiday', 'Substitute holiday: switch from weekday service to holiday service'),
--    ('holiday_service', '2026-05-06', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('sunday_service', '2026-07-20', 'removed', 'holiday', 'public_holiday', 'Switch from Sunday service to holiday service'),
--    ('holiday_service', '2026-07-20', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-08-11', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2026-08-11', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-09-21', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2026-09-21', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-09-22', 'removed', 'holiday', 'public_holiday', 'Citizen''s holiday: switch from weekday service to holiday service'),
--    ('holiday_service', '2026-09-22', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-09-23', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2026-09-23', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('sunday_service', '2026-10-12', 'removed', 'holiday', 'public_holiday', 'Switch from Sunday service to holiday service'),
--    ('holiday_service', '2026-10-12', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-11-03', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2026-11-03', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2026-11-23', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2026-11-23', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--
--    ('weekday_service', '2027-01-01', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-01-01', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-01-11', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-01-11', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-02-11', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-02-11', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-02-23', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-02-23', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('sunday_service', '2027-03-21', 'removed', 'holiday', 'public_holiday', 'Switch from Sunday service to holiday service'),
--    ('holiday_service', '2027-03-21', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-03-22', 'removed', 'holiday', 'public_holiday', 'Substitute holiday: switch from weekday service to holiday service'),
--    ('holiday_service', '2027-03-22', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-04-29', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-04-29', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-05-03', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-05-03', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-05-04', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-05-04', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-05-05', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-05-05', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-07-19', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-07-19', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-08-11', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-08-11', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-09-20', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-09-20', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-09-23', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-09-23', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-10-11', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-10-11', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-11-03', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-11-03', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
--    ('weekday_service', '2027-11-23', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
--    ('holiday_service', '2027-11-23', 'added', 'holiday', 'public_holiday', 'Enable holiday service');


--INSERT INTO scenarios (scenario_id, scenario_name, scenario_type, description, is_active) 
--VALUES
--    -- Delay scenarios
--    ('delay_morning_peak_karasuma', 'Karasuma Morning Peak Delay', 'delay', 'Simulate moderate delays on Karasuma Line during morning peak hours.', FALSE),
--    ('delay_evening_peak_tozai', 'Tozai Evening Peak Delay', 'delay', 'Simulate moderate delays on Tozai Line during evening peak hours.', FALSE),
--    ('delay_karasuma_full_line', 'Karasuma Full Line Delay', 'delay', 'Simulate end-to-end delays affecting the entire Karasuma Line.', FALSE),
--    ('delay_tozai_full_line', 'Tozai Full Line Delay', 'delay', 'Simulate end-to-end delays affecting the entire Tozai Line.', FALSE),
--    ('delay_karasuma_central_segment', 'Karasuma Central Segment Delay', 'delay', 'Simulate concentrated delays on central Karasuma Line stations and adjacent segments.', FALSE),
--    ('delay_tozai_eastern_segment', 'Tozai Eastern Segment Delay', 'delay', 'Simulate concentrated delays on the eastern segment of Tozai Line.', FALSE),
--
--    -- Maintenance scenarios
--    ('maintenance_karasuma_segment', 'Karasuma Segment Maintenance', 'maintenance', 'Simulate planned maintenance on a segment of Karasuma Line with reduced service.', FALSE),
--    ('maintenance_tozai_segment', 'Tozai Segment Maintenance', 'maintenance', 'Simulate planned maintenance on a segment of Tozai Line with reduced service.', FALSE),
--    ('maintenance_karasuma_night', 'Karasuma Night Maintenance', 'maintenance', 'Simulate late-night maintenance operations on Karasuma Line.', FALSE),
--    ('maintenance_tozai_night', 'Tozai Night Maintenance', 'maintenance', 'Simulate late-night maintenance operations on Tozai Line.', FALSE),
--    ('maintenance_karasuma_oike_station', 'Karasuma Oike Station Maintenance', 'maintenance', 'Simulate planned maintenance impacting station movement and transfer capacity at Karasuma Oike.', FALSE),
--
--    -- Closure scenarios
--    ('closure_karasuma_oike_interchange', 'Karasuma Oike Interchange Closure', 'closure', 'Simulate temporary closure of interchange transfer flows at Karasuma Oike.', FALSE),
--    ('closure_karasuma_line_partial', 'Karasuma Line Partial Closure', 'closure', 'Simulate partial closure of Karasuma Line between selected stations.', FALSE),
--    ('closure_tozai_line_partial', 'Tozai Line Partial Closure', 'closure', 'Simulate partial closure of Tozai Line between selected stations.', FALSE),
--    ('closure_single_station_karasuma', 'Karasuma Single Station Closure', 'closure', 'Simulate closure of a single station on Karasuma Line while surrounding segments remain operational.', FALSE),
--    ('closure_single_station_tozai', 'Tozai Single Station Closure', 'closure', 'Simulate closure of a single station on Tozai Line while surrounding segments remain operational.', FALSE),
--    ('closure_karasuma_full_line', 'Karasuma Full Line Closure', 'closure', 'Simulate complete suspension of Karasuma Line service.', FALSE),
--    ('closure_tozai_full_line', 'Tozai Full Line Closure', 'closure', 'Simulate complete suspension of Tozai Line service.', FALSE),
--
--    -- Mixed scenarios
--    ('mixed_city_event_disruption', 'City Event Mixed Disruption', 'mixed', 'Simulate combined delays, transfer congestion, and partial closures caused by a major city event.', FALSE),
--    ('mixed_severe_weather', 'Severe Weather Mixed Scenario', 'mixed', 'Simulate weather-related delays, selective station restrictions, and degraded routing availability.', FALSE),
--    ('mixed_emergency_response', 'Emergency Response Scenario', 'mixed', 'Simulate an emergency response case with closures, rerouting, and cascading delays.', FALSE),
--    ('mixed_transfer_congestion', 'Transfer Congestion Scenario', 'mixed', 'Simulate severe transfer congestion with increased transfer times and moderate line delays.', FALSE),
--    ('mixed_peak_hour_incident', 'Peak Hour Incident Scenario', 'mixed', 'Simulate a peak-hour incident that causes both station restrictions and multi-segment delays.', FALSE),
--    ('mixed_multi_line_disruption', 'Multi Line Disruption Scenario', 'mixed', 'Simulate simultaneous disruptions across both Karasuma and Tozai lines.', FALSE);


-- =====================================================================
-- FULL SYNTHETIC TRIPS + TIMETABLE FOR ALL SERVICES AND 4 DIRECTIONS
-- =====================================================================

--WITH
---- ---------------------------------------------------------------------
---- 1) Departure templates for each service bucket
----    Bạn có thể thay các mốc này bằng dữ liệu scrape thật sau.
---- ---------------------------------------------------------------------
--service_departures(service_id, dep_time) AS (
--    VALUES
--        -- weekday
--        ('weekday_service', TIME '05:30'),
--        ('weekday_service', TIME '06:00'),
--        ('weekday_service', TIME '06:30'),
--        ('weekday_service', TIME '07:00'),
--        ('weekday_service', TIME '07:30'),
--        ('weekday_service', TIME '08:00'),
--        ('weekday_service', TIME '08:30'),
--        ('weekday_service', TIME '09:00'),
--        ('weekday_service', TIME '10:00'),
--        ('weekday_service', TIME '11:00'),
--        ('weekday_service', TIME '12:00'),
--        ('weekday_service', TIME '13:00'),
--        ('weekday_service', TIME '14:00'),
--        ('weekday_service', TIME '15:00'),
--        ('weekday_service', TIME '16:00'),
--        ('weekday_service', TIME '17:00'),
--        ('weekday_service', TIME '18:00'),
--        ('weekday_service', TIME '19:00'),
--        ('weekday_service', TIME '20:00'),
--        ('weekday_service', TIME '21:00'),
--        ('weekday_service', TIME '22:00'),
--
--        -- saturday
--        ('saturday_service', TIME '05:45'),
--        ('saturday_service', TIME '06:30'),
--        ('saturday_service', TIME '07:15'),
--        ('saturday_service', TIME '08:00'),
--        ('saturday_service', TIME '09:00'),
--        ('saturday_service', TIME '10:00'),
--        ('saturday_service', TIME '11:00'),
--        ('saturday_service', TIME '12:00'),
--        ('saturday_service', TIME '13:00'),
--        ('saturday_service', TIME '14:00'),
--        ('saturday_service', TIME '15:00'),
--        ('saturday_service', TIME '16:00'),
--        ('saturday_service', TIME '17:00'),
--        ('saturday_service', TIME '18:00'),
--        ('saturday_service', TIME '19:00'),
--        ('saturday_service', TIME '20:00'),
--        ('saturday_service', TIME '21:00'),
--        ('saturday_service', TIME '22:00'),
--
--        -- sunday
--        ('sunday_service', TIME '06:00'),
--        ('sunday_service', TIME '07:00'),
--        ('sunday_service', TIME '08:00'),
--        ('sunday_service', TIME '09:00'),
--        ('sunday_service', TIME '10:00'),
--        ('sunday_service', TIME '11:00'),
--        ('sunday_service', TIME '12:00'),
--        ('sunday_service', TIME '13:00'),
--        ('sunday_service', TIME '14:00'),
--        ('sunday_service', TIME '15:00'),
--        ('sunday_service', TIME '16:00'),
--        ('sunday_service', TIME '17:00'),
--        ('sunday_service', TIME '18:00'),
--        ('sunday_service', TIME '19:00'),
--        ('sunday_service', TIME '20:00'),
--        ('sunday_service', TIME '21:00'),
--
--        -- holiday
--        ('holiday_service', TIME '06:00'),
--        ('holiday_service', TIME '07:00'),
--        ('holiday_service', TIME '08:00'),
--        ('holiday_service', TIME '09:00'),
--        ('holiday_service', TIME '10:00'),
--        ('holiday_service', TIME '11:00'),
--        ('holiday_service', TIME '12:00'),
--        ('holiday_service', TIME '13:00'),
--        ('holiday_service', TIME '14:00'),
--        ('holiday_service', TIME '15:00'),
--        ('holiday_service', TIME '16:00'),
--        ('holiday_service', TIME '17:00'),
--        ('holiday_service', TIME '18:00'),
--        ('holiday_service', TIME '19:00'),
--        ('holiday_service', TIME '20:00'),
--        ('holiday_service', TIME '21:00'),
--
--        -- special
--        ('special_service', TIME '07:00'),
--        ('special_service', TIME '09:00'),
--        ('special_service', TIME '11:00'),
--        ('special_service', TIME '13:00'),
--        ('special_service', TIME '15:00'),
--        ('special_service', TIME '17:00'),
--        ('special_service', TIME '19:00')
--),
--
---- ---------------------------------------------------------------------
---- 2) 4 route patterns
---- ---------------------------------------------------------------------
--route_defs AS (
--    SELECT * FROM (
--        VALUES
--            ('karasuma', 1::smallint, 'K01'::text, 'K15'::text, 'Takeda'::text),
--            ('karasuma', 0::smallint, 'K15'::text, 'K01'::text, 'Kokusaikaikan'::text),
--            ('tozai',    1::smallint, 'T01'::text, 'T17'::text, 'Uzumasa Tenjingawa'::text),
--            ('tozai',    0::smallint, 'T17'::text, 'T01'::text, 'Rokujizo'::text)
--    ) AS x(line_id, direction_id, origin_station_id, destination_station_id, headsign)
--),
--
---- ---------------------------------------------------------------------
---- 3) Generate trip rows
---- ---------------------------------------------------------------------
--trip_rows AS (
--    SELECT
--        r.line_id || '_' ||
--        lower(r.origin_station_id) || '_' ||
--        lower(r.destination_station_id) || '_' ||
--        s.service_id || '_' ||
--        replace(s.dep_time::text, ':', '') AS trip_id,
--        r.line_id,
--        s.service_id,
--        r.direction_id,
--        CASE
--            WHEN r.direction_id = 1 THEN 'increasing_order'
--            ELSE 'decreasing_order'
--        END AS direction_name,
--        r.origin_station_id,
--        r.destination_station_id,
--        r.headsign,
--        TRUE AS is_active,
--        s.dep_time
--    FROM route_defs r
--    CROSS JOIN service_departures s
--),
--
---- ---------------------------------------------------------------------
---- 4) Stop patterns with cumulative offsets derived from your edges
---- ---------------------------------------------------------------------
--stop_pattern AS (
--    SELECT * FROM (
--        VALUES
--        -- Karasuma forward K01 -> K15
--        ('karasuma', 1::smallint,  1, 'K01'::text,  1,  0),
--        ('karasuma', 1::smallint,  2, 'K02'::text,  2,  2),
--        ('karasuma', 1::smallint,  3, 'K03'::text,  3,  4),
--        ('karasuma', 1::smallint,  4, 'K04'::text,  4,  6),
--        ('karasuma', 1::smallint,  5, 'K05'::text,  5,  8),
--        ('karasuma', 1::smallint,  6, 'K06'::text,  6, 10),
--        ('karasuma', 1::smallint,  7, 'K07'::text,  7, 12),
--        ('karasuma', 1::smallint,  8, 'K08'::text,  8, 14),
--        ('karasuma', 1::smallint,  9, 'K09'::text,  9, 16),
--        ('karasuma', 1::smallint, 10, 'K10'::text, 10, 18),
--        ('karasuma', 1::smallint, 11, 'K11'::text, 11, 20),
--        ('karasuma', 1::smallint, 12, 'K12'::text, 12, 21),
--        ('karasuma', 1::smallint, 13, 'K13'::text, 13, 23),
--        ('karasuma', 1::smallint, 14, 'K14'::text, 14, 25),
--        ('karasuma', 1::smallint, 15, 'K15'::text, 15, 26),
--
--        -- Karasuma backward K15 -> K01
--        ('karasuma', 0::smallint,  1, 'K15'::text, 15,  0),
--        ('karasuma', 0::smallint,  2, 'K14'::text, 14,  1),
--        ('karasuma', 0::smallint,  3, 'K13'::text, 13,  3),
--        ('karasuma', 0::smallint,  4, 'K12'::text, 12,  5),
--        ('karasuma', 0::smallint,  5, 'K11'::text, 11,  6),
--        ('karasuma', 0::smallint,  6, 'K10'::text, 10,  8),
--        ('karasuma', 0::smallint,  7, 'K09'::text,  9, 10),
--        ('karasuma', 0::smallint,  8, 'K08'::text,  8, 12),
--        ('karasuma', 0::smallint,  9, 'K07'::text,  7, 14),
--        ('karasuma', 0::smallint, 10, 'K06'::text,  6, 16),
--        ('karasuma', 0::smallint, 11, 'K05'::text,  5, 18),
--        ('karasuma', 0::smallint, 12, 'K04'::text,  4, 20),
--        ('karasuma', 0::smallint, 13, 'K03'::text,  3, 22),
--        ('karasuma', 0::smallint, 14, 'K02'::text,  2, 24),
--        ('karasuma', 0::smallint, 15, 'K01'::text,  1, 26),
--
--        -- Tozai forward T01 -> T17
--        ('tozai', 1::smallint,  1, 'T01'::text,  1,  0),
--        ('tozai', 1::smallint,  2, 'T02'::text,  2,  3),
--        ('tozai', 1::smallint,  3, 'T03'::text,  3,  5),
--        ('tozai', 1::smallint,  4, 'T04'::text,  4,  7),
--        ('tozai', 1::smallint,  5, 'T05'::text,  5,  9),
--        ('tozai', 1::smallint,  6, 'T06'::text,  6, 11),
--        ('tozai', 1::smallint,  7, 'T07'::text,  7, 13),
--        ('tozai', 1::smallint,  8, 'T08'::text,  8, 16),
--        ('tozai', 1::smallint,  9, 'T09'::text,  9, 19),
--        ('tozai', 1::smallint, 10, 'T10'::text, 10, 21),
--        ('tozai', 1::smallint, 11, 'T11'::text, 11, 23),
--        ('tozai', 1::smallint, 12, 'T12'::text, 12, 24),
--        ('tozai', 1::smallint, 13, 'T13'::text, 13, 26),
--        ('tozai', 1::smallint, 14, 'T14'::text, 14, 28),
--        ('tozai', 1::smallint, 15, 'T15'::text, 15, 30),
--        ('tozai', 1::smallint, 16, 'T16'::text, 16, 32),
--        ('tozai', 1::smallint, 17, 'T17'::text, 17, 34),
--
--        -- Tozai backward T17 -> T01
--        ('tozai', 0::smallint,  1, 'T17'::text, 17,  0),
--        ('tozai', 0::smallint,  2, 'T16'::text, 16,  2),
--        ('tozai', 0::smallint,  3, 'T15'::text, 15,  4),
--        ('tozai', 0::smallint,  4, 'T14'::text, 14,  6),
--        ('tozai', 0::smallint,  5, 'T13'::text, 13,  8),
--        ('tozai', 0::smallint,  6, 'T12'::text, 12, 10),
--        ('tozai', 0::smallint,  7, 'T11'::text, 11, 11),
--        ('tozai', 0::smallint,  8, 'T10'::text, 10, 13),
--        ('tozai', 0::smallint,  9, 'T09'::text,  9, 15),
--        ('tozai', 0::smallint, 10, 'T08'::text,  8, 18),
--        ('tozai', 0::smallint, 11, 'T07'::text,  7, 21),
--        ('tozai', 0::smallint, 12, 'T06'::text,  6, 23),
--        ('tozai', 0::smallint, 13, 'T05'::text,  5, 25),
--        ('tozai', 0::smallint, 14, 'T04'::text,  4, 27),
--        ('tozai', 0::smallint, 15, 'T03'::text,  3, 29),
--        ('tozai', 0::smallint, 16, 'T02'::text,  2, 31),
--        ('tozai', 0::smallint, 17, 'T01'::text,  1, 34)
--    ) AS x(line_id, direction_id, stop_sequence, station_id, line_station_order, offset_min)
--),
--
---- ---------------------------------------------------------------------
---- 5) Insert trips
---- ---------------------------------------------------------------------
--ins_trips AS (
--    INSERT INTO trips (
--        trip_id,
--        line_id,
--        service_id,
--        direction_id,
--        direction_name,
--        origin_station_id,
--        destination_station_id,
--        headsign,
--        is_active
--    )
--    SELECT
--        trip_id,
--        line_id,
--        service_id,
--        direction_id,
--        direction_name,
--        origin_station_id,
--        destination_station_id,
--        headsign,
--        is_active
--    FROM trip_rows
--    ON CONFLICT (trip_id) DO NOTHING
--    RETURNING trip_id
--)
--
---- ---------------------------------------------------------------------
---- 6) Insert timetable
---- ---------------------------------------------------------------------
--INSERT INTO timetable (
--    trip_id,
--    line_id,
--    station_id,
--    line_station_order,
--    stop_sequence,
--    scheduled_arrival_time,
--    scheduled_arrival_day_offset,
--    scheduled_departure_time,
--    scheduled_departure_day_offset,
--    pickup_allowed,
--    dropoff_allowed
--)
--SELECT
--    t.trip_id,
--    t.line_id,
--    s.station_id,
--    s.line_station_order,
--    s.stop_sequence,
--    (t.dep_time + make_interval(mins => s.offset_min))::time AS scheduled_arrival_time,
--    0 AS scheduled_arrival_day_offset,
--    (t.dep_time + make_interval(mins => s.offset_min))::time AS scheduled_departure_time,
--    0 AS scheduled_departure_day_offset,
--    TRUE AS pickup_allowed,
--    TRUE AS dropoff_allowed
--FROM trip_rows t
--JOIN stop_pattern s
--  ON s.line_id = t.line_id
-- AND s.direction_id = t.direction_id
--ON CONFLICT (trip_id, stop_sequence) DO NOTHING;

