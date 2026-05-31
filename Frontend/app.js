// ==========================================
// 1. CẤU HÌNH BIẾN TOÀN CỤC & MAP
// ==========================================
const API_BASE_URL = 'http://127.0.0.1:8000/api/v1';
const map = L.map('map').setView([35.0116, 135.7681], 12);
let startMarker, endMarker;
let routeLayerGroup = L.featureGroup().addTo(map);
let isSelectingStart = true;

// Nền bản đồ OpenStreetMap
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap contributors'
}).addTo(map);

// Vẽ ranh giới Kyoto hoặc mạng lưới giao thông ban đầu nếu có dữ liệu
const geoData = typeof kyotoData !== 'undefined' ? kyotoData : (typeof kyotoGeoData !== 'undefined' ? kyotoGeoData : null);

if (geoData && geoData.features) {
    L.geoJSON(geoData, {
        style: { color: '#ff4d4d', weight: 2, fillOpacity: 0, dashArray: '5, 5' },
        filter: (f) => {
            const r = f.properties ? f.properties.railway : '';
            const pt = f.properties ? f.properties.public_transport : '';
            // Lọc ẩn các ga và tuyến đường ray chính để tránh rối mắt ban đầu
            return !(r === 'subway' || r === 'rail' || r === 'light_rail' || r === 'station' || pt === 'station' || f.geometry.type === 'Point');
        }
    }).addTo(map);
}

// KHỞI TẠO LAYER TÀU ĐIỆN NGẦM ẨN/HIỆN (TĨNH) KHỚP MÀU & TIẾNG ANH
let subwayLayer = L.featureGroup();
let isSubwayVisible = false;

if (geoData && geoData.features) {
    L.geoJSON(geoData, {
        filter: (f) => {
            const r = f.properties ? f.properties.railway : '';
            const pt = f.properties ? f.properties.public_transport : '';
            if (r === 'subway') return true;
            if (r === 'station' || pt === 'station') {
                const propStr = JSON.stringify(f.properties).toLowerCase();
                if (propStr.includes('subway') || propStr.includes('karasuma') || propStr.includes('tozai')) {
                    return true;
                }
            }
            return false;
        },
        pointToLayer: (f, latlng) => {
            const propStr = JSON.stringify(f.properties).toLowerCase();
            let strokeColor = '#38bdf8';
            if (propStr.includes('karasuma')) strokeColor = '#4CAF50';
            else if (propStr.includes('tozai')) strokeColor = '#E60012';

            const stationNameEN = f.properties['name:en'] || f.properties.name_en || f.properties.name || 'Unknown Station';
            return L.circleMarker(latlng, {
                radius: 5,
                fillColor: '#ffffff',
                color: strokeColor,
                weight: 2,
                opacity: 1,
                fillOpacity: 1
            }).bindPopup(`<b> Ga: ${stationNameEN}</b><br><span style="font-size:11px;color:#666;">Tuyến Tàu điện ngầm</span>`);
        },
        style: (f) => {
            if (f.geometry && f.geometry.type === 'Point') return {};
            const propStr = JSON.stringify(f.properties).toLowerCase();
            let lineColor = '#38bdf8';
            if (propStr.includes('karasuma')) lineColor = '#4CAF50';
            else if (propStr.includes('tozai')) lineColor = '#E60012';
            return { color: lineColor, weight: 5, opacity: 0.9 };
        }
    }).addTo(subwayLayer);
}

// Bắt sự kiện nhấn nút Ẩn/Hiện Tàu điện ngầm trong Sidebar
const toggleSubwayBtn = document.getElementById('toggleSubwayBtn');
if (toggleSubwayBtn) {
    toggleSubwayBtn.addEventListener('click', (e) => {
        e.preventDefault();
        if (isSubwayVisible) {
            map.removeLayer(subwayLayer);
            toggleSubwayBtn.innerText = "Hiện hệ thống tàu";
            isSubwayVisible = false;
        } else {
            subwayLayer.addTo(map);
            toggleSubwayBtn.innerText = "Ẩn hệ thống tàu";
            isSubwayVisible = true;
            if (subwayLayer.getLayers().length > 0) {
                map.fitBounds(subwayLayer.getBounds(), { padding: [40, 40] });
            }
        }
    });
}

