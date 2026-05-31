// ==========================================
// 1. CẤU HÌNH BIẾN TOÀN CỤC & MAP
// ==========================================
const API_BASE_URL = 'http://127.0.0.1:8000/api';
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
// 3. TƯƠNG TÁC CHỌN ĐIỂM TRÊN BẢN ĐỒ
// ==========================================
map.on('click', (e) => {
    const latlng = e.latlng;
    if (isSelectingStart) {
        if (startMarker) map.removeLayer(startMarker);
        startMarker = L.marker(latlng, {draggable: true}).addTo(map).bindPopup("<b>A</b> - Điểm bắt đầu").openPopup();
        
        const startInput = document.getElementById('start-input');
        if (startInput) startInput.value = `Lat: ${latlng.lat.toFixed(4)}, Lng: ${latlng.lng.toFixed(4)}`;
        
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
        
        endMarker.on('dragend', function() {
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
// 4. THỰC THI THUẬT TOÁN TÌM ĐƯỜNG
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

        // 1. Vẽ các đoạn đường đi (Segments) kết hợp đồng bộ màu sắc 2 Subway
        if (result.segments) {
            result.segments.forEach(segment => {
                let isTrainRoute = ['subway', 'metro', 'rail', 'light_rail'].includes(segment.mode);
                let polylineStyle;
                
                if (isTrainRoute) {
                    let strokeColor = '#fb923c'; 
                    
                    if (segment.mode === 'subway') {
                        const segmentStr = JSON.stringify(segment).toLowerCase();
                        if (segmentStr.includes('karasuma')) {
                            strokeColor = '#4CAF50'; // Karasuma - Xanh lá
                        } else if (segmentStr.includes('tozai')) {
                            strokeColor = '#E60012'; // Tozai - Đỏ
                        } else {
                            strokeColor = '#38bdf8';
                        }
                    }
                    polylineStyle = { color: strokeColor, weight: 6, opacity: 0.9 };
                } else {
                    polylineStyle = { color: '#2ecc71', weight: 4, dashArray: '8, 8', opacity: 0.8 };
                }

                L.polyline(segment.coordinates, polylineStyle).addTo(routeLayerGroup);

                // 2. Điểm các nhà ga dọc tuyến khớp màu viền
                if (segment.stations && segment.stations.length > 0) {
                    segment.stations.forEach(station => {
                        let markerColor = "#1e293b";
                        
                        if (segment.mode === 'subway') {
                            const stationStr = JSON.stringify(station).toLowerCase();
                            const segmentStr = JSON.stringify(segment).toLowerCase();
                            if (stationStr.includes('karasuma') || segmentStr.includes('karasuma')) {
                                markerColor = '#4CAF50';
                            } else if (stationStr.includes('tozai') || segmentStr.includes('tozai')) {
                                markerColor = '#E60012';
                            } else {
                                markerColor = '#38bdf8';
                            }
                        } else if (!isTrainRoute) {
                            markerColor = "#2ecc71";
                        }

                        // Ưu tiên lấy tiếng Anh
                        let stationNameEN = station.name_en || station['name:en'] || station.name || 'Unknown Station';

                        L.circleMarker([station.lat, station.lng], {
                            radius: 5,
                            fillColor: "#fff",
                            color: markerColor,
                            weight: 2,
                            opacity: 1,
                            fillOpacity: 1
                        }).bindPopup(`<b> Ga: ${stationNameEN}</b><br><span style="font-size:11px;color:#666;">Mode: ${segment.mode.toUpperCase()}</span>`)
                          .addTo(routeLayerGroup);
                    });
                }
            });
        }

        if (routeLayerGroup.getLayers().length > 0) {
            map.fitBounds(routeLayerGroup.getBounds(), { padding: [40, 40] });
        }

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
// 5. TÌM KIẾM ĐỊA CHỈ
// ==========================================
// Sự kiện khi bấm nút Tìm vị trí
    document.getElementById('searchBtn').addEventListener('click', handleSearchAddress);

    // Sự kiện khi nhấn phím Enter ngay trong ô nhập liệu địa chỉ
    document.getElementById('search-input').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') handleSearchAddress();
    });
    async function handleSearchAddress() {
    const query = document.getElementById('search-input').value.trim();
    if (!query) {
        showToast("Vui lòng nhập tên địa danh hoặc nhà ga cần tìm kiếm!", "warning");
        return;
    }

    const searchBtn = document.getElementById('searchBtn');
    searchBtn.innerText = "Đang tìm...";
    searchBtn.disabled = true;

    // Định vị địa chỉ và giới hạn tìm kiếm tập trung tại khu vực Kyoto, Nhật Bản
    const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}+Kyoto&limit=1`;

    try {
        const response = await fetch(url);
        const results = await response.json();

        if (results && results.length > 0) {
            const topResult = results[0];
            const lat = parseFloat(topResult.lat);
            const lon = parseFloat(topResult.lon);
            const targetLatLng = L.latLng(lat, lon);

            // Phóng tầm mắt bản đồ đến vị trí vừa tìm thấy
            map.setView(targetLatLng, 15);

            // Tự động gán Marker và điền tọa độ vào ô dữ liệu đầu vào (Điểm đi hoặc Điểm đến)
            if (isSelectingStart) {
                if (startMarker) map.removeLayer(startMarker);
                
                startMarker = L.marker(targetLatLng).addTo(map)
                    .bindPopup(`<b>Điểm xuất phát (A)</b><br>${topResult.display_name.split(',')[0]}`).openPopup();
                    
                document.getElementById('start-input').value = `Vĩ độ: ${lat.toFixed(4)}, Kinh độ: ${lon.toFixed(4)}`;
                isSelectingStart = false; // Chuyển lượt chọn tiếp theo sang điểm đích
                showToast("Đã tự động điền Điểm xuất phát từ kết quả tìm kiếm!", "info");
            } else {
                if (endMarker) map.removeLayer(endMarker);
                
                endMarker = L.marker(targetLatLng).addTo(map)
                    .bindPopup(`<b>Đích đến (B)</b><br>${topResult.display_name.split(',')[0]}`).openPopup();
                    
                document.getElementById('end-input').value = `Vĩ độ: ${lat.toFixed(4)}, Kinh độ: ${lon.toFixed(4)}`;
                isSelectingStart = true; // Quay vòng lại lượt chọn điểm đầu
                showToast("Đã tự động điền Đích đến từ kết quả tìm kiếm!", "success");
            }
        } else {
            showToast("Không tìm thấy địa danh nào phù hợp tại khu vực Kyoto.", "error");
        }
    } catch (err) {
        showToast("Lỗi kết nối máy chủ tìm kiếm: " + err.message, "error");
    } finally {
        searchBtn.innerText = "Tìm vị trí";
        searchBtn.disabled = false;
    }
}

initDashboard();