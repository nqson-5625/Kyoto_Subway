-- ===================
-- 1) Danh mục tuyến
-- ===================

INSERT INTO lines (line_id, line_code, line_name, operator_name, color_hex, is_active) 
VALUES
    ('karasuma', 'K', 'Karasuma Line', 'Kyoto Municipal Transportation Bureau', '#4CAF50', TRUE),
    ('tozai',    'T', 'Tozai Line',    'Kyoto Municipal Transportation Bureau', '#E60012', TRUE);


-- =================
-- 2) Danh mục ga
-- =================

INSERT INTO stations (station_id, station_name, geom, is_transfer_station, is_active) 
VALUES
    ('K01', 'Kokusaikaikan', 	ST_SetSRID(ST_MakePoint(135.785171, 35.063612), 4326), FALSE, TRUE),
    ('K02', 'Matsugasaki', 		ST_SetSRID(ST_MakePoint(135.775158, 35.051656), 4326), FALSE, TRUE),
    ('K03', 'Kitayama', 		ST_SetSRID(ST_MakePoint(135.765209, 35.051243), 4326), FALSE, TRUE),
    ('K04', 'Kitaoji', 			ST_SetSRID(ST_MakePoint(135.758709, 35.044573), 4326), FALSE, TRUE),
    ('K05', 'Kuramaguchi', 		ST_SetSRID(ST_MakePoint(135.759303, 35.037182), 4326), FALSE, TRUE),
    ('K06', 'Imadegawa', 		ST_SetSRID(ST_MakePoint(135.759369, 35.029394), 4326), FALSE, TRUE),
    ('K07', 'Marutamachi', 		ST_SetSRID(ST_MakePoint(135.759553, 35.016288), 4326), FALSE, TRUE),
    ('K08', 'Karasuma Oike', 	ST_SetSRID(ST_MakePoint(135.759646, 35.010824), 4326), TRUE,  TRUE),
    ('K09', 'Shijo', 			ST_SetSRID(ST_MakePoint(135.759653, 35.002469), 4326), FALSE, TRUE),
    ('K10', 'Gojo', 			ST_SetSRID(ST_MakePoint(135.759714, 34.994940), 4326), FALSE, TRUE),
    ('K11', 'Kyoto', 			ST_SetSRID(ST_MakePoint(135.758505, 34.987082), 4326), FALSE, TRUE),
    ('K12', 'Kujo', 			ST_SetSRID(ST_MakePoint(135.759723, 34.979173), 4326), FALSE, TRUE),
    ('K13', 'Jujo', 			ST_SetSRID(ST_MakePoint(135.752433, 34.973728), 4326), FALSE, TRUE),
    ('K14', 'Kuinabashi', 		ST_SetSRID(ST_MakePoint(135.757046, 34.962281), 4326), FALSE, TRUE),
    ('K15', 'Takeda', 			ST_SetSRID(ST_MakePoint(135.756489, 34.957164), 4326), FALSE, TRUE),
    
    ('T01', 'Rokujizo', 		ST_SetSRID(ST_MakePoint(135.793342, 34.931953), 4326), FALSE, TRUE),
    ('T02', 'Ishida', 			ST_SetSRID(ST_MakePoint(135.804006, 34.940626), 4326), FALSE, TRUE),
    ('T03', 'Daigo', 			ST_SetSRID(ST_MakePoint(135.810651, 34.950669), 4326), FALSE, TRUE),
    ('T04', 'Ono', 				ST_SetSRID(ST_MakePoint(135.812689, 34.961145), 4326), FALSE, TRUE),
    ('T05', 'Nagitsuji', 		ST_SetSRID(ST_MakePoint(135.814901, 34.972709), 4326), FALSE, TRUE),
    ('T06', 'Higashino', 		ST_SetSRID(ST_MakePoint(135.816675, 34.981957), 4326), FALSE, TRUE),
    ('T07', 'Yamashina', 		ST_SetSRID(ST_MakePoint(135.817237, 34.992636), 4326), FALSE, TRUE),
    ('T08', 'Misasagi', 		ST_SetSRID(ST_MakePoint(135.801768, 34.996060), 4326), FALSE, TRUE),
    ('T09', 'Keage', 			ST_SetSRID(ST_MakePoint(135.790557, 35.007597), 4326), FALSE, TRUE),
    ('T10', 'Higashiyama', 		ST_SetSRID(ST_MakePoint(135.779778, 35.009434), 4326), FALSE, TRUE),
    ('T11', 'Sanjo Keihan', 	ST_SetSRID(ST_MakePoint(135.772605, 35.008151), 4326), FALSE, TRUE),
    ('T12', 'Kyoto Shiyakusho-mae', ST_SetSRID(ST_MakePoint(135.768870, 35.010899), 4326), FALSE, TRUE),
    ('T13', 'Karasuma Oike', 	ST_SetSRID(ST_MakePoint(135.759646, 35.010824), 4326), TRUE,  TRUE),
    ('T14', 'Nijojo-mae', 		ST_SetSRID(ST_MakePoint(135.750281, 35.011890), 4326), FALSE, TRUE),
    ('T15', 'Nijo', 			ST_SetSRID(ST_MakePoint(135.741730, 35.011028), 4326), FALSE, TRUE),
    ('T16', 'Nishioji Oike', 	ST_SetSRID(ST_MakePoint(135.730634, 35.010945), 4326), FALSE, TRUE),
    ('T17', 'Uzumasa Tenjingawa', ST_SetSRID(ST_MakePoint(135.715634, 35.010813), 4326), FALSE, TRUE);
    

