const API_BASE_URL = 'http://127.0.0.1:5000/api/v1'; 

const fallbackStations = [
    { id: "node/karasuma_kyoto", name: "Kyoto Station [Karasuma Line]" },
    { id: "node/karasuma_oike", name: "Karasuma Oike [Karasuma/Tozai Line]" },
    { id: "node/karasuma_shijo", name: "Shijo [Karasuma Line]" },
    { id: "node/karasuma_gojo", name: "Gojo [Karasuma Line]" },
    { id: "node/karasuma_kitaoji", name: "Kitaoji [Karasuma Line]" },
    { id: "node/karasuma_imadegawa", name: "Imadegawa [Karasuma Line]" },
    { id: "node/karasuma_marutamachi", name: "Marutamachi [Karasuma Line]" },
    { id: "node/tozai_yamashina", name: "Yamashina [Tozai Line]" },
    { id: "node/tozai_sanjo", name: "Sanjo Keihan [Tozai Line]" },
    { id: "node/tozai_nijo", name: "Nijo [Tozai Line]" }
];

const fallbackEdges = [
    { id: "way/karasuma_sub1", name: "Karasuma Line (Kyoto ➔ Gojo)" },
    { id: "way/karasuma_sub2", name: "Karasuma Line (Gojo ➔ Shijo)" },
    { id: "way/karasuma_sub3", name: "Karasuma Line (Shijo ➔ Karasuma Oike)" },
    { id: "way/karasuma_sub4", name: "Karasuma Line (Karasuma Oike ➔ Marutamachi)" },
    { id: "way/tozai_sub1", name: "Tozai Line (Karasuma Oike ➔ Kyoto Shiyakusho-mae)" },
    { id: "way/tozai_sub2", name: "Tozai Line (Sanjo Keihan ➔ Higashiyama)" },
    { id: "way/tozai_sub3", name: "Tozai Line (Misasagi ➔ Yamashina)" }
];

function getSubwayStations() {
    const stationsList = [];
    if (typeof kyotoGeoData !== 'undefined' && kyotoGeoData.features) {
        kyotoGeoData.features.forEach(f => {
            if (f.geometry && f.geometry.type === 'Point' && f.properties && (f.properties.railway === 'station' || f.properties.public_transport === 'station')) {
                const propStr = JSON.stringify(f.properties).toLowerCase();
                if (propStr.includes('karasuma') || propStr.includes('tozai') || propStr.includes('subway') || propStr.includes('烏丸') || propStr.includes('東西')) {
                    stationsList.push({
                        name: f.properties['name:en'] || f.properties['name:ja-Latn'] || f.properties.name || "Unknown",
                        lng: f.geometry.coordinates[0],
                        lat: f.geometry.coordinates[1]
                    });
                }
            }
        });
    }
    if (stationsList.length === 0) {
        return [
            { name: "Kyoto Station", lng: 135.7586, lat: 34.9858 },
            { name: "Gojo", lng: 135.7595, lat: 34.9963 },
            { name: "Shijo", lng: 135.7597, lat: 35.0037 },
            { name: "Karasuma Oike", lng: 135.7595, lat: 35.0105 }
        ];
    }
    return stationsList;
}

function getNearestStation(lng, lat, stationsList) {
    let minDist = Infinity;
    let nearestName = "Unknown";
    stationsList.forEach(st => {
        const dist = Math.pow(st.lng - lng, 2) + Math.pow(st.lat - lat, 2);
        if (dist < minDist) {
            minDist = dist;
            nearestName = st.name;
        }
    });
    return nearestName;
}

