// app.js

// ==========================================
// 1. CẤU HÌNH BIẾN TOÀN CỤC & MAP
// ==========================================
const API_BASE_URL = 'http://127.0.0.1:5000/api';
const map = L.map('map').setView([35.0116, 135.7681], 12);
let startMarker, endMarker;
let routeLayerGroup = L.featureGroup().addTo(map);
let isSelectingStart = true;

// Nền bản đồ
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap'
}).addTo(map);

// Vẽ ranh giới Kyoto (tạm ẩn các ga và tuyến đường ray)
if (typeof kyotoData !== 'undefined' && kyotoData.features) {
    L.geoJSON(kyotoData, {
        style: { color: '#ff4d4d', weight: 3, fillOpacity: 0 },
        filter: (f) => {
            const r = f.properties ? f.properties.railway : '';
            const pt = f.properties ? f.properties.public_transport : '';
            return !(r === 'subway' || r === 'rail' || r === 'light_rail' || r === 'station' || pt === 'station' || f.geometry.type === 'Point');
        }
    }).addTo(map);
}

// ==========================================
// 2. HỆ THỐNG THÔNG BÁO (TOAST NOTIFICATION)
// ==========================================
function showToast(message, type = 'error') {
    const container = document.getElementById('toast-container');
    if (!container) return console.log(`${type.toUpperCase()}: ${message}`);

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    const icon = type === 'error' ? '❌' : (type === 'success' ? '✅' : '⚠️');
    
    toast.innerHTML = `<span>${icon}</span> <span>${message}</span>`;
    container.appendChild(toast);

    setTimeout(() => {
        toast.style.opacity = '0';
        toast.style.transition = '0.5s';
        setTimeout(() => toast.remove(), 500);
    }, 4000);
}

// ==========================================
// 3. KHỞI TẠO DASHBOARD & STATUS EVENTS
// ==========================================
async function initDashboard() {
    try {
        const scRes = await fetch(`${API_BASE_URL}/scenarios`);
        const scenarios = await scRes.json();
        const scSelect = document.getElementById('scenarioSelect');
        scenarios.forEach(s => scSelect.add(new Option(s.name, s.id)));
        await refreshSystemStatus();
    } catch (err) {
        showToast("Chưa kết nối được với Backend để tải kịch bản.", "warning");
    }
}

async function refreshSystemStatus() {
    const list = document.getElementById('statusList');
    try {
        const [stationEvents, lineEvents] = await Promise.all([
            fetch(`${API_BASE_URL}/station-status-events`).then(r => r.json()),
            fetch(`${API_BASE_URL}/line-status-events`).then(r => r.json())
        ]);

        if (stationEvents.length === 0 && lineEvents.length === 0) {
            list.innerHTML = '<div style="text-align:center; color:#28a745; font-size:12px;">✓ Hệ thống ổn định</div>';
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
        list.innerHTML = '<div style="color:#888; font-size:11px; text-align:center;">Dữ liệu sự cố trống.</div>';
    }
}

// ==========================================
// 4. CHỌN ĐIỂM TRÊN MAP
// ==========================================
map.on('click', (e) => {
    const latlng = e.latlng;
    if (isSelectingStart) {
        if (startMarker) map.removeLayer(startMarker);
        startMarker = L.marker(latlng, {draggable: true}).addTo(map).bindPopup("Bắt đầu");
        isSelectingStart = false;
    } else {
        if (endMarker) map.removeLayer(endMarker);
        endMarker = L.marker(latlng, {draggable: true}).addTo(map).bindPopup("Kết thúc");
        isSelectingStart = true;
    }
});

// ==========================================
// 5. THỰC THI THUẬT TOÁN & BÁO LỖI OUTPUT
// ==========================================
document.getElementById('findPathBtn').addEventListener('click', async () => {
    if (!startMarker || !endMarker) {
        showToast("Vui lòng chọn 2 điểm trên bản đồ!", "error");
        return;
    }

    const btn = document.getElementById('findPathBtn');
    btn.innerText = "ĐANG TÍNH TOÁN...";
    btn.disabled = true;

    const payload = {
        start: startMarker.getLatLng(),
        end: endMarker.getLatLng(),
        algorithm: document.getElementById('algoSelect').value,
        scenario_id: document.getElementById('scenarioSelect').value,
        service_date: document.getElementById('serviceDate').value
    };

    try {
        const response = await fetch(`${API_BASE_URL}/find-path`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            const errBody = await response.json();
            throw new Error(errBody.message || "Lỗi từ Backend.");
        }

        const result = await response.json();

        if (!result || (!result.path && !result.segments)) {
            showToast("Không tìm thấy đường đi hoặc lộ trình bị lỗi!", "error");
            routeLayerGroup.clearLayers();
            document.getElementById('stat-time').innerText = "-- phút";
            document.getElementById('stat-length').innerText = "-- m";
            return;
        }

        routeLayerGroup.clearLayers();

        if (result.segments) {
            result.segments.forEach(segment => {
                let isTrainRoute = ['subway', 'metro', 'rail'].includes(segment.mode);
                
                if (!isTrainRoute) {
                    L.polyline(segment.coordinates, { color: '#2ecc71', weight: 5, dashArray: '10, 10', opacity: 0.8 }).addTo(routeLayerGroup);
                }

                if (segment.stations && segment.stations.length > 0) {
                    segment.stations.forEach(station => {
                        L.circleMarker([station.lat, station.lng], {
                            radius: 5,
                            fillColor: "#fff",
                            color: "#000",
                            weight: 2,
                            opacity: 1
                        }).bindPopup(`<b>${station.name}</b>`).addTo(routeLayerGroup);
                    });
                }
            });
        }

        if (routeLayerGroup.getLayers().length > 0) {
            map.fitBounds(routeLayerGroup.getBounds(), {padding: [50, 50]});
        }

        document.getElementById('stat-time').innerText = (result.travel_time || result.execution_time || 0) + " phút";
        document.getElementById('stat-length').innerText = (result.distance || result.total_distance || 0) + " m";
        showToast("Đã trích xuất lộ trình tối ưu.", "success");

    } catch (err) {
        showToast("Lỗi hệ thống: " + err.message, "error");
    } finally {
        btn.innerText = "TÌM ĐƯỜNG ĐI TỐI ƯU";
        btn.disabled = false;
    }
});

initDashboard();