-- =========================
-- 3) Quan hệ ga - tuyến
-- =========================
    
INSERT INTO station_lines ( line_id, station_order, station_id, is_terminal) 
VALUES
    ('karasuma', 1,  'K01', TRUE),
    ('karasuma', 2,  'K02', FALSE),
    ('karasuma', 3,  'K03', FALSE),
    ('karasuma', 4,  'K04', FALSE),
    ('karasuma', 5,  'K05', FALSE),
    ('karasuma', 6,  'K06', FALSE),
    ('karasuma', 7,  'K07', FALSE),
    ('karasuma', 8,  'K08', FALSE),
    ('karasuma', 9,  'K09', FALSE),
    ('karasuma', 10, 'K10', FALSE),
    ('karasuma', 11, 'K11', FALSE),
    ('karasuma', 12, 'K12', FALSE),
    ('karasuma', 13, 'K13', FALSE),
    ('karasuma', 14, 'K14', FALSE),
    ('karasuma', 15, 'K15', TRUE),

    ('tozai', 1,  'T01', TRUE),
    ('tozai', 2,  'T02', FALSE),
    ('tozai', 3,  'T03', FALSE),
    ('tozai', 4,  'T04', FALSE),
    ('tozai', 5,  'T05', FALSE),
    ('tozai', 6,  'T06', FALSE),
    ('tozai', 7,  'T07', FALSE),
    ('tozai', 8,  'T08', FALSE),
    ('tozai', 9,  'T09', FALSE),
    ('tozai', 10, 'T10', FALSE),
    ('tozai', 11, 'T11', FALSE),
    ('tozai', 12, 'T12', FALSE),
    ('tozai', 13, 'T13', FALSE),
    ('tozai', 14, 'T14', FALSE),
    ('tozai', 15, 'T15', FALSE),
    ('tozai', 16, 'T16', FALSE),
    ('tozai', 17, 'T17', TRUE);

    
-- ====================================
-- 4) Cạnh cơ sở của đồ thị subway 
-- ====================================

INSERT INTO edges (line_id, from_station_id, from_station_order, to_station_id, to_station_order, travel_time_min, distance_km, geom, is_active)
SELECT
    v.line_id,
    v.from_station_id,
    v.from_station_order,
    v.to_station_id,
    v.to_station_order,
    v.travel_time_min,
    ROUND((ST_Length(ST_MakeLine(sf.geom, st.geom)::geography) / 1000.0)::numeric, 3) AS distance_km,
    ST_MakeLine(sf.geom, st.geom) AS geom,
    TRUE AS is_active
