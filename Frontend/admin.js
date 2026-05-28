const API_BASE_URL = 'http://127.0.0.1:5000/api'; 

document.addEventListener('DOMContentLoaded', () => {
    // 1. Khởi tạo bản đồ nền
    const map = L.map('map-bg', { zoomControl: false, dragging: false, scrollWheelZoom: false }).setView([35.0116, 135.7681], 13);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);

    // Vẽ dữ liệu từ Mapdata.js lên bản đồ nền làm hiệu ứng chìm
    if (typeof kyotoGeoData !== 'undefined') {
        L.geoJSON(kyotoGeoData, {
            style: { color: "#34495e", weight: 1, opacity: 0.3 }, 
            pointToLayer: function (feature, latlng) {
                if (feature.properties && (feature.properties.railway === 'station' || feature.properties.public_transport === 'station')) {
                    return L.circleMarker(latlng, { radius: 5, fillColor: "#e74c3c", color: "#fff", weight: 1, fillOpacity: 0.8 });
                }
                return L.circleMarker(latlng, { radius: 2, color: "#aaa", opacity: 0.2 });
            }
        }).addTo(map);
    }

    // 2. Mặc định nạp danh sách Ga
    fetchTargets('station');

    // 3. Chuyển đổi danh sách đối tượng & Đổi màu khi thay đổi loại sự cố
    const eventTypeSelect = document.getElementById('eventType');
    eventTypeSelect.addEventListener('change', (e) => {
        fetchTargets(e.target.value);
        
        const colors = { 'station': '#3498db', 'line': '#e67e22', 'trip': '#9b59b6', 'edge': '#1abc9c' };
        eventTypeSelect.style.color = colors[eventTypeSelect.value] || 'white';
    });
    eventTypeSelect.dispatchEvent(new Event('change'));

    // 4. Đổi màu chữ khi thay đổi trạng thái sự cố
    const eventStatusSelect = document.getElementById('eventStatus');
    eventStatusSelect.addEventListener('change', function() {
        const colors = { 'normal': '#2ecc71', 'warning': '#f1c40f', 'incident': '#e74c3c', 'maintenance': '#bdc3c7' };
        this.style.color = colors[this.value] || 'white';
    });
    eventStatusSelect.dispatchEvent(new Event('change'));

    // 5. Lắng nghe nút lệnh Submit gửi về server
    document.getElementById('submitAdminBtn').addEventListener('click', postStatusEvent);
});

// =====================================================================
// [NHẬN TỪ BACKEND/MAPDATA]: Lấy danh sách đối tượng đổ vào ô Target ID
// =====================================================================
async function fetchTargets(type) {
    const targetSelect = document.getElementById('targetList');
    targetSelect.innerHTML = '<option value="">Đang đồng bộ...</option>';
    
    // Nếu chọn 'station' -> Trích xuất trực tiếp dữ liệu từ file Mapdata.js
    if (type === 'station' && typeof kyotoGeoData !== 'undefined') {
        targetSelect.innerHTML = '<option value="">-- Chọn ga tàu --</option>';
        
        const stations = kyotoGeoData.features.filter(f => 
            f.properties && (f.properties.railway === 'station' || f.properties.public_transport === 'station')
        );

        stations.forEach(station => {
            const id = station.properties['@id'] || station.id;
            const name = station.properties.name || station.properties['name:en'] || `Ga ID: ${id}`;
            targetSelect.add(new Option(name, id));
        });
        return;
    }

    // Ngược lại, gọi API kéo từ Backend về đối với Line, Trip, Edge
    const endpoints = {
        'line': '/lines',
        'trip': '/trips',
        'edge': '/edges' 
    };

    try {
        const response = await fetch(`${API_BASE_URL}${endpoints[type]}`);
        if (!response.ok) throw new Error();
        const data = await response.json();
        
        targetSelect.innerHTML = '';
        data.forEach(item => {
            let option = new Option(item.name || `Mã ID: ${item.id}`, item.id);
            targetSelect.add(option);
        });
    } catch (err) {
        targetSelect.innerHTML = '<option value=""> Lỗi tải dữ liệu Backend</option>';
    }
}

// =====================================================================
// [GỬI VỀ BACKEND]: Đẩy sự cố lên Server qua phương thức POST
// =====================================================================
async function postStatusEvent() {
    const type = document.getElementById('eventType').value;
    const targetId = document.getElementById('targetList').value;
    const status = document.getElementById('eventStatus').value;
    const msgDiv = document.getElementById('status-msg');

    if (!targetId) {
        msgDiv.innerText = " Vui lòng chọn đối tượng bị ảnh hưởng!";
        msgDiv.style.color = "#f1c40f";
        return;
    }

    msgDiv.innerText = " Đang truyền tín hiệu tới server...";
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