document.addEventListener('DOMContentLoaded', () => {
    const map = L.map('map-bg', { zoomControl: false, dragging: false, scrollWheelZoom: false }).setView([35.0116, 135.7681], 13);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);

    const hasMapData = (typeof kyotoGeoData !== 'undefined' && kyotoGeoData.features);

    if (hasMapData) {
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

    const highlightLayer = L.geoJSON(null).addTo(map);

    fetchTargets('station');

    const eventTypeSelect = document.getElementById('eventType');
    eventTypeSelect.addEventListener('change', (e) => {
        highlightLayer.clearLayers(); 
        fetchTargets(e.target.value);
        
        const colors = { 'station': '#3498db', 'line': '#e67e22', 'trip': '#9b59b6', 'edge': '#1abc9c' };
        eventTypeSelect.style.color = colors[e.target.value] || 'white';
    });

    const eventStatusSelect = document.getElementById('eventStatus');
    eventStatusSelect.addEventListener('change', function() {
        const colors = { 'normal': '#2ecc71', 'warning': '#f1c40f', 'incident': '#e74c3c', 'maintenance': '#bdc3c7' };
        this.style.color = colors[this.value] || 'white';
    });
    eventStatusSelect.dispatchEvent(new Event('change'));

    const targetListSelect = document.getElementById('targetList');
    targetListSelect.addEventListener('change', (e) => {
        const type = document.getElementById('eventType').value;
        const targetId = e.target.value;

        highlightLayer.clearLayers(); 

        if (!targetId || !hasMapData) return;

        if (type === 'station') {
            const feature = kyotoGeoData.features.find(f => (f.properties && f.properties['@id'] || f.id) === targetId);
            if (feature) {
                L.geoJSON(feature, {
                    pointToLayer: function (f, latlng) {
                        return L.circleMarker(latlng, { radius: 12, fillColor: "#f1c40f", color: "#fff", weight: 3, fillOpacity: 1 });
                    }
                }).addTo(highlightLayer);
            }
        } 
        else if (type === 'line') {
            const lineFeatures = kyotoGeoData.features.filter(f => {
                if (f.geometry && (f.geometry.type === 'LineString' || f.geometry.type === 'MultiLineString') && f.properties) {
                    if (f.properties.railway === 'subway' || f.properties.route === 'subway') {
                        const propStr = JSON.stringify(f.properties).toLowerCase();
                        if (targetId === 'karasuma_line' && propStr.includes('karasuma')) return true;
                        if (targetId === 'tozai_line' && propStr.includes('tozai')) return true;
                    }
                }
                return false;
            });
            if (lineFeatures.length > 0) {
                L.geoJSON(lineFeatures, { style: { color: "#f1c40f", weight: 6, opacity: 1 } }).addTo(highlightLayer);
            }
        } 
        else if (type === 'edge') {
            const selectedOptionText = targetListSelect.options[targetListSelect.selectedIndex].text;
            const stationsList = getSubwayStations();

            const edgeFeatures = kyotoGeoData.features.filter(f => {
                if (f.geometry && (f.geometry.type === 'LineString' || f.geometry.type === 'MultiLineString') && f.properties && f.properties.railway === 'subway') {
                    let lineName = f.properties['name:en'] || f.properties.name;
                    if (!lineName) {
                        const propStr = JSON.stringify(f.properties).toLowerCase();
                        lineName = propStr.includes('karasuma') ? "Karasuma Line" : (propStr.includes('tozai') ? "Tozai Line" : "Subway Track");
                    }
                    let coords = f.geometry.coordinates;
                    if (f.geometry.type === 'MultiLineString') coords = coords[0];

                    if (coords && coords.length >= 2) {
                        const sA = getNearestStation(coords[0][0], coords[0][1], stationsList);
                        const sB = getNearestStation(coords[coords.length - 1][0], coords[coords.length - 1][1], stationsList);
                        const currentComputedName = (sA !== sB) ? `${lineName} (${sA} ➔ ${sB})` : `${lineName} (Khu vực ga ${sA})`;
                        return currentComputedName === selectedOptionText;
                    }
                }
                return false;
            });
            if (edgeFeatures.length > 0) {
                L.geoJSON(edgeFeatures, { style: { color: "#f1c40f", weight: 6, opacity: 1 } }).addTo(highlightLayer);
            }
        }
        if (highlightLayer.getLayers().length > 0) {
            const bounds = highlightLayer.getBounds();
            map.fitBounds(bounds, { padding: [50, 50], maxZoom: 15, duration: 0.5 });
        }
    });

    document.getElementById('submitAdminBtn').addEventListener('click', postStatusEvent);
});