// ==========================================
// 2. HỆ THỐNG THÔNG BÁO (TOAST NOTIFICATION)
// ==========================================
function showToast(message, type = 'error') {
    const container = document.getElementById('toast-container');
    if (!container) {
        console.log(`${type.toUpperCase()}: ${message}`);
        return;
    }

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;

    toast.innerHTML = `<span></span> <span>${message}</span>`;
    container.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transition = '0.5s';
        setTimeout(() => toast.remove(), 500);
    }, 4000);
}

// ==========================================
// 3. KHỞI TẠO DASHBOARD & STATUS EVENTS (BACKEND)
// ==========================================
async function initDashboard() {
    // 1. Giữ nguyên tính năng lấy ngày hiện tại
    const dateInput = document.getElementById('serviceDate');
    if (dateInput && !dateInput.value) {
        dateInput.value = new Date().toISOString().split('T')[0];
    }

    try {
        const scRes = await fetch(`${API_BASE_URL}/scenarios`);
        if (scRes.ok) {
            let scenarios = await scRes.json();

            // In ra Console để debug nếu vẫn lỗi
            console.log("Dữ liệu Scenarios từ Backend:", scenarios);

            // Chống lỗi nếu Backend bọc data vào trong { data: [...] }
            if (!Array.isArray(scenarios)) {
                if (scenarios.data) scenarios = scenarios.data;
                else if (scenarios.items) scenarios = scenarios.items;
                else scenarios = Object.values(scenarios)[0];
            }

            const scSelect = document.getElementById('scenarioSelect');
            if (scSelect) {
                let optionsHTML = '<option value="">-- Bình thường (Không sự cố) --</option>';

                scenarios.forEach((s, index) => {
                    // Cố gắng lấy tên
                    let text = s.scenario_name || s.name;
                    let value = s.scenario_id || s.id;

                    // NẾU KHÔNG CÓ TÊN -> ÉP IN TOÀN BỘ CỤC DỮ LIỆU ĐỂ TÌM LỖI
                    if (!text) {
                        text = `Dữ liệu lạ ${index + 1}: ` + JSON.stringify(s);
                    }
                    if (!value) {
                        value = `error_${index}`;
                    }

                    optionsHTML += `<option value="${value}">${text}</option>`;
                });

                scSelect.innerHTML = optionsHTML;
            }
        }
        // 2. Giữ nguyên tính năng cập nhật bảng thông báo sự cố đỏ ở dưới
        await refreshSystemStatus();
    } catch (err) {
        showToast("Chưa kết nối được với Backend để tải sự cố.", "warning");
    }
}

async function refreshSystemStatus() {
    const list = document.getElementById('statusList');
    if (!list) return;

    try {
        const [stationEvents, lineEvents] = await Promise.all([
            fetch(`${API_BASE_URL}/station-status-events`).then(r => r.ok ? r.json() : []),
            fetch(`${API_BASE_URL}/line-status-events`).then(r => r.ok ? r.json() : [])
        ]);

        if (stationEvents.length === 0 && lineEvents.length === 0) {
            list.innerHTML = '<div style="text-align:center; color:#28a745; font-size:12px; padding: 5px;">✓ Hệ thống ổn định</div>';
            return;
        }

        list.innerHTML = '';

        // Sửa lại theo đúng format của StationStatusEventResponse
        stationEvents.forEach(ev => {
            const statusText = ev.status.toUpperCase();
            const reason = ev.reason_text ? ` - ${ev.reason_text}` : '';
            list.innerHTML += `<div class="event-item"><b>Ga ${ev.station_id}:</b> ${statusText}${reason}</div>`;
        });

        // Sửa lại theo đúng format của LineStatusEventResponse
        lineEvents.forEach(ev => {
            const statusText = ev.status.toUpperCase();
            const reason = ev.reason_text ? ` - ${ev.reason_text}` : '';
            list.innerHTML += `<div class="event-item line"><b>Tuyến ${ev.line_id}:</b> ${statusText}${reason}</div>`;
        });

    } catch (e) {
        list.innerHTML = '<div style="color:#888; font-size:11px; text-align:center; padding: 5px;">Không thể tải dữ liệu sự cố công cộng.</div>';
    }
}

