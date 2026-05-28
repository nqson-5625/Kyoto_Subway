const API_BASE_URL = 'http://127.0.0.1:5000/api'; 

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
        eventTypeSelect.style.color = colors[eventTypeSelect.value] || 'white';
    });
    eventTypeSelect.dispatchEvent(new Event('change'));

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

        if (type === 'station' || type === 'edge') {
            const feature = kyotoGeoData.features.find(f => {
                const id = f.properties && f.properties['@id'] || f.id;
                return id === targetId;
            });

            if (feature) {
                if (type === 'station') {
                    L.geoJSON(feature, {
                        pointToLayer: function (feature, latlng) {
                            return L.circleMarker(latlng, { radius: 12, fillColor: "#f1c40f", color: "#fff", weight: 3, fillOpacity: 1 });
                        }
                    }).addTo(highlightLayer);
                } else if (type === 'edge') {
                    L.geoJSON(feature, {
                        style: { color: "#f1c40f", weight: 6, opacity: 1 }
                    }).addTo(highlightLayer);
                }
            }
        } 
        else if (type === 'line') {
            const lineFeatures = kyotoGeoData.features.filter(f => {
                if (f.geometry && (f.geometry.type === 'LineString' || f.geometry.type === 'MultiLineString') && f.properties) {
                    if (f.properties.railway === 'subway' || f.properties.route === 'subway') {
                        const propStr = JSON.stringify(f.properties).toLowerCase();
                        
                        if (targetId === 'karasuma_line' && propStr.includes('karasuma')) return true;
                        if (targetId === 'tozai_line' && propStr.includes('tozai')) return true;
                        
                        const lineName = f.properties['name:en'] || f.properties.name || f.properties.ref;
                        if (lineName) {
                            const genId = lineName.toLowerCase().replace(/\s+/g, '_');
                            if (genId === targetId) return true;
                        }
                    }
                }
                return false;
            });

            if (lineFeatures.length > 0) {
                L.geoJSON(lineFeatures, {
                    style: { color: "#f1c40f", weight: 6, opacity: 1 }
                }).addTo(highlightLayer);
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
                    if (!propStr.includes('karasuma') && !propStr.includes('tozai') && !propStr.includes('subway')) return;

                    const id = f.properties['@id'] || f.id;
                    if (addedStationIds.has(id)) return;

                    const displayName = f.properties['name:en'] || f.properties['name:ja-Latn'] || f.properties.name || `Station ID: ${id}`;
                    let lineTag = '';
                    if (propStr.includes('karasuma')) lineTag = ' [Karasuma Line]';
                    else if (propStr.includes('tozai')) lineTag = ' [Tozai Line]';

                    targetSelect.add(new Option(`${displayName}${lineTag}`, id));
                    addedStationIds.add(id);
                });

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

                if (uniqueLines.size > 0) {
                    uniqueLines.forEach(lineName => {
                        targetSelect.add(new Option(lineName, lineName.toLowerCase().replace(/\s+/g, '_')));
                    });
                } else {
                    targetSelect.add(new Option("Karasuma Line", "karasuma_line"));
                    targetSelect.add(new Option("Tozai Line", "tozai_line"));
                }
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
                const stationsList = [];
                kyotoGeoData.features.forEach(f => {
                    if (f.geometry && f.geometry.type === 'Point' && f.properties && (f.properties.railway === 'station' || f.properties.public_transport === 'station')) {
                        const propStr = JSON.stringify(f.properties).toLowerCase();
                        if (propStr.includes('karasuma') || propStr.includes('tozai') || propStr.includes('subway')) {
                            stationsList.push({
                                name: f.properties['name:en'] || f.properties['name:ja-Latn'] || f.properties.name || "Unknown",
                                lng: f.geometry.coordinates[0],
                                lat: f.geometry.coordinates[1]
                            });
                        }
                    }
                });

                const getNearestStation = (lng, lat) => {
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
                };

                let count = 0;
                const addedEdgeNames = new Set();

                kyotoGeoData.features.forEach(f => {
                    if (f.geometry && (f.geometry.type === 'LineString' || f.geometry.type === 'MultiLineString') && f.properties && f.properties.railway === 'subway') {
                        
                        let lineName = f.properties['name:en'] || f.properties.name;
                        if (!lineName) {
                            const propStr = JSON.stringify(f.properties).toLowerCase();
                            if (propStr.includes('karasuma')) lineName = "Karasuma Line";
                            else if (propStr.includes('tozai')) lineName = "Tozai Line";
                            else lineName = "Subway Track";
                        }

                        let coords = f.geometry.coordinates;
                        if (f.geometry.type === 'MultiLineString') coords = coords[0];

                        if (coords && coords.length >= 2) {
                            const startPoint = coords[0];
                            const endPoint = coords[coords.length - 1];
                            
                            const stationA = getNearestStation(startPoint[0], startPoint[1]);
                            const stationB = getNearestStation(endPoint[0], endPoint[1]);

                            const id = f.properties['@id'] || f.id || `subway_edge_${count++}`;
                            let edgeName = "";
                            
                            if (stationA !== stationB) {
                                edgeName = `${lineName} (${stationA} ➔ ${stationB})`;
                            } else {
                                edgeName = `${lineName} (Khu vực ga ${stationA})`; 
                            }

                            if (!addedEdgeNames.has(edgeName)) {
                                targetSelect.add(new Option(edgeName, id));
                                addedEdgeNames.add(edgeName);
                            }
                        }
                    }
                });
                
                const optionsArr = Array.from(targetSelect.options).slice(1);
                optionsArr.sort((a, b) => a.text.localeCompare(b.text));
                targetSelect.innerHTML = '<option value="">-- Chọn đoạn ray điện ngầm --</option>';
                optionsArr.forEach(opt => targetSelect.add(opt));

                if (targetSelect.options.length <= 1) {
<<<<<<< HEAD
                    targetSelect.innerHTML = '<option value="">Bản đồ không có đoạn ray subway độc lập</option>';
=======
                    targetSelect.innerHTML = '<option value=""> Bản đồ không có đoạn ray subway độc lập</option>';
>>>>>>> 71b85543e60e56fc773abae5e693c7ee5d1ba7a5
                }
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
        msgDiv.innerText = "Vui lòng chọn đối tượng bị ảnh hưởng thực tế!";
        msgDiv.style.color = "#f1c40f";
        return;
    }

    msgDiv.innerText = "Đang truyền tín hiệu tới server...";
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
            msgDiv.innerText = "Cập nhật hệ thống thành công!";
            msgDiv.style.color = "#2ecc71";
        } else {
            throw new Error();
        }
    } catch (err) {
        msgDiv.innerText = "Lỗi: Backend từ chối hoặc chưa thiết lập cấu hình Router này";
        msgDiv.style.color = "#e74c3c";
    }
}