FROM (
    VALUES
        -- Karasuma Line: forward
        ('karasuma', 'K01',  1, 'K02',  2, 2),
        ('karasuma', 'K02',  2, 'K03',  3, 2),
        ('karasuma', 'K03',  3, 'K04',  4, 2),
        ('karasuma', 'K04',  4, 'K05',  5, 2),
        ('karasuma', 'K05',  5, 'K06',  6, 2),
        ('karasuma', 'K06',  6, 'K07',  7, 2),
        ('karasuma', 'K07',  7, 'K08',  8, 2),
        ('karasuma', 'K08',  8, 'K09',  9, 2),
        ('karasuma', 'K09',  9, 'K10', 10, 2),
        ('karasuma', 'K10', 10, 'K11', 11, 2),
        ('karasuma', 'K11', 11, 'K12', 12, 1),
        ('karasuma', 'K12', 12, 'K13', 13, 2),
        ('karasuma', 'K13', 13, 'K14', 14, 2),
        ('karasuma', 'K14', 14, 'K15', 15, 1),

        -- Karasuma Line: backward
        ('karasuma', 'K02',  2, 'K01',  1, 2),
        ('karasuma', 'K03',  3, 'K02',  2, 2),
        ('karasuma', 'K04',  4, 'K03',  3, 2),
        ('karasuma', 'K05',  5, 'K04',  4, 2),
        ('karasuma', 'K06',  6, 'K05',  5, 2),
        ('karasuma', 'K07',  7, 'K06',  6, 2),
        ('karasuma', 'K08',  8, 'K07',  7, 2),
        ('karasuma', 'K09',  9, 'K08',  8, 2),
        ('karasuma', 'K10', 10, 'K09',  9, 2),
        ('karasuma', 'K11', 11, 'K10', 10, 2),
        ('karasuma', 'K12', 12, 'K11', 11, 1),
        ('karasuma', 'K13', 13, 'K12', 12, 2),
        ('karasuma', 'K14', 14, 'K13', 13, 2),
        ('karasuma', 'K15', 15, 'K14', 14, 1),

        -- Tozai Line: forward
        ('tozai', 'T01',  1, 'T02',  2, 3),
        ('tozai', 'T02',  2, 'T03',  3, 2),
        ('tozai', 'T03',  3, 'T04',  4, 2),
        ('tozai', 'T04',  4, 'T05',  5, 2),
        ('tozai', 'T05',  5, 'T06',  6, 2),
        ('tozai', 'T06',  6, 'T07',  7, 2),
        ('tozai', 'T07',  7, 'T08',  8, 3),
        ('tozai', 'T08',  8, 'T09',  9, 3),
        ('tozai', 'T09',  9, 'T10', 10, 2),
        ('tozai', 'T10', 10, 'T11', 11, 2),
        ('tozai', 'T11', 11, 'T12', 12, 1),
        ('tozai', 'T12', 12, 'T13', 13, 2),
        ('tozai', 'T13', 13, 'T14', 14, 2),
        ('tozai', 'T14', 14, 'T15', 15, 2),
        ('tozai', 'T15', 15, 'T16', 16, 2),
        ('tozai', 'T16', 16, 'T17', 17, 2),

        -- Tozai Line: backward
        ('tozai', 'T02',  2, 'T01',  1, 3),
        ('tozai', 'T03',  3, 'T02',  2, 2),
        ('tozai', 'T04',  4, 'T03',  3, 2),
        ('tozai', 'T05',  5, 'T04',  4, 2),
        ('tozai', 'T06',  6, 'T05',  5, 2),
        ('tozai', 'T07',  7, 'T06',  6, 2),
        ('tozai', 'T08',  8, 'T07',  7, 3),
        ('tozai', 'T09',  9, 'T08',  8, 3),
        ('tozai', 'T10', 10, 'T09',  9, 2),
        ('tozai', 'T11', 11, 'T10', 10, 2),
        ('tozai', 'T12', 12, 'T11', 11, 1),
        ('tozai', 'T13', 13, 'T12', 12, 2),
        ('tozai', 'T14', 14, 'T13', 13, 2),
        ('tozai', 'T15', 15, 'T14', 14, 2),
        ('tozai', 'T16', 16, 'T15', 15, 2),
        ('tozai', 'T17', 17, 'T16', 16, 2)
) AS v(line_id, from_station_id, from_station_order, to_station_id, to_station_order, travel_time_min)
JOIN stations sf
  ON sf.station_id = v.from_station_id
JOIN stations st
  ON st.station_id = v.to_station_id;

-- source: https://www2.city.kyoto.lg.jp/kotsu/webguide/en/tika/travel_time.html   
    
        
-- =======================================
-- 5) Quan hệ trung chuyển giữa các ga
-- =======================================
        
INSERT INTO transfers (from_station_id, to_station_id, transfer_time_min, is_active, transfer_type, note) 
VALUES
    ('K08', 'T13', 4, TRUE, 'same_station_interchange', 'Transfer between Karasuma Line and Tozai Line at Karasuma Oike'),
    ('T13', 'K08', 4, TRUE, 'same_station_interchange', 'Transfer between Tozai Line and Karasuma Line at Karasuma Oike');


-- =====================================
-- 6) Lịch cơ sở theo thứ trong tuần
-- =====================================

INSERT INTO service_calendar (service_id, service_name, service_type, monday, tuesday, wednesday, thursday, friday, saturday, sunday, start_date, end_date) 
VALUES
    ('weekday_service', 'Weekday Service', 'weekday', TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, DATE '2025-01-01', DATE '2030-12-31'),
    ('saturday_service', 'Saturday Service', 'saturday', FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, DATE '2025-01-01', DATE '2030-12-31'),
    ('sunday_service', 'Sunday Service', 'sunday', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, DATE '2025-01-01', DATE '2030-12-31'),
    ('holiday_service', 'Holiday Service', 'holiday', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, DATE '2025-01-01', DATE '2030-12-31'),
    ('special_service', 'Special Service', 'special', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, DATE '2025-01-01', DATE '2030-12-31');   