// ==========================================
// 4. TƯƠNG TÁC CHỌN ĐIỂM TRÊN BẢN ĐỒ
// ==========================================
map.on('click', (e) => {
    const latlng = e.latlng;
    if (isSelectingStart) {
        if (startMarker) map.removeLayer(startMarker);
        startMarker = L.marker(latlng, { draggable: true }).addTo(map).bindPopup("<b>A</b> - Điểm bắt đầu").openPopup();

        const startInput = document.getElementById('start-input');
        if (startInput) startInput.value = `Lat: ${latlng.lat.toFixed(4)}, Lng: ${latlng.lng.toFixed(4)}`;

        startMarker.on('dragend', function () {
            const pos = startMarker.getLatLng();
            if (startInput) startInput.value = `Lat: ${pos.lat.toFixed(4)}, Lng: ${pos.lng.toFixed(4)}`;
        });

        isSelectingStart = false;
    } else {
        if (endMarker) map.removeLayer(endMarker);
        endMarker = L.marker(latlng, { draggable: true }).addTo(map).bindPopup("<b>B</b> - Đích đến").openPopup();

        const endInput = document.getElementById('end-input');
        if (endInput) endInput.value = `Lat: ${latlng.lat.toFixed(4)}, Lng: ${latlng.lng.toFixed(4)}`;

        endMarker.on('dragend', function () {
            const pos = endMarker.getLatLng();
            if (endInput) endInput.value = `Lat: ${pos.lat.toFixed(4)}, Lng: ${pos.lng.toFixed(4)}`;
        });

        isSelectingStart = true;
    }
});

const clearBtn = document.getElementById('clearBtn');
if (clearBtn) {
    clearBtn.addEventListener('click', () => {
        if (startMarker) { map.removeLayer(startMarker); startMarker = null; }
        if (endMarker) { map.removeLayer(endMarker); endMarker = null; }
        if (typeof searchMarker !== 'undefined' && searchMarker) {
            map.removeLayer(searchMarker);
            searchMarker = null;
        }
        routeLayerGroup.clearLayers();

        const startInput = document.getElementById('start-input');
        const endInput = document.getElementById('end-input');
        const searchInput = document.getElementById('searchInput');
        if (startInput) startInput.value = "";
        if (endInput) endInput.value = "";
        if (searchInput) searchInput.value = "";

        document.getElementById('stat-time').innerText = "-- ms";
        document.getElementById('stat-length').innerText = "-- m";
        document.getElementById('perf-section').style.display = 'none';

        isSelectingStart = true;
        showToast("Đã xóa các điểm đã chọn.", "success");
    });
}

