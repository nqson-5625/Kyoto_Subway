// ==========================================
// 1. CẤU HÌNH BIẾN TOÀN CỤC & MAP
// ==========================================
const API_BASE_URL = 'http://127.0.0.1:5000/api';
const map = L.map('map').setView([35.0116, 135.7681], 12);
let startMarker, endMarker, currentPath;
let isSelectingStart = true;

// Nền bản đồ
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap'
}).addTo(map);

// Vẽ ranh giới Kyoto (Biến kyotoData được định nghĩa trong index.html)
if (typeof kyotoData !== 'undefined' && kyotoData.features) {
    L.geoJSON(kyotoData, {
        style: { color: '#ff4d4d', weight: 3, fillOpacity: 0 },
        filter: (f) => f.geometry.type !== 'Point'
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
        // Load kịch bản vận hành
        const scRes = await fetch(`${API_BASE_URL}/scenarios`);
        const scenarios = await scRes.json();
        const scSelect = document.getElementById('scenarioSelect');
        scenarios.forEach(s => scSelect.add(new Option(s.name, s.id)));

        // Load sự cố thời gian thực
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
    // Kiểm tra đầu vào
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

        // KIỂM TRA OUTPUT: Nếu không thể trích xuất lộ trình
        if (!result || !result.path || result.path.length === 0) {
            showToast("Không tìm thấy đường đi hoặc lộ trình bị lỗi!", "error");
            if (currentPath) map.removeLayer(currentPath);
            document.getElementById('stat-time').innerText = "-- phút";
            document.getElementById('stat-length').innerText = "-- m";
            return;
        }

        // Vẽ đường đi
        if (currentPath) map.removeLayer(currentPath);
        currentPath = L.polyline(result.path, {
            color: '#7f7fd5',
            weight: 6,
            lineJoin: 'round'
        }).addTo(map);

        map.fitBounds(currentPath.getBounds(), {padding: [50, 50]});

        // Cập nhật thông tin hành trình
        document.getElementById('stat-time').innerText = (result.travel_time || 0) + " phút";
        document.getElementById('stat-length').innerText = (result.distance || 0) + " m";
        showToast("Đã trích xuất lộ trình tối ưu.", "success");

    } catch (err) {
        showToast("Lỗi hệ thống: " + err.message, "error");
    } finally {
        btn.innerText = "TÌM ĐƯỜNG ĐI TỐI ƯU";
        btn.disabled = false;
    }
});

// Khởi chạy khi load trang
initDashboard();