-- ===============================
-- 7) Danh sách ngày lễ thực tế
-- ===============================

INSERT INTO holiday_dates (holiday_date, holiday_name, is_public_holiday, note) 
VALUES
    ('2026-01-01', 'New Year''s Day', 			TRUE, NULL),
    ('2026-01-12', 'Coming of Age Day', 		TRUE, NULL),
    ('2026-02-11', 'National Foundation Day', 	TRUE, NULL),
    ('2026-02-23', 'Emperor''s Birthday', 		TRUE, NULL),
    ('2026-03-20', 'Vernal Equinox Day', 		TRUE, NULL),
    ('2026-04-29', 'Showa Day', 				TRUE, NULL),
    ('2026-05-03', 'Constitution Memorial Day', TRUE, NULL),
    ('2026-05-04', 'Greenery Day', 				TRUE, NULL),
    ('2026-05-05', 'Children''s Day', 			TRUE, NULL),
    ('2026-05-06', 'Holiday', 					TRUE, 'Substitute holiday'),
    ('2026-07-20', 'Marine Day', 				TRUE, NULL),
    ('2026-08-11', 'Mountain Day', 				TRUE, NULL),
    ('2026-09-21', 'Respect for the Aged Day', 	TRUE, NULL),
    ('2026-09-22', 'Holiday', 					TRUE, 'Citizen''s holiday'),
    ('2026-09-23', 'Autumnal Equinox Day', 		TRUE, NULL),
    ('2026-10-12', 'Sports Day', 				TRUE, NULL),
    ('2026-11-03', 'Culture Day', 				TRUE, NULL),
    ('2026-11-23', 'Labor Thanksgiving Day', 	TRUE, NULL),

    ('2027-01-01', 'New Year''s Day', 			TRUE, NULL),
    ('2027-01-11', 'Coming of Age Day', 		TRUE, NULL),
    ('2027-02-11', 'National Foundation Day', 	TRUE, NULL),
    ('2027-02-23', 'Emperor''s Birthday', 		TRUE, NULL),
    ('2027-03-21', 'Vernal Equinox Day', 		TRUE, NULL),
    ('2027-03-22', 'Holiday', 					TRUE, 'Substitute holiday'),
    ('2027-04-29', 'Showa Day', 				TRUE, NULL),
    ('2027-05-03', 'Constitution Memorial Day', TRUE, NULL),
    ('2027-05-04', 'Greenery Day', 				TRUE, NULL),
    ('2027-05-05', 'Children''s Day', 			TRUE, NULL),
    ('2027-07-19', 'Marine Day', 				TRUE, NULL),
    ('2027-08-11', 'Mountain Day', 				TRUE, NULL),
    ('2027-09-20', 'Respect for the Aged Day', 	TRUE, NULL),
    ('2027-09-23', 'Autumnal Equinox Day', 		TRUE, NULL),
    ('2027-10-11', 'Sports Day', 				TRUE, NULL),
    ('2027-11-03', 'Culture Day', 				TRUE, NULL),
    ('2027-11-23', 'Labor Thanksgiving Day', 	TRUE, NULL);
    
-- Source: https://www8.cao.go.jp/chosei/shukujitsu/gaiyou.html
    
 
-- =========================================
-- 8) Ngoại lệ lịch chạy theo ngày cụ thể
-- =========================================
    
