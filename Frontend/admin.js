const API_BASE_URL = 'http://localhost:5000'; 

document.addEventListener('DOMContentLoaded', () => {
    // Khởi tạo bản đồ nền
    const map = L.map('map-bg', { zoomControl: false, dragging: false, scrollWheelZoom: false }).setView([35.0116, 135.7681], 13);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);

    // Mặc định nạp danh sách Ga
    fetchTargets('station');

    // Chuyển đổi danh sách đối tượng khi thay đổi loại sự cố
    document.getElementById('eventType').addEventListener('change', (e) => {
        fetchTargets(e.target.value);
    });

    document.getElementById('submitAdminBtn').addEventListener('click', postStatusEvent);
});

// =====================================================================
// [NHẬN TỪ BACKEND]: Lấy danh sách đối tượng (GET /stations, /lines, etc.)
// =====================================================================
async function fetchTargets(type) {
    const targetSelect = document.getElementById('targetList');
    targetSelect.innerHTML = '<option>Đang đồng bộ...</option>';
    
    // Mapping loại sự cố với Endpoint GET tương ứng
    const endpoints = {
        'station': '/stations',
        'line': '/lines',
        'trip': '/trips',
        'edge': '/edge-status-events' // Hoặc endpoint chứa danh sách cạnh
    };

    try {
        const response = await fetch(`${API_BASE_URL}${endpoints[type]}`);
        if (!response.ok) throw new Error();
        const data = await response.json();
        
        targetSelect.innerHTML = '';
        data.forEach(item => {
            let option = new Option(item.name || `ID: ${item.id}`, item.id);
            targetSelect.add(option);
        });
    } catch (err) {
        targetSelect.innerHTML = '<option>Lỗi tải dữ liệu Backend</option>';
    }
}

// =====================================================================
// [GỬI VỀ BACKEND]: Phát hành sự kiện mới (POST /...-status-events)
// =====================================================================
async function postStatusEvent() {
    const type = document.getElementById('eventType').value;
    const targetId = document.getElementById('targetList').value;
    const status = document.getElementById('eventStatus').value;
    const msgDiv = document.getElementById('status-msg');

    if (!targetId) return;

    msgDiv.innerText = "📡 Đang truyền tín hiệu tới server...";
    msgDiv.style.color = "#3498db";

    // Mapping loại sự cố với Endpoint POST tương ứng từ danh sách của bạn
    const postEndpoints = {
        'station': '/station-status-events',
        'line': '/line-status-events',
        'trip': '/trip-status-events',
        'edge': '/edge-status-events'
    };

    try {
        const response = await fetch(`${API_BASE_URL}${postEndpoints[type]}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                [`${type}_id`]: targetId, // Dynamic key: station_id, line_id, v.v.
                status: status,
                timestamp: new Date().toISOString()
            })
        });
        
        if(response.ok) {
            msgDiv.innerText = "🚀 Cập nhật hệ thống thành công!";
            msgDiv.style.color = "#2ecc71";
        } else {
            throw new Error();
        }
    } catch (err) {
        msgDiv.innerText = "❌ Lỗi: Backend từ chối yêu cầu";
        msgDiv.style.color = "#e74c3c";
    }
}