async function fetchTargets(type) {
    const targetSelect = document.getElementById('targetList');
    targetSelect.innerHTML = '<option value="">Đang bóc tách dữ liệu...</option>';
    
    const hasMapData = (typeof kyotoGeoData !== 'undefined' && kyotoGeoData.features);

    switch (type) {
        case 'station':
            targetSelect.innerHTML = '<option value="">-- Chọn ga tàu điện ngầm --</option>';
            if (hasMapData) {
                const addedStationIds = new Set();
                kyotoGeoData.features.forEach(f => {
                    if (!f.properties) return;
                    const isStation = f.properties.railway === 'station' || f.properties.public_transport === 'station';
                    if (!isStation) return;

                    const propStr = JSON.stringify(f.properties).toLowerCase();
                    if (!propStr.includes('karasuma') && !propStr.includes('tozai') && !propStr.includes('subway') && !propStr.includes('烏丸') && !propStr.includes('東西')) return;

                    const id = f.properties['@id'] || f.id;
                    if (addedStationIds.has(id)) return;

                    const displayName = f.properties['name:en'] || f.properties['name:ja-Latn'] || f.properties.name || `Station ID: ${id}`;
                    let lineTag = '';
                    if (propStr.includes('karasuma') || propStr.includes('烏丸')) lineTag = ' [Karasuma Line]';
                    else if (propStr.includes('tozai') || propStr.includes('東西')) lineTag = ' [Tozai Line]';

                    targetSelect.add(new Option(`${displayName}${lineTag}`, id));
                    addedStationIds.add(id);
                });
            }

            if (targetSelect.options.length <= 1) {
                console.warn("Kích hoạt Ga tàu dự phòng do dữ liệu bản đồ trống!");
                fallbackStations.forEach(st => targetSelect.add(new Option(st.name, st.id)));
            } else {
                const optionsArr = Array.from(targetSelect.options).slice(1);
                optionsArr.sort((a, b) => a.text.localeCompare(b.text));
                targetSelect.innerHTML = '<option value="">-- Chọn ga tàu điện ngầm --</option>';
                optionsArr.forEach(opt => targetSelect.add(opt));
            }
            break;

        case 'line':
            targetSelect.innerHTML = '<option value="">-- Chọn tuyến tàu điện ngầm --</option>';
            if (hasMapData) {
                const uniqueLines = new Set();
                kyotoGeoData.features.forEach(f => {
                    if (f.geometry && (f.geometry.type === 'LineString' || f.geometry.type === 'MultiLineString') && f.properties) {
                        if (f.properties.railway === 'subway' || f.properties.route === 'subway') {
                            const lineName = f.properties['name:en'] || f.properties.name || f.properties.ref;
                            if (lineName) uniqueLines.add(lineName);
                        }
                    }
                });
                uniqueLines.forEach(lineName => {
                    targetSelect.add(new Option(lineName, lineName.toLowerCase().replace(/\s+/g, '_')));
                });
            }
            if (targetSelect.options.length <= 1) {
                targetSelect.add(new Option("Karasuma Line (Tuyến Karasuma)", "karasuma_line"));
                targetSelect.add(new Option("Tozai Line (Tuyến Tozai)", "tozai_line"));
            }
            break;

        case 'trip':
            targetSelect.innerHTML = '<option value="">-- Chọn chuyến tàu điện ngầm --</option>';
            const mockTrips = [
                { id: "trip_k1", name: "Trip K1: Karasuma Morning Express (07:00)" },
                { id: "trip_k2", name: "Trip K2: Karasuma Local (08:15)" },
                { id: "trip_k3", name: "Trip K3: Karasuma Night Shift (23:00)" },
                { id: "trip_t1", name: "Trip T1: Tozai Rush Hour (17:30)" },
                { id: "trip_t2", name: "Trip T2: Tozai Evening (19:45)" }
            ];
            mockTrips.forEach(item => targetSelect.add(new Option(item.name, item.id)));
            break;

        case 'edge':
            targetSelect.innerHTML = '<option value="">-- Chọn đoạn ray điện ngầm --</option>';
            if (hasMapData) {
                const stationsList = getSubwayStations();
                const addedEdgeNames = new Set(); 

                kyotoGeoData.features.forEach(f => {
                    if (f.geometry && (f.geometry.type === 'LineString' || f.geometry.type === 'MultiLineString') && f.properties && f.properties.railway === 'subway') {
                        let lineName = f.properties['name:en'] || f.properties.name;
                        if (!lineName) {
                            const propStr = JSON.stringify(f.properties).toLowerCase();
                            lineName = propStr.includes('karasuma') || propStr.includes('烏丸') ? "Karasuma Line" : "Tozai Line";
                        }

                        let coords = f.geometry.coordinates;
                        if (f.geometry.type === 'MultiLineString') coords = coords[0];

                        if (coords && coords.length >= 2) {
                            const startPoint = coords[0];
                            const endPoint = coords[coords.length - 1];
                            
                            const stationA = getNearestStation(startPoint[0], startPoint[1], stationsList);
                            const stationB = getNearestStation(endPoint[0], endPoint[1], stationsList);

                            let edgeName = (stationA !== stationB) ? `${lineName} (${stationA} ➔ ${stationB})` : `${lineName} (Khu vực ga ${stationA})`;
                            const id = f.properties['@id'] || f.id || `edge_${Math.random()}`;

                            if (!addedEdgeNames.has(edgeName)) {
                                targetSelect.add(new Option(edgeName, id)); 
                                addedEdgeNames.add(edgeName);
                            }
                        }
                    }
                });
            }

            if (targetSelect.options.length <= 1) {
                console.warn("Kích hoạt Đoạn đường dự phòng do dữ liệu bản đồ trống!");
                fallbackEdges.forEach(ed => targetSelect.add(new Option(ed.name, ed.id)));
            } else {
                const optionsArr = Array.from(targetSelect.options).slice(1);
                optionsArr.sort((a, b) => a.text.localeCompare(b.text));
                targetSelect.innerHTML = '<option value="">-- Chọn đoạn ray điện ngầm --</option>';
                optionsArr.forEach(opt => targetSelect.add(opt));
            }
            break;
    }
}

async function postStatusEvent() {
    const type = document.getElementById('eventType').value;
    const targetId = document.getElementById('targetList').value;
    const status = document.getElementById('eventStatus').value;
    const msgDiv = document.getElementById('status-msg');

    if (!targetId) {
        msgDiv.innerText = " Vui lòng chọn đối tượng bị ảnh hưởng thực tế!";
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
        msgDiv.innerText = " Lỗi: Backend từ chối hoặc chưa thiết lập cấu hình Router này";
        msgDiv.style.color = "#e74c3c";
    }
}