INSERT INTO service_exceptions (service_id, service_date, exception_type, exception_category, reason, note) 
VALUES
    ('weekday_service', '2026-01-01', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2026-01-01', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-01-12', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2026-01-12', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-02-11', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2026-02-11', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-02-23', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2026-02-23', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-03-20', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2026-03-20', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-04-29', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2026-04-29', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('sunday_service', '2026-05-03', 'removed', 'holiday', 'public_holiday', 'Switch from Sunday service to holiday service'),
    ('holiday_service', '2026-05-03', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-05-04', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2026-05-04', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-05-05', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2026-05-05', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-05-06', 'removed', 'holiday', 'public_holiday', 'Substitute holiday: switch from weekday service to holiday service'),
    ('holiday_service', '2026-05-06', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('sunday_service', '2026-07-20', 'removed', 'holiday', 'public_holiday', 'Switch from Sunday service to holiday service'),
    ('holiday_service', '2026-07-20', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-08-11', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2026-08-11', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-09-21', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2026-09-21', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-09-22', 'removed', 'holiday', 'public_holiday', 'Citizen''s holiday: switch from weekday service to holiday service'),
    ('holiday_service', '2026-09-22', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-09-23', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2026-09-23', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('sunday_service', '2026-10-12', 'removed', 'holiday', 'public_holiday', 'Switch from Sunday service to holiday service'),
    ('holiday_service', '2026-10-12', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-11-03', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2026-11-03', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2026-11-23', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2026-11-23', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),

    ('weekday_service', '2027-01-01', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-01-01', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-01-11', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-01-11', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-02-11', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-02-11', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-02-23', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-02-23', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('sunday_service', '2027-03-21', 'removed', 'holiday', 'public_holiday', 'Switch from Sunday service to holiday service'),
    ('holiday_service', '2027-03-21', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-03-22', 'removed', 'holiday', 'public_holiday', 'Substitute holiday: switch from weekday service to holiday service'),
    ('holiday_service', '2027-03-22', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-04-29', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-04-29', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-05-03', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-05-03', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-05-04', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-05-04', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-05-05', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-05-05', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-07-19', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-07-19', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-08-11', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-08-11', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-09-20', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-09-20', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-09-23', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-09-23', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-10-11', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-10-11', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-11-03', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-11-03', 'added', 'holiday', 'public_holiday', 'Enable holiday service'),
    ('weekday_service', '2027-11-23', 'removed', 'holiday', 'public_holiday', 'Switch from weekday service to holiday service'),
    ('holiday_service', '2027-11-23', 'added', 'holiday', 'public_holiday', 'Enable holiday service');


-- ===============================================
-- 9) Chuyến tàu
-- 10) Giờ biểu theo từng điểm dừng của chuyến
-- ===============================================
    
WITH
-- ---------------------------------------------------------------------
-- 1) Departure templates for each service bucket
--    Bạn có thể thay các mốc này bằng dữ liệu scrape thật sau.
-- ---------------------------------------------------------------------
service_departures(service_id, dep_time) AS (
    VALUES
        -- weekday
        ('weekday_service', TIME '05:30'),
        ('weekday_service', TIME '06:00'),
        ('weekday_service', TIME '06:30'),
        ('weekday_service', TIME '07:00'),
        ('weekday_service', TIME '07:30'),
        ('weekday_service', TIME '08:00'),
        ('weekday_service', TIME '08:30'),
        ('weekday_service', TIME '09:00'),
        ('weekday_service', TIME '10:00'),
        ('weekday_service', TIME '11:00'),
        ('weekday_service', TIME '12:00'),
        ('weekday_service', TIME '13:00'),
        ('weekday_service', TIME '14:00'),
        ('weekday_service', TIME '15:00'),
        ('weekday_service', TIME '16:00'),
        ('weekday_service', TIME '17:00'),
        ('weekday_service', TIME '18:00'),
        ('weekday_service', TIME '19:00'),
        ('weekday_service', TIME '20:00'),
        ('weekday_service', TIME '21:00'),
        ('weekday_service', TIME '22:00'),

        -- saturday
        ('saturday_service', TIME '05:45'),
        ('saturday_service', TIME '06:30'),
        ('saturday_service', TIME '07:15'),
        ('saturday_service', TIME '08:00'),
        ('saturday_service', TIME '09:00'),
        ('saturday_service', TIME '10:00'),
        ('saturday_service', TIME '11:00'),
        ('saturday_service', TIME '12:00'),
        ('saturday_service', TIME '13:00'),
        ('saturday_service', TIME '14:00'),
        ('saturday_service', TIME '15:00'),
        ('saturday_service', TIME '16:00'),
        ('saturday_service', TIME '17:00'),
        ('saturday_service', TIME '18:00'),
        ('saturday_service', TIME '19:00'),
        ('saturday_service', TIME '20:00'),
        ('saturday_service', TIME '21:00'),
        ('saturday_service', TIME '22:00'),

        -- sunday
        ('sunday_service', TIME '06:00'),
        ('sunday_service', TIME '07:00'),
        ('sunday_service', TIME '08:00'),
        ('sunday_service', TIME '09:00'),
        ('sunday_service', TIME '10:00'),
        ('sunday_service', TIME '11:00'),
        ('sunday_service', TIME '12:00'),
        ('sunday_service', TIME '13:00'),
        ('sunday_service', TIME '14:00'),
        ('sunday_service', TIME '15:00'),
        ('sunday_service', TIME '16:00'),
        ('sunday_service', TIME '17:00'),
        ('sunday_service', TIME '18:00'),
        ('sunday_service', TIME '19:00'),
        ('sunday_service', TIME '20:00'),
        ('sunday_service', TIME '21:00'),

        -- holiday
        ('holiday_service', TIME '06:00'),
        ('holiday_service', TIME '07:00'),
        ('holiday_service', TIME '08:00'),
        ('holiday_service', TIME '09:00'),
        ('holiday_service', TIME '10:00'),
        ('holiday_service', TIME '11:00'),
        ('holiday_service', TIME '12:00'),
        ('holiday_service', TIME '13:00'),
        ('holiday_service', TIME '14:00'),
        ('holiday_service', TIME '15:00'),
        ('holiday_service', TIME '16:00'),
        ('holiday_service', TIME '17:00'),
        ('holiday_service', TIME '18:00'),
        ('holiday_service', TIME '19:00'),
        ('holiday_service', TIME '20:00'),
        ('holiday_service', TIME '21:00'),

        -- special
        ('special_service', TIME '07:00'),
        ('special_service', TIME '09:00'),
        ('special_service', TIME '11:00'),
        ('special_service', TIME '13:00'),
        ('special_service', TIME '15:00'),
        ('special_service', TIME '17:00'),
        ('special_service', TIME '19:00')
),

-- ---------------------------------------------------------------------
-- 2) 4 route patterns
-- ---------------------------------------------------------------------
route_defs AS (
    SELECT * FROM (
        VALUES
            ('karasuma', 1::smallint, 'K01'::text, 'K15'::text, 'Takeda'::text),
            ('karasuma', 0::smallint, 'K15'::text, 'K01'::text, 'Kokusaikaikan'::text),
            ('tozai',    1::smallint, 'T01'::text, 'T17'::text, 'Uzumasa Tenjingawa'::text),
            ('tozai',    0::smallint, 'T17'::text, 'T01'::text, 'Rokujizo'::text)
    ) AS x(line_id, direction_id, origin_station_id, destination_station_id, headsign)
),

-- ---------------------------------------------------------------------
-- 3) Generate trip rows
-- ---------------------------------------------------------------------
trip_rows AS (
    SELECT
        r.line_id || '_' ||
        lower(r.origin_station_id) || '_' ||
        lower(r.destination_station_id) || '_' ||
        s.service_id || '_' ||
        replace(s.dep_time::text, ':', '') AS trip_id,
        r.line_id,
        s.service_id,
        r.direction_id,
        CASE
            WHEN r.direction_id = 1 THEN 'increasing_order'
            ELSE 'decreasing_order'
        END AS direction_name,
        r.origin_station_id,
        r.destination_station_id,
        r.headsign,
        TRUE AS is_active,
        s.dep_time
    FROM route_defs r
    CROSS JOIN service_departures s
),

-- ---------------------------------------------------------------------
-- 4) Stop patterns with cumulative offsets derived from your edges
-- ---------------------------------------------------------------------
stop_pattern AS (
    SELECT * FROM (
        VALUES
        -- Karasuma forward K01 -> K15
        ('karasuma', 1::smallint,  1, 'K01'::text,  1,  0),
        ('karasuma', 1::smallint,  2, 'K02'::text,  2,  2),
        ('karasuma', 1::smallint,  3, 'K03'::text,  3,  4),
        ('karasuma', 1::smallint,  4, 'K04'::text,  4,  6),
        ('karasuma', 1::smallint,  5, 'K05'::text,  5,  8),
        ('karasuma', 1::smallint,  6, 'K06'::text,  6, 10),
        ('karasuma', 1::smallint,  7, 'K07'::text,  7, 12),
        ('karasuma', 1::smallint,  8, 'K08'::text,  8, 14),
        ('karasuma', 1::smallint,  9, 'K09'::text,  9, 16),
        ('karasuma', 1::smallint, 10, 'K10'::text, 10, 18),
        ('karasuma', 1::smallint, 11, 'K11'::text, 11, 20),
        ('karasuma', 1::smallint, 12, 'K12'::text, 12, 21),
        ('karasuma', 1::smallint, 13, 'K13'::text, 13, 23),
        ('karasuma', 1::smallint, 14, 'K14'::text, 14, 25),
        ('karasuma', 1::smallint, 15, 'K15'::text, 15, 26),

        -- Karasuma backward K15 -> K01
        ('karasuma', 0::smallint,  1, 'K15'::text, 15,  0),
        ('karasuma', 0::smallint,  2, 'K14'::text, 14,  1),
        ('karasuma', 0::smallint,  3, 'K13'::text, 13,  3),
        ('karasuma', 0::smallint,  4, 'K12'::text, 12,  5),
        ('karasuma', 0::smallint,  5, 'K11'::text, 11,  6),
        ('karasuma', 0::smallint,  6, 'K10'::text, 10,  8),
        ('karasuma', 0::smallint,  7, 'K09'::text,  9, 10),
        ('karasuma', 0::smallint,  8, 'K08'::text,  8, 12),
        ('karasuma', 0::smallint,  9, 'K07'::text,  7, 14),
        ('karasuma', 0::smallint, 10, 'K06'::text,  6, 16),
        ('karasuma', 0::smallint, 11, 'K05'::text,  5, 18),
        ('karasuma', 0::smallint, 12, 'K04'::text,  4, 20),
        ('karasuma', 0::smallint, 13, 'K03'::text,  3, 22),
        ('karasuma', 0::smallint, 14, 'K02'::text,  2, 24),
        ('karasuma', 0::smallint, 15, 'K01'::text,  1, 26),

        -- Tozai forward T01 -> T17
        ('tozai', 1::smallint,  1, 'T01'::text,  1,  0),
        ('tozai', 1::smallint,  2, 'T02'::text,  2,  3),
        ('tozai', 1::smallint,  3, 'T03'::text,  3,  5),
        ('tozai', 1::smallint,  4, 'T04'::text,  4,  7),
        ('tozai', 1::smallint,  5, 'T05'::text,  5,  9),
        ('tozai', 1::smallint,  6, 'T06'::text,  6, 11),
        ('tozai', 1::smallint,  7, 'T07'::text,  7, 13),
        ('tozai', 1::smallint,  8, 'T08'::text,  8, 16),
        ('tozai', 1::smallint,  9, 'T09'::text,  9, 19),
        ('tozai', 1::smallint, 10, 'T10'::text, 10, 21),
        ('tozai', 1::smallint, 11, 'T11'::text, 11, 23),
        ('tozai', 1::smallint, 12, 'T12'::text, 12, 24),
        ('tozai', 1::smallint, 13, 'T13'::text, 13, 26),
        ('tozai', 1::smallint, 14, 'T14'::text, 14, 28),
        ('tozai', 1::smallint, 15, 'T15'::text, 15, 30),
        ('tozai', 1::smallint, 16, 'T16'::text, 16, 32),
        ('tozai', 1::smallint, 17, 'T17'::text, 17, 34),

        -- Tozai backward T17 -> T01
        ('tozai', 0::smallint,  1, 'T17'::text, 17,  0),
        ('tozai', 0::smallint,  2, 'T16'::text, 16,  2),
        ('tozai', 0::smallint,  3, 'T15'::text, 15,  4),
        ('tozai', 0::smallint,  4, 'T14'::text, 14,  6),
        ('tozai', 0::smallint,  5, 'T13'::text, 13,  8),
        ('tozai', 0::smallint,  6, 'T12'::text, 12, 10),
        ('tozai', 0::smallint,  7, 'T11'::text, 11, 11),
        ('tozai', 0::smallint,  8, 'T10'::text, 10, 13),
        ('tozai', 0::smallint,  9, 'T09'::text,  9, 15),
        ('tozai', 0::smallint, 10, 'T08'::text,  8, 18),
        ('tozai', 0::smallint, 11, 'T07'::text,  7, 21),
        ('tozai', 0::smallint, 12, 'T06'::text,  6, 23),
        ('tozai', 0::smallint, 13, 'T05'::text,  5, 25),
        ('tozai', 0::smallint, 14, 'T04'::text,  4, 27),
        ('tozai', 0::smallint, 15, 'T03'::text,  3, 29),
        ('tozai', 0::smallint, 16, 'T02'::text,  2, 31),
        ('tozai', 0::smallint, 17, 'T01'::text,  1, 34)
    ) AS x(line_id, direction_id, stop_sequence, station_id, line_station_order, offset_min)
),

-- ---------------------------------------------------------------------
-- 5) Insert trips
-- ---------------------------------------------------------------------
ins_trips AS (
    INSERT INTO trips (
        trip_id,
        line_id,
        service_id,
        direction_id,
        direction_name,
        origin_station_id,
        destination_station_id,
        headsign,
        is_active
    )
    SELECT
        trip_id,
        line_id,
        service_id,
        direction_id,
        direction_name,
        origin_station_id,
        destination_station_id,
        headsign,
        is_active
    FROM trip_rows
    ON CONFLICT (trip_id) DO NOTHING
    RETURNING trip_id
)

-- ---------------------------------------------------------------------
-- 6) Insert timetable
-- ---------------------------------------------------------------------
INSERT INTO timetable (
    trip_id,
    line_id,
    station_id,
    line_station_order,
    stop_sequence,
    scheduled_arrival_time,
    scheduled_arrival_day_offset,
    scheduled_departure_time,
    scheduled_departure_day_offset,
    pickup_allowed,
    dropoff_allowed
)
SELECT
    t.trip_id,
    t.line_id,
    s.station_id,
    s.line_station_order,
    s.stop_sequence,
    (t.dep_time + make_interval(mins => s.offset_min))::time AS scheduled_arrival_time,
    0 AS scheduled_arrival_day_offset,
    (t.dep_time + make_interval(mins => s.offset_min))::time AS scheduled_departure_time,
    0 AS scheduled_departure_day_offset,
    TRUE AS pickup_allowed,
    TRUE AS dropoff_allowed
FROM trip_rows t
JOIN stop_pattern s
  ON s.line_id = t.line_id
 AND s.direction_id = t.direction_id
ON CONFLICT (trip_id, stop_sequence) DO NOTHING;

    
    
    
    
-- =========================
-- 11) Tình huống giả lập
-- =========================
    
INSERT INTO scenarios (scenario_id, scenario_name, scenario_type, description, is_active) 
VALUES
    -- Delay scenarios
    ('delay_morning_peak_karasuma', 'Karasuma Morning Peak Delay', 'delay', 'Simulate moderate delays on Karasuma Line during morning peak hours.', FALSE),
    ('delay_evening_peak_tozai', 'Tozai Evening Peak Delay', 'delay', 'Simulate moderate delays on Tozai Line during evening peak hours.', FALSE),
    ('delay_karasuma_full_line', 'Karasuma Full Line Delay', 'delay', 'Simulate end-to-end delays affecting the entire Karasuma Line.', FALSE),
    ('delay_tozai_full_line', 'Tozai Full Line Delay', 'delay', 'Simulate end-to-end delays affecting the entire Tozai Line.', FALSE),
    ('delay_karasuma_central_segment', 'Karasuma Central Segment Delay', 'delay', 'Simulate concentrated delays on central Karasuma Line stations and adjacent segments.', FALSE),
    ('delay_tozai_eastern_segment', 'Tozai Eastern Segment Delay', 'delay', 'Simulate concentrated delays on the eastern segment of Tozai Line.', FALSE),

    -- Maintenance scenarios
    ('maintenance_karasuma_segment', 'Karasuma Segment Maintenance', 'maintenance', 'Simulate planned maintenance on a segment of Karasuma Line with reduced service.', FALSE),
    ('maintenance_tozai_segment', 'Tozai Segment Maintenance', 'maintenance', 'Simulate planned maintenance on a segment of Tozai Line with reduced service.', FALSE),
    ('maintenance_karasuma_night', 'Karasuma Night Maintenance', 'maintenance', 'Simulate late-night maintenance operations on Karasuma Line.', FALSE),
    ('maintenance_tozai_night', 'Tozai Night Maintenance', 'maintenance', 'Simulate late-night maintenance operations on Tozai Line.', FALSE),
    ('maintenance_karasuma_oike_station', 'Karasuma Oike Station Maintenance', 'maintenance', 'Simulate planned maintenance impacting station movement and transfer capacity at Karasuma Oike.', FALSE),

    -- Closure scenarios
    ('closure_karasuma_oike_interchange', 'Karasuma Oike Interchange Closure', 'closure', 'Simulate temporary closure of interchange transfer flows at Karasuma Oike.', FALSE),
    ('closure_karasuma_line_partial', 'Karasuma Line Partial Closure', 'closure', 'Simulate partial closure of Karasuma Line between selected stations.', FALSE),
    ('closure_tozai_line_partial', 'Tozai Line Partial Closure', 'closure', 'Simulate partial closure of Tozai Line between selected stations.', FALSE),
    ('closure_single_station_karasuma', 'Karasuma Single Station Closure', 'closure', 'Simulate closure of a single station on Karasuma Line while surrounding segments remain operational.', FALSE),
    ('closure_single_station_tozai', 'Tozai Single Station Closure', 'closure', 'Simulate closure of a single station on Tozai Line while surrounding segments remain operational.', FALSE),
    ('closure_karasuma_full_line', 'Karasuma Full Line Closure', 'closure', 'Simulate complete suspension of Karasuma Line service.', FALSE),
    ('closure_tozai_full_line', 'Tozai Full Line Closure', 'closure', 'Simulate complete suspension of Tozai Line service.', FALSE),

    -- Mixed scenarios
    ('mixed_city_event_disruption', 'City Event Mixed Disruption', 'mixed', 'Simulate combined delays, transfer congestion, and partial closures caused by a major city event.', FALSE),
    ('mixed_severe_weather', 'Severe Weather Mixed Scenario', 'mixed', 'Simulate weather-related delays, selective station restrictions, and degraded routing availability.', FALSE),
    ('mixed_emergency_response', 'Emergency Response Scenario', 'mixed', 'Simulate an emergency response case with closures, rerouting, and cascading delays.', FALSE),
    ('mixed_transfer_congestion', 'Transfer Congestion Scenario', 'mixed', 'Simulate severe transfer congestion with increased transfer times and moderate line delays.', FALSE),
    ('mixed_peak_hour_incident', 'Peak Hour Incident Scenario', 'mixed', 'Simulate a peak-hour incident that causes both station restrictions and multi-segment delays.', FALSE),
    ('mixed_multi_line_disruption', 'Multi Line Disruption Scenario', 'mixed', 'Simulate simultaneous disruptions across both Karasuma and Tozai lines.', FALSE);

    

    
