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
        targetSelect.innerHTML = '<option value="">-- Chọn ga tàu điện ngầm --</option>';
        const stations = kyotoGeoData.features.filter(f => {
            if (!f.properties || !f.geometry || f.geometry.type !== 'Point') return false;
            
            const r = f.properties.railway || '';
            const pt = f.properties.public_transport || '';
            
            const isStation = (r === 'station' || pt === 'station' || r === 'subway');
            if (!isStation) return false;
            
            const propStr = JSON.stringify(f.properties).toLowerCase();
            return propStr.includes('subway') || propStr.includes('karasuma') || propStr.includes('tozai');
        });

        stations.forEach(station => {
            const id = station.properties['@id'] || station.id;
            
            // ƯU TIÊN HIỂN THỊ TÊN TIẾNG ANH (name:en hoặc name_en trước)
            const name = station.properties['name:en'] || 
                         station.properties.name_en || 
                         station.properties.name || 
                         `Ga ID: ${id}`;
                         
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
// [NHẬN TỪ BACKEND/MAPDATA]: Lấy danh sách đối tượng đổ vào ô Target ID
// =====================================================================
async function fetchTargets(type) {
    const targetSelect = document.getElementById('targetList');
    targetSelect.innerHTML = '<option value="">Đang đồng bộ...</option>';
    
    // Nếu chọn 'station' -> Trích xuất trực tiếp dữ liệu từ file Mapdata.js
    if (type === 'station' && typeof kyotoGeoData !== 'undefined') {
        targetSelect.innerHTML = '<option value="">-- Chọn ga tàu điện ngầm --</option>';
        
        // 1. Khởi tạo danh sách bộ lọc thủ công dựa trên tên tiếng Anh chuẩn của các ga thuộc 2 tuyến
        const karasumaStations = [
            "Kokusaikaikan", "Matsugasaki", "Kitayama", "Kita-Oji", "Kuramaguchi", 
            "Imadegawa", "Marutamachi", "Karasuma Oike", "Shijo", "Gojo", 
            "Kyoto", "Kujo", "Jujo", "Takeda"
        ];
        
        const tozaiStations = [
            "Rokujizo", "Ishida", "Daigo", "Ono", "Nagitsuji", "Higashino", 
            "Yamashina", "Misasagi", "Keage", "Higashiyama", "Sanjo Keihan", 
            "Kyoto Shiyakusho-mae", "Karasuma Oike", "Nijojo-mae", "Nijo", 
            "NishiOji Sanjo", "Uzumasa Tenjingawa"
        ];

        // Lọc toàn bộ các Điểm (Point) được định danh là nhà ga
        const stations = kyotoGeoData.features.filter(f => {
            if (!f.properties || !f.geometry || f.geometry.type !== 'Point') return false;
            const r = f.properties.railway || '';
            const pt = f.properties.public_transport || '';
            return (r === 'station' || pt === 'station' || r === 'subway');
        });

        const addedStationIds = new Set(); // Tránh trùng lặp ga hiển thị

        stations.forEach(station => {
            const id = station.properties['@id'] || station.id;
            if (addedStationIds.has(id)) return;

            // Lấy tên tiếng Anh ưu tiên
            const englishName = station.properties['name:en'] || station.properties.name_en || '';
            const nativeName = station.properties.name || '';
            
            let displayName = englishName || nativeName || `Ga ID: ${id}`;
            
            let lineTag = '';
            const cleanName = (str) => str.toLowerCase().replace(/ station/g, '').trim();
            const targetClean = cleanName(displayName);

            const isKarasuma = karasumaStations.some(s => cleanName(s) === targetClean || targetClean.includes(cleanName(s)));
            const isTozai = tozaiStations.some(s => cleanName(s) === targetClean || targetClean.includes(cleanName(s)));

            if (isKarasuma && isTozai) {
                lineTag = ' [Karasuma & Tozai Line]';
            } else if (isKarasuma) {
                lineTag = ' [Karasuma Line]';
            } else if (isTozai) {
                lineTag = ' [Tozai Line]';
            }

            // Chỉ đẩy vào danh sách tuyển chọn nếu ga này được xác định nằm trong hệ thống Subway
            if (lineTag !== '') {
                const finalOptionName = `${displayName}${lineTag}`;
                targetSelect.add(new Option(finalOptionName, id));
                addedStationIds.add(id);
            }
        });
        const optionsArr = Array.from(targetSelect.options).slice(1);
        optionsArr.sort((a, b) => a.text.localeCompare(b.text));
        targetSelect.innerHTML = '<option value="">-- Chọn ga tàu điện ngầm --</option>';
        optionsArr.forEach(opt => targetSelect.add(opt));

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