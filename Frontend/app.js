// ==========================================
// 1. CẤU HÌNH BIẾN TOÀN CỤC & MAP
// ==========================================
const API_BASE_URL = 'http://127.0.0.1:5000/api';
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
    const icon = type === 'error' ? '' : (type === 'success' ? '' : '');
    
    toast.innerHTML = `<span>${icon}</span> <span>${message}</span>`;
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
    // Đặt ngày mặc định là hôm nay
    const dateInput = document.getElementById('serviceDate');
    if (dateInput && !dateInput.value) {
        dateInput.value = new Date().toISOString().split('T')[0];
    }

    try {
        const scRes = await fetch(`${API_BASE_URL}/scenarios`);
        if (scRes.ok) {
            const scenarios = await scRes.json();
            const scSelect = document.getElementById('scenarioSelect');
            if (scSelect) {
                scSelect.innerHTML = '<option value="">-- Bình thường (Không sự cố) --</option>';
                scenarios.forEach(s => scSelect.add(new Option(s.name, s.id)));
            }
        }
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
        stationEvents.forEach(ev => {
            list.innerHTML += `<div class="event-item"><b>Ga ${ev.station_name}:</b> ${ev.status}</div>`;
        });
        lineEvents.forEach(ev => {
            list.innerHTML += `<div class="event-item line"><b>Tuyến ${ev.line_name}:</b> ${ev.description}</div>`;
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
        startMarker = L.marker(latlng, {draggable: true}).addTo(map).bindPopup("<b>A</b> - Điểm bắt đầu").openPopup();
        
        const startInput = document.getElementById('start-input');
        if (startInput) startInput.value = `Lat: ${latlng.lat.toFixed(4)}, Lng: ${latlng.lng.toFixed(4)}`;
        
        // Thêm sự kiện kéo marker cập nhật tọa độ
        startMarker.on('dragend', function() {
            const pos = startMarker.getLatLng();
            if (startInput) startInput.value = `Lat: ${pos.lat.toFixed(4)}, Lng: ${pos.lng.toFixed(4)}`;
        });

        isSelectingStart = false;
    } else {
        if (endMarker) map.removeLayer(endMarker);
        endMarker = L.marker(latlng, {draggable: true}).addTo(map).bindPopup("<b>B</b> - Đích đến").openPopup();
        
        const endInput = document.getElementById('end-input');
        if (endInput) endInput.value = `Lat: ${latlng.lat.toFixed(4)}, Lng: ${latlng.lng.toFixed(4)}`;
        
        // Thêm sự kiện kéo marker cập nhật tọa độ
        endMarker.on('dragend', function() {
            const pos = endMarker.getLatLng();
            if (endInput) endInput.value = `Lat: ${pos.lat.toFixed(4)}, Lng: ${pos.lng.toFixed(4)}`;
        });

        isSelectingStart = true;
    }
});

// Xử lý nút Hủy điểm đã chọn
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

    // Hiển thị khung kết quả chờ
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
        const response = await fetch(`${API_BASE_URL}/find-path`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            const errBody = await response.json();
            throw new Error(errBody.message || "Lỗi xử lý đường đi từ Hệ thống.");
        }

        const result = await response.json();

        if (!result || (!result.path && !result.segments)) {
            showToast("Không tìm thấy đường đi thích hợp hoặc mạng lưới bị cô lập!", "error");
            routeLayerGroup.clearLayers();
            document.getElementById('stat-time').innerText = "-- ms";
            document.getElementById('stat-length').innerText = "-- m";
            return;
        }

        routeLayerGroup.clearLayers();

        // 1. Vẽ các đoạn đường đi (Segments)
        if (result.segments) {
            result.segments.forEach(segment => {
                let isTrainRoute = ['subway', 'metro', 'rail', 'light_rail'].includes(segment.mode);
                let polylineStyle;
                
                if (isTrainRoute) {
                    // Tuyến đường sắt/tàu điện ngầm: Màu xanh dương hoặc cam đậm đậm nét
                    let strokeColor = segment.mode === 'subway' ? '#38bdf8' : '#fb923c';
                    polylineStyle = { color: strokeColor, weight: 6, opacity: 0.9 };
                } else {
                    // Đi bộ hoặc phương thức khác: Nét đứt màu xanh lá cây
                    polylineStyle = { color: '#2ecc71', weight: 4, dashArray: '8, 8', opacity: 0.8 };
                }

                L.polyline(segment.coordinates, polylineStyle).addTo(routeLayerGroup);

                // 2. Điểm các nhà ga dọc tuyến nếu có
                if (segment.stations && segment.stations.length > 0) {
                    segment.stations.forEach(station => {
                        L.circleMarker([station.lat, station.lng], {
                            radius: 5,
                            fillColor: "#fff",
                            color: isTrainRoute ? "#1e293b" : "#2ecc71",
                            weight: 2,
                            opacity: 1,
                            fillOpacity: 1
                        }).bindPopup(`<b>🚉 Ga: ${station.name}</b><br><span style="font-size:11px;color:#666;">Mode: ${segment.mode.toUpperCase()}</span>`)
                          .addTo(routeLayerGroup);
                    });
                }
            });
        }

        // Tự động căn góc bản đồ vừa vặn với toàn bộ lộ trình đường đi
        if (routeLayerGroup.getLayers().length > 0) {
            map.fitBounds(routeLayerGroup.getBounds(), { padding: [40, 40] });
        }

        // Cập nhật giao diện thông số hiệu năng kết quả
        // Linh hoạt hiển thị execution_time hoặc travel_time tùy cấu trúc API trả về
        const timeVal = result.execution_time !== undefined ? result.execution_time + " ms" : (result.travel_time ? result.travel_time + " phút" : "0 ms");
        const distVal = result.total_distance !== undefined ? result.total_distance + " m" : (result.distance ? result.distance + " m" : "0 m");

        document.getElementById('stat-time').innerText = timeVal;
        document.getElementById('stat-length').innerText = distVal;
        
        if (result.message) {
            showToast(result.message, "success");
        } else {
            showToast("Đã trích xuất lộ trình tối ưu thành công.", "success");
        }

    } catch (err) {
        showToast("Lỗi hệ thống: " + err.message, "error");
        document.getElementById('stat-time').innerText = "Lỗi";
        document.getElementById('stat-length').innerText = "Lỗi";
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
            // Giới hạn tìm kiếm ưu tiên khu vực Kyoto (viewbox)
            const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=1&viewbox=135.5,35.2,136.0,34.8&bounded=0`;
            const res = await fetch(url);
            const data = await res.json();
            
            if (data && data.length > 0) {
                const lat = parseFloat(data[0].lat);
                const lon = parseFloat(data[0].lon);
                
                // Di chuyển bản đồ đến vị trí tìm thấy
                map.setView([lat, lon], 15);
                
                // Đánh dấu marker tạm thời
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

// Bắt sự kiện nhấn phím Enter trong ô tìm kiếm
document.getElementById('searchInput').addEventListener('keypress', function (e) {
    if (e.key === 'Enter') {
        document.getElementById('searchBtn').click();
    }
});

initDashboard();