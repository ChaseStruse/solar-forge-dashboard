import QtQuick

// A rotating, sun-lit world. Each `kind` paints its own surface; every kind
// shares the night-side terminator, sun-facing rim light, and atmosphere.
//   ringed  — banded giant whose ring fills with `progress`
//   gas     — wavy cloud bands and a drifting storm (red on `alert`)
//   holo    — wireframe globe with an orbiting satellite
//   lava    — dark crust whose fissures glow with `heat`
//   ice     — pale world emitting signal waves scaled by `progress`
//   crater  — cratered moon with outpost lights on its night side
//   dots    — rotating point-cloud data globe
Item {
    id: root
    required property DashboardTheme theme
    property string kind: "gas"
    property real lightAngle: 0
    property real progress: -1
    property real heat: 0
    property bool alert: false
    property bool animating: true
    property real spin: 0

    readonly property var tilts: ({ ringed: 0.35, gas: 0.2, holo: 0.4, lava: 0.25, ice: 0.3, crater: 0.15, dots: 0.45 })
    readonly property var speeds: ({ ringed: 0.3, gas: 0.35, holo: 0.6, lava: 0.22, ice: 0.3, crater: 0.18, dots: 0.5 })

    // Seeded features so every redraw shows the same geography.
    function seeded(seed, count, mapper) {
        var s = seed, out = [];
        function rand() { s = (s * 16807) % 2147483647; return s / 2147483647; }
        for (var i = 0; i < count; i++) out.push(mapper(rand, i));
        return out;
    }
    readonly property var hotspots: seeded(11, 22, function(rand) {
        return { lat: (rand() - 0.5) * 2.6, lon: rand() * Math.PI * 2, size: 0.08 + rand() * 0.14, flicker: rand() * 6 };
    })
    readonly property var craters: seeded(29, 16, function(rand) {
        return { lat: (rand() - 0.5) * 2.8, lon: rand() * Math.PI * 2, size: 0.07 + rand() * 0.16 };
    })
    readonly property var outposts: seeded(53, 30, function(rand) {
        return { lat: (rand() - 0.5) * 2.4, lon: rand() * Math.PI * 2 };
    })
    readonly property var cloud: seeded(7, 150, function(rand, i) {
        // Fibonacci sphere for an even point cloud.
        return { lat: Math.asin(1 - 2 * (i + 0.5) / 150), lon: i * 2.39996, glow: rand() };
    })

    Timer {
        interval: 40
        repeat: true
        running: root.animating && root.visible
        onTriggered: root.spin = (root.spin + 0.04 * (root.speeds[root.kind] || 0.3)) % (Math.PI * 200)
    }

    Canvas {
        id: art
        anchors.centerIn: parent
        width: root.width * 2.4
        height: width
        property real spin: root.spin
        property real lightAngle: root.lightAngle
        property color ink: root.theme.accentColor
        property color second: root.theme.secondaryAccentColor
        property color hot: root.theme.urgentColor
        property color shade: root.theme.backgroundColor
        property color fore: root.theme.foregroundColor
        onSpinChanged: requestPaint()
        onLightAngleChanged: requestPaint()
        onInkChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var c = getContext("2d");
            c.reset();
            var m = width / 2, r = root.width / 2 - 1;
            if (r < 4) return;
            var kind = root.kind, tilt = root.tilts[kind] || 0.3, sp = spin;
            var lx = Math.cos(lightAngle), ly = Math.sin(lightAngle);
            var T = root.theme;

            function rgba(col, a) { return Qt.rgba(col.r, col.g, col.b, a); }
            function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1); }
            // Orthographic projection with axial tilt; z > 0 faces the viewer.
            function project(lat, lon, radius) {
                var R = radius || r;
                var cl = Math.cos(lat), x = cl * Math.sin(lon + sp), y = Math.sin(lat), z = cl * Math.cos(lon + sp);
                var y2 = y * Math.cos(tilt) - z * Math.sin(tilt), z2 = y * Math.sin(tilt) + z * Math.cos(tilt);
                return { x: m + x * R, y: m - y2 * R, z: z2 };
            }
            function circle() { c.beginPath(); c.arc(m, m, r, 0, Math.PI * 2); }

            var base = kind === "ringed" ? second
                : kind === "gas" ? mix(ink, second, 0.55)
                : kind === "holo" ? ink
                : kind === "lava" ? mix(shade, hot, 0.22)
                : kind === "ice" ? mix(ink, fore, 0.55)
                : kind === "crater" ? mix(mix(second, fore, 0.35), shade, 0.35)
                : mix(ink, second, 0.3);

            // Atmosphere halo, brighter on the sun side.
            var halo = c.createRadialGradient(m + lx * r * 0.25, m + ly * r * 0.25, r * 0.9, m, m, r * 1.45);
            halo.addColorStop(0, rgba(kind === "lava" ? hot : base, kind === "holo" || kind === "dots" ? 0.28 : 0.35));
            halo.addColorStop(1, rgba(base, 0));
            c.fillStyle = halo;
            c.fillRect(0, 0, width, height);

            // Ring geometry (ringed): back half drawn now, front half after the body.
            var ringA = 1.75 * r, ringB = 0.42 * r, ringRot = -0.32;
            function ring(front) {
                c.save();
                c.translate(m, m);
                c.rotate(ringRot);
                var bands = [[1.25, 0.18], [1.48, 0.1], [1.66, 0.05]];
                for (var b = 0; b < bands.length; b++) {
                    var k = bands[b][0] / 1.75;
                    c.beginPath();
                    c.ellipse(-ringA * k, -ringB * k, ringA * k * 2, ringB * k * 2);
                    c.lineWidth = r * bands[b][1];
                    c.strokeStyle = rgba(mix(ink, fore, 0.2), front ? 0.55 : 0.25);
                    c.stroke();
                }
                // Completion arc rides the outer band.
                if (root.progress >= 0) {
                    var start = front ? 0 : Math.PI, span = Math.PI;
                    var filled = Math.max(0, Math.min(1, root.progress * 2 - (front ? 0 : 1)));
                    if (filled > 0) {
                        c.beginPath();
                        var steps = 40;
                        for (var i = 0; i <= steps; i++) {
                            var a = start + span * filled * i / steps;
                            var px = Math.cos(a) * ringA * 0.95, py = Math.sin(a) * ringB * 0.95;
                            if (i === 0) c.moveTo(px, py); else c.lineTo(px, py);
                        }
                        c.lineWidth = r * 0.09;
                        c.strokeStyle = rgba(Qt.lighter(ink, 1.4), front ? 1 : 0.5);
                        c.stroke();
                    }
                }
                c.restore();
            }
            if (kind === "ringed") {
                // Far half of the ring (above the ring plane), behind the body.
                c.save();
                c.beginPath();
                c.translate(m, m); c.rotate(ringRot); c.rect(-width, -height, width * 2, height); c.rotate(-ringRot); c.translate(-m, -m);
                c.clip();
                ring(false);
                c.restore();
            }

            // ---- Body ----
            c.save();
            circle();
            c.clip();
            var body = c.createRadialGradient(m + lx * r * 0.4, m + ly * r * 0.4, 0, m, m, r);
            body.addColorStop(0, Qt.lighter(base, kind === "lava" ? 1.1 : 1.35));
            body.addColorStop(1, mix(base, shade, 0.55));
            c.fillStyle = kind === "holo" || kind === "dots" ? rgba(mix(base, shade, 0.85), 0.75) : body;
            c.fillRect(0, 0, width, height);

            if (kind === "ringed" || kind === "gas") {
                var bandsN = kind === "gas" ? 9 : 6;
                for (var k = 0; k < bandsN; k++) {
                    var y0 = m - r + (2 * r) * k / bandsN;
                    c.beginPath();
                    c.moveTo(m - r, y0);
                    for (var x = -r; x <= r; x += r / 10) {
                        var wave = kind === "gas" ? Math.sin(x / r * 3 + sp * 2 + k * 1.7) * r * 0.05 : 0;
                        c.lineTo(m + x, y0 + wave);
                    }
                    c.lineTo(m + r, y0 + 2 * r / bandsN);
                    c.lineTo(m - r, y0 + 2 * r / bandsN);
                    c.closePath();
                    var tone = k % 3 === 0 ? ink : k % 3 === 1 ? second : fore;
                    c.fillStyle = rgba(tone, kind === "gas" ? 0.16 + (k % 2) * 0.1 : 0.1);
                    c.fill();
                }
                if (kind === "gas") {
                    var storm = project(-0.4, 0.6);
                    if (storm.z > 0) {
                        c.beginPath();
                        c.ellipse(storm.x - r * 0.22 * storm.z, storm.y - r * 0.1, r * 0.44 * storm.z, r * 0.2);
                        c.fillStyle = rgba(root.alert ? hot : Qt.lighter(second, 1.3), 0.75);
                        c.fill();
                        c.lineWidth = 1.5;
                        c.strokeStyle = rgba(fore, 0.4);
                        c.stroke();
                    }
                }
            } else if (kind === "holo") {
                c.lineWidth = 1;
                for (var mer = 0; mer < 12; mer++) {
                    var lon = mer * Math.PI / 6;
                    for (var seg = 0; seg < 2; seg++) {
                        c.beginPath();
                        var started = false, frontSeg = seg === 0;
                        for (var lat = -Math.PI / 2; lat <= Math.PI / 2 + 0.01; lat += Math.PI / 18) {
                            var p = project(lat, lon);
                            if ((p.z >= 0) !== frontSeg) { started = false; continue; }
                            if (!started) { c.moveTo(p.x, p.y); started = true; } else c.lineTo(p.x, p.y);
                        }
                        c.strokeStyle = rgba(Qt.lighter(ink, 1.3), frontSeg ? 0.85 : 0.18);
                        c.stroke();
                    }
                }
                for (var la = -2; la <= 2; la++) {
                    var latL = la * Math.PI / 6;
                    c.beginPath();
                    for (var lo = 0; lo <= Math.PI * 2 + 0.01; lo += Math.PI / 24) {
                        var q = project(latL, lo);
                        if (lo === 0) c.moveTo(q.x, q.y); else c.lineTo(q.x, q.y);
                    }
                    c.strokeStyle = rgba(ink, la === 0 ? 0.7 : 0.35);
                    c.stroke();
                }
            } else if (kind === "lava") {
                var glow = 0.35 + root.heat * 0.65;
                // Fissures between neighbouring hotspots.
                c.lineWidth = Math.max(1, r * 0.04);
                for (var h = 0; h < root.hotspots.length - 1; h += 2) {
                    var a1 = project(root.hotspots[h].lat, root.hotspots[h].lon);
                    var a2 = project(root.hotspots[h + 1].lat, root.hotspots[h].lon + 0.5);
                    if (a1.z < 0 && a2.z < 0) continue;
                    c.beginPath(); c.moveTo(a1.x, a1.y); c.lineTo((a1.x + a2.x) / 2 + r * 0.05, (a1.y + a2.y) / 2); c.lineTo(a2.x, a2.y);
                    c.strokeStyle = rgba(Qt.lighter(hot, 1.3), 0.5 * glow * Math.max(0.2, Math.min(a1.z, a2.z) + 0.6));
                    c.stroke();
                }
                for (var hs = 0; hs < root.hotspots.length; hs++) {
                    var spot = root.hotspots[hs], pp = project(spot.lat, spot.lon);
                    if (pp.z <= 0) continue;
                    var flick = 0.75 + 0.25 * Math.sin(sp * 9 + spot.flicker);
                    var g = c.createRadialGradient(pp.x, pp.y, 0, pp.x, pp.y, r * spot.size * (0.5 + pp.z * 0.6));
                    g.addColorStop(0, rgba(Qt.lighter(hot, 1.8), glow * flick));
                    g.addColorStop(0.4, rgba(hot, 0.7 * glow * flick));
                    g.addColorStop(1, rgba(hot, 0));
                    c.fillStyle = g;
                    c.fillRect(pp.x - r, pp.y - r, r * 2, r * 2);
                }
            } else if (kind === "ice") {
                for (var st = -3; st <= 3; st++) {
                    c.beginPath();
                    for (var li = 0; li <= Math.PI * 2 + 0.01; li += Math.PI / 20) {
                        var ip = project(st * 0.38 + Math.sin(li * 3) * 0.05, li);
                        if (li === 0) c.moveTo(ip.x, ip.y); else c.lineTo(ip.x, ip.y);
                    }
                    c.strokeStyle = rgba(fore, 0.18);
                    c.lineWidth = 1;
                    c.stroke();
                }
                // Polar cap
                var cap = c.createRadialGradient(m, m - r * 0.95, 0, m, m - r * 0.95, r * 0.6);
                cap.addColorStop(0, rgba(fore, 0.7));
                cap.addColorStop(1, rgba(fore, 0));
                c.fillStyle = cap;
                c.fillRect(0, 0, width, height);
            } else if (kind === "crater") {
                for (var cr = 0; cr < root.craters.length; cr++) {
                    var k2 = root.craters[cr], cp = project(k2.lat, k2.lon);
                    if (cp.z <= 0.05) continue;
                    var rx = r * k2.size, ry = rx * (0.35 + cp.z * 0.65);
                    c.beginPath();
                    c.ellipse(cp.x - rx, cp.y - ry, rx * 2, ry * 2);
                    c.fillStyle = rgba(shade, 0.5);
                    c.fill();
                    // Lit crater wall faces away from the sun.
                    c.beginPath();
                    c.ellipse(cp.x - rx - lx * rx * 0.25, cp.y - ry - ly * ry * 0.25, rx * 2, ry * 2);
                    c.lineWidth = Math.max(1, r * 0.03);
                    c.strokeStyle = rgba(fore, 0.3);
                    c.stroke();
                }
            } else if (kind === "dots") {
                for (var d = 0; d < root.cloud.length; d++) {
                    var dp = project(root.cloud[d].lat, root.cloud[d].lon);
                    var front = dp.z > 0;
                    var size = (front ? 1 + dp.z * 1.4 : 0.8) * Math.max(0.6, r / 30);
                    c.fillStyle = rgba(root.cloud[d].glow > 0.85 ? second : Qt.lighter(ink, 1.3), front ? 0.35 + dp.z * 0.6 : 0.12);
                    c.fillRect(dp.x - size / 2, dp.y - size / 2, size, size);
                }
            }

            // Night side: terminator gradient away from the sun.
            var night = c.createLinearGradient(m + lx * r, m + ly * r, m - lx * r, m - ly * r);
            var nightStrength = kind === "holo" || kind === "dots" ? 0.5 : 0.8;
            night.addColorStop(0, rgba(shade, 0));
            night.addColorStop(0.45, rgba(shade, 0.15));
            night.addColorStop(1, rgba(shade, nightStrength));
            c.fillStyle = night;
            c.fillRect(0, 0, width, height);

            // Outpost lights glitter only on the night side.
            if (kind === "crater") {
                for (var o = 0; o < root.outposts.length; o++) {
                    var op = project(root.outposts[o].lat, root.outposts[o].lon);
                    if (op.z <= 0) continue;
                    var dark = -((op.x - m) * lx + (op.y - m) * ly) / r;
                    if (dark < 0.15) continue;
                    c.fillStyle = rgba(Qt.lighter(ink, 1.5), Math.min(1, dark) * 0.9);
                    c.fillRect(op.x - 1, op.y - 1, 2, 2);
                }
            }
            c.restore();

            // Rim light on the sun-facing limb: brightest at the sub-solar
            // point, fading toward the terminator.
            var rimTone = Qt.lighter(kind === "lava" ? hot : base, 1.35);
            for (var seg2 = -6; seg2 < 6; seg2++) {
                var a0 = lightAngle + seg2 * 0.2, fade = 1 - Math.abs(seg2 + 0.5) / 6.5;
                c.beginPath();
                c.arc(m, m, r - 0.5, a0, a0 + 0.21);
                c.lineWidth = Math.max(1, r * 0.035);
                c.strokeStyle = rgba(rimTone, 0.75 * fade);
                c.stroke();
            }

            if (kind === "ringed") {
                c.save();
                c.beginPath();
                c.translate(m, m); c.rotate(ringRot); c.rect(-width, 0, width * 2, height); c.rotate(-ringRot); c.translate(-m, -m);
                c.clip();
                ring(true);
                c.restore();
            } else if (kind === "holo") {
                // Satellite on a tilted orbit, hidden while behind the globe.
                var sa = sp * 3.2, sx = Math.cos(sa) * r * 1.55, sy = Math.sin(sa) * r * 0.45;
                var behind = Math.sin(sa) < 0 && Math.hypot(sx, sy) < r;
                if (!behind) {
                    for (var tr = 6; tr >= 0; tr--) {
                        var ta = sa - tr * 0.09;
                        c.fillStyle = rgba(Qt.lighter(ink, 1.5), tr === 0 ? 1 : 0.4 * (1 - tr / 7));
                        var ts = tr === 0 ? Math.max(2.5, r * 0.12) : Math.max(1.5, r * 0.06);
                        c.fillRect(m + Math.cos(ta) * r * 1.55 - ts / 2, m + Math.sin(ta) * r * 0.45 - ts / 2, ts, ts);
                    }
                }
            } else if (kind === "ice") {
                // Signal waves radiating outward; strength tracks the uplink.
                var strength = root.progress < 0 ? 0.15 : root.progress;
                for (var wv = 0; wv < 3; wv++) {
                    var t = ((sp * 0.9 + wv / 3) % 1 + 1) % 1;
                    c.beginPath();
                    c.arc(m, m, r * (1.05 + t * 0.85), lightAngle + Math.PI - 0.7, lightAngle + Math.PI + 0.7);
                    c.lineWidth = Math.max(1, r * 0.05);
                    c.strokeStyle = rgba(root.progress < 0 ? hot : Qt.lighter(ink, 1.4), (1 - t) * 0.8 * (0.3 + strength * 0.7));
                    c.stroke();
                }
            }
        }
    }
}
