const API_BASE_URL = 'http://localhost:5000'; 

document.addEventListener('DOMContentLoaded', () => {
    // Khởi tạo bản đồ nền
    const map = L.map('map-bg', { zoomControl: false, dragging: false, scrollWheelZoom: false }).setView([35.0116, 135.7681], 13);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);

    // Mặc định nạp danh sách Ga
    fetchTargets('station');

    // Chuyển đổi danh sách đối tượng & Đổi màu khi thay đổi loại sự cố
    const eventTypeSelect = document.getElementById('eventType');
    eventTypeSelect.addEventListener('change', (e) => {
        fetchTargets(e.target.value);
        
        // Đổi màu chữ
        const colors = { 'station': '#3498db', 'line': '#e67e22', 'trip': '#9b59b6', 'edge': '#1abc9c' };
        eventTypeSelect.style.color = colors[eventTypeSelect.value] || 'white';
    });
    eventTypeSelect.dispatchEvent(new Event('change'));

    // Đổi màu chữ khi thay đổi trạng thái
    const eventStatusSelect = document.getElementById('eventStatus');
    eventStatusSelect.addEventListener('change', function() {
        const colors = { 'normal': '#2ecc71', 'warning': '#f1c40f', 'incident': '#e74c3c', 'maintenance': '#bdc3c7' };
        this.style.color = colors[this.value] || 'white';
    });
    eventStatusSelect.dispatchEvent(new Event('change'));

    // Lắng nghe nút Submit
    document.getElementById('submitAdminBtn').addEventListener('click', postStatusEvent);
});

// =====================================================================
// [NHẬN TỪ BACKEND]: Lấy danh sách đối tượng
// =====================================================================
async function fetchTargets(type) {
    const targetSelect = document.getElementById('targetList');
    targetSelect.innerHTML = '<option>Đang đồng bộ...</option>';
    
    const endpoints = {
        'station': '/stations',
        'line': '/lines',
        'trip': '/trips',
        'edge': '/edge-status-events'
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
// [GỬI VỀ BACKEND]: Phát hành sự kiện mới
// =====================================================================
async function postStatusEvent() {
    const type = document.getElementById('eventType').value;
    const targetId = document.getElementById('targetList').value;
    const status = document.getElementById('eventStatus').value;
    const msgDiv = document.getElementById('status-msg');

    if (!targetId) return;

    msgDiv.innerText = "📡 Đang truyền tín hiệu tới server...";
    msgDiv.style.color = "#3498db";

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
                [`${type}_id`]: targetId,
                status: status,
                timestamp: new Date().toISOString()
            })
        });
        
        if(response.ok || response.status === 201) {
            msgDiv.innerText = " Cập nhật hệ thống thành công!";
            msgDiv.style.color = "#2ecc71";
        } else {
            throw new Error();
        }
    } catch (err) {
        msgDiv.innerText = " Lỗi: Backend từ chối yêu cầu";
        msgDiv.style.color = "#e74c3c";
    }
}