// ==========================================
// 5. THỰC THI THUẬT TOÁN TÌM ĐƯỜNG
// ==========================================
document.getElementById('findPathBtn').addEventListener('click', async () => {
    if (!startMarker || !endMarker) {
        showToast("Vui lòng chọn 2 điểm trên bản đồ!", "error");
        return;
    }

    const btn = document.getElementById('findPathBtn');
    btn.innerText = "ĐANG TÍNH TOÁN...";
    btn.disabled = true;

    document.getElementById('perf-section').style.display = 'block';
    document.getElementById('stat-time').innerText = "...";
    document.getElementById('stat-length').innerText = "...";

    const payload = {
        start: startMarker.getLatLng(),
        end: endMarker.getLatLng(),
        algorithm: document.getElementById('algoSelect').value,
        scenario_id: document.getElementById('scenarioSelect') ? document.getElementById('scenarioSelect').value : "",
        service_date: document.getElementById('serviceDate') ? document.getElementById('serviceDate').value : ""
    };

    try {
        const response = await fetch(`${API_BASE_URL}/route/find-path`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            throw new Error("Lỗi kết nối đến máy chủ định tuyến.");
        }

        const result = await response.json();

        // Hỗ trợ cả 2 định dạng trả về (RoutePostprocessingOutput hoặc CoreRoutingOutput)
        let routes = result.routes || [];
        if (routes.length === 0 && result.segments) {
            routes = [{ segments: result.segments, cost_breakdown: { time_cost: result.travel_time } }];
        }

        if (!routes || routes.length === 0 || !routes[0].segments || routes[0].segments.length === 0) {
            showToast(result.message || "Không tìm thấy lộ trình phù hợp giữa 2 điểm này!", "error");
            routeLayerGroup.clearLayers();
            document.getElementById('stat-time').innerText = "-- ms";
            document.getElementById('stat-length').innerText = "-- m";
            return;
        }

        routeLayerGroup.clearLayers();
        const mainRoute = routes[0];
        let totalTravelTime = mainRoute.cost_breakdown?.time_cost || 0;

        // VẼ CÁC ĐOẠN ĐƯỜNG
        mainRoute.segments.forEach(segment => {
            let latLngs = [];

            // Giải mã toạ độ thực tế từ thuộc tính polyline
            if (segment.polyline && segment.polyline.points) {
                latLngs = JSON.parse(segment.polyline.points);
            } else if (segment.coordinates && segment.coordinates.length > 0) {
                latLngs = segment.coordinates; // Hỗ trợ tương thích ngược
            }

            if (latLngs.length > 0) {
                let strokeColor = '#0078FF'; // Xanh dương (Tàu)
                let weight = 6;
                let dashArray = null;

                if (segment.mode === 'walk') {
                    strokeColor = '#888888'; // Xám (Đi bộ thực tế)
                    weight = 5;
                    dashArray = '6, 6';
                } else if (segment.mode === 'transfer') {
                    strokeColor = '#FFA500'; // Cam (Chuyển tuyến)
                    weight = 5;
                    dashArray = '4, 4';
                }

                L.polyline(latLngs, {
                    color: strokeColor,
                    weight: weight,
                    dashArray: dashArray,
                    opacity: 1.0,
                    lineJoin: 'round'
                }).addTo(routeLayerGroup);
            }
        });

        // ZOOM VỪA VẶN BẢN ĐỒ
        if (routeLayerGroup.getLayers().length > 0) {
            map.fitBounds(routeLayerGroup.getBounds(), { padding: [40, 40] });
        }

        // HIỂN THỊ THỜI GIAN
        document.getElementById('stat-time').innerText = totalTravelTime > 0 ? `${totalTravelTime.toFixed(1)} phút` : "-- phút";
        document.getElementById('stat-length').innerText = "Đường đi thực tế";

        showToast("Đã tính toán lộ trình thành công!", "success");

    } catch (err) {
        console.error(err);
        showToast("Lỗi hệ thống: " + err.message, "error");
    } finally {
        btn.innerText = "TÌM ĐƯỜNG ĐI TỐI ƯU";
        btn.disabled = false;
    }
});

// ==========================================
// 6. TÌM KIẾM ĐỊA CHỈ
// ==========================================
let searchMarker;

const searchBtn = document.getElementById('searchBtn');
if (searchBtn) {
    searchBtn.addEventListener('click', async () => {
        const query = document.getElementById('searchInput').value;
        if (!query) {
            showToast("Vui lòng nhập địa chỉ cần tìm!", "warning");
            return;
        }

        searchBtn.innerText = "...";
        searchBtn.disabled = true;

        try {
            const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=1&viewbox=135.5,35.2,136.0,34.8&bounded=0`;
            const res = await fetch(url);
            const data = await res.json();

            if (data && data.length > 0) {
                const lat = parseFloat(data[0].lat);
                const lon = parseFloat(data[0].lon);

                map.setView([lat, lon], 15);

                if (searchMarker) map.removeLayer(searchMarker);
                searchMarker = L.marker([lat, lon]).addTo(map)
                    .bindPopup(`<b>Kết quả:</b> ${data[0].display_name}`).openPopup();

                showToast("Đã tìm thấy địa điểm!", "success");
            } else {
                showToast("Không tìm thấy địa điểm này.", "error");
            }
        } catch (err) {
            showToast("Lỗi kết nối máy chủ tìm kiếm.", "error");
        } finally {
            searchBtn.innerText = "Tìm";
            searchBtn.disabled = false;
        }
    });
}

document.getElementById('searchInput').addEventListener('keypress', function (e) {
    if (e.key === 'Enter') {
        document.getElementById('searchBtn').click();
    }
});

initDashboard();