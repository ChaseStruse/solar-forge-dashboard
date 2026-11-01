import QtQuick
import QtQuick.Controls
import qs.Commons

// Projected solar system: static painted lighting, scene-graph orbital motion.
// The sun is the system's heat gauge; when a module is open the whole core
// docks beside it as a navigator.
Item {
    id: root
    required property DashboardTheme theme
    required property SystemReadinessSource readinessSource
    required property GitHubSource githubSource
    property bool animating: false
    property bool pointerPaused: false
    onAnimatingChanged: if (!animating) pointerPaused = false
    property real corePhase: 0
    property int selectedModule: -1
    property bool docked: false
    // Upper bound for the orbit chamber; fullscreen layouts raise it.
    property real maxChamber: 860
    // 0 → 1 during ignition: the sun swells and planets fly out to orbit.
    property real ignition: 1
    signal moduleSelected(int module)
    signal moduleNavigated(int module)
    signal moduleOpened(int module)
    readonly property real orbitTilt: 0.42
    readonly property real innerModuleOrbit: 0.33
    readonly property real outerModuleOrbit: 0.45
    readonly property real chamberSize: Math.min(width, maxChamber)
    // The tilted orbit is wide and shallow; a square chamber wastes the top
    // and bottom thirds. Docked cores stay square to fit the narrow column.
    readonly property real chamberHeight: docked ? chamberSize * 0.82 : chamberSize * 0.6
    readonly property real sunCanvasSize: Math.min(chamberSize * 0.5, Math.max(256, chamberSize * 0.3))
    implicitHeight: chamberHeight + (docked ? satelliteIndex.implicitHeight + 16 : 50)
    focus: true

    readonly property var modules: [
        { name: "OBJECTIVES", key: "T", glyph: "", kind: "ringed" },
        { name: "GITHUB INTEL", key: "G", glyph: "", kind: "gas" },
        { name: "LAUNCH CONTROL", key: "L", glyph: "󱓞", kind: "holo" },
        { name: "REACTOR", key: "R", glyph: "󰈸", kind: "lava" },
        { name: "COMMS ARRAY", key: "C", glyph: "󰖩", kind: "ice" },
        { name: "SUPPLY DEPOT", key: "D", glyph: "󰏗", kind: "crater" },
        { name: "KEYBIND CODEX", key: "K", glyph: "󰌌", kind: "dots" }
    ]
    // Per-planet telemetry supplied by the dashboard:
    // { badge: string, alert: bool, progress: 0..1 or -1, detail: string }
    property var planetStates: []
    function planetState(index) {
        return planetStates[index] || { badge: "", alert: false, progress: -1, detail: "" };
    }
    // Space in the core jumps straight to this module, like SUPER + SPACE.
    property int launcherModule: 2

    // 0 = idle, 1 = critical. Load drives the base; active warnings add heat.
    readonly property real heat: {
        var s = readinessSource;
        var load = Math.max(s.cpuPercent, s.gpuPercent, 0) / 100;
        var thermal = s.gpuTemperature > 0 ? Math.max(0, (s.gpuTemperature - 50) / 40) : 0;
        return Math.max(0, Math.min(1, Math.max(load, thermal) + s.warningCount * 0.18));
    }
    readonly property string forgeState: heat >= 0.75 ? "CRITICAL" : heat >= 0.45 ? "ELEVATED" : "STABLE"
    readonly property color sunColor: theme.mix(theme.accentColor, theme.urgentColor, Math.max(0, heat - 0.25) / 0.75)
    property real surfaceAngle: 0
    property real pulsePhase: 0

    function ignite() {
        ignitionAnim.restart();
    }
    NumberAnimation {
        id: ignitionAnim
        target: root
        property: "ignition"
        from: 0
        to: 1
        duration: 1800
        easing.type: Easing.OutBack
        easing.overshoot: 1.2
    }

    function focusPicker() {
        forceActiveFocus();
    }

    function orbitX(angle, radius) {
        return chamber.width / 2 + Math.cos(angle) * radius;
    }

    function orbitY(angle, radius) {
        return chamber.height / 2 + Math.sin(angle) * radius * orbitTilt;
    }

    // Even modules ride the inner orbit until it holds half (rounded down);
    // the rest fill the outer orbit. Integer speeds keep the loop seamless.
    readonly property int innerCount: Math.floor(modules.length / 2)
    function isInner(index) {
        return index % 2 === 0 && index / 2 < innerCount;
    }
    function orbitSlot(index) {
        if (isInner(index))
            return index / 2;
        var slot = 0;
        for (var i = 0; i < index; i++)
            if (!isInner(i)) slot++;
        return slot;
    }
    function planetOrbit(index) {
        return chamber.width * (isInner(index) ? innerModuleOrbit : outerModuleOrbit) * ignition;
    }
    function planetAngle(index, phase) {
        var inner = isInner(index);
        var count = inner ? innerCount : modules.length - innerCount;
        return phase * (inner ? 2 : 1) + orbitSlot(index) * Math.PI * 2 / count + (inner ? 0 : Math.PI / count);
    }

    // Selected planet centre in this item's coordinates, for the conduit.
    readonly property point selectedPoint: selectedModule < 0 ? Qt.point(width / 2, chamber.height / 2)
        : Qt.point(chamber.x + orbitX(planetAngle(selectedModule, corePhase), planetOrbit(selectedModule)),
                   chamber.y + orbitY(planetAngle(selectedModule, corePhase), planetOrbit(selectedModule)))

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
            root.moduleNavigated((root.selectedModule + root.modules.length - 1) % root.modules.length);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
            root.moduleNavigated((root.selectedModule + 1) % root.modules.length);
            event.accepted = true;
        } else if (event.key === Qt.Key_Space) {
            root.moduleOpened(root.launcherModule);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.selectedModule >= 0)
                root.moduleOpened(root.selectedModule);
            event.accepted = true;
        } else {
            for (var i = 0; i < modules.length; i++) {
                if (event.text.toUpperCase() === modules[i].key) {
                    if (!event.isAutoRepeat) root.moduleSelected(i);
                    event.accepted = true;
                    return;
                }
            }
        }
    }

    // Integer phase multiples all meet at the loop boundary.
    NumberAnimation on corePhase {
        from: 0; to: Math.PI * 2
        duration: 60000
        loops: Animation.Infinite
        running: true
        paused: !root.animating || root.pointerPaused
    }

    // Heat-scaled motion: hotter cores churn and breathe faster.
    FrameAnimation {
        running: root.animating
        onTriggered: {
            root.surfaceAngle = (root.surfaceAngle + frameTime * (8 + root.heat * 110)) % 360;
            root.pulsePhase = (root.pulsePhase + frameTime * (1.1 + root.heat * 5)) % (Math.PI * 2);
        }
    }

    Item {
        id: chamber
        width: root.chamberSize
        height: root.chamberHeight
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
            model: 48
            Rectangle {
                required property int index
                width: index % 9 === 0 ? 2 : 1
                height: width
                radius: width / 2
                x: ((index * 47) % 101) / 101 * chamber.width
                y: ((index * 71) % 103) / 103 * chamber.height
                color: root.theme.foregroundColor
                opacity: 0.08 + (1 + Math.sin(root.corePhase * 2 + index)) * 0.06
                z: -3
            }
        }

        // Perspective deck grid beneath the orbital plane.
        Canvas {
            anchors.fill: parent
            opacity: Math.max(0, Math.min(1, root.ignition))
            z: -2.5
            property color ink: root.theme.accentColor
            onInkChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var c = getContext("2d");
                c.reset();
                var cx = width / 2, cy = height / 2, rx = width * 0.5, ry = rx * root.orbitTilt;
                c.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 1);
                c.lineWidth = 1;
                for (var k = 1; k <= 7; k++) {
                    var t = k / 7;
                    c.globalAlpha = 0.07 * (1 - t * 0.6);
                    c.beginPath();
                    c.ellipse(cx - rx * t, cy - ry * t, rx * t * 2, ry * t * 2);
                    c.stroke();
                }
                for (var s = 0; s < 24; s++) {
                    var a = s * Math.PI / 12;
                    c.globalAlpha = s % 6 === 0 ? 0.1 : 0.045;
                    c.beginPath();
                    c.moveTo(cx + Math.cos(a) * rx * 0.2, cy + Math.sin(a) * ry * 0.2);
                    c.lineTo(cx + Math.cos(a) * rx, cy + Math.sin(a) * ry);
                    c.stroke();
                }
            }
        }

        // Static tracks share the same projection and radii as their nodes.
        Canvas {
            anchors.fill: parent
            opacity: Math.max(0, Math.min(1, root.ignition))
            z: -2
            property color ink: root.theme.accentColor
            onInkChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var c = getContext("2d");
                c.reset();
                for (var ring of [0.24, root.innerModuleOrbit, root.outerModuleOrbit]) {
                    for (var front = 0; front < 2; front++) {
                        c.beginPath();
                        for (var i = 0; i <= 100; i++) {
                            var a = Math.PI * (front + i / 100);
                            var x = root.orbitX(a, width * ring);
                            var y = root.orbitY(a, width * ring);
                            if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
                        }
                        c.strokeStyle = ink;
                        c.globalAlpha = front === 0 ? 0.38 : 0.12;
                        c.lineWidth = 1;
                        c.stroke();
                    }
                }
            }
        }

        // Paint the corona and luminous sphere; colour tracks heat, scale
        // breathes with it, and the texture spins faster as load climbs.
        Item {
            id: sunBody
            width: root.sunCanvasSize
            height: width
            anchors.centerIn: parent
            z: 0
            scale: (0.25 + 0.75 * Math.min(1, root.ignition)) * (1 + Math.sin(root.pulsePhase) * (0.015 + root.heat * 0.045))

            Canvas {
                id: sun
                anchors.fill: parent
                property color ink: root.sunColor
                Behavior on ink { ColorAnimation { duration: 1400 } }
                onInkChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d");
                    c.reset();
                    var m = width / 2, r = width * 0.19;
                    var halo = c.createRadialGradient(m, m, r * 0.65, m, m, m);
                    halo.addColorStop(0, Qt.rgba(ink.r, ink.g, ink.b, 0.7));
                    halo.addColorStop(0.36, Qt.rgba(ink.r, ink.g, ink.b, 0.22));
                    halo.addColorStop(1, Qt.rgba(ink.r, ink.g, ink.b, 0));
                    c.fillStyle = halo;
                    c.fillRect(0, 0, width, height);
                    var surface = c.createRadialGradient(m-r*0.3, m-r*0.3, 0, m, m, r);
                    surface.addColorStop(0, Qt.lighter(ink, 2.8));
                    surface.addColorStop(0.42, Qt.lighter(ink, 1.9));
                    surface.addColorStop(0.78, Qt.lighter(ink, 1.35));
                    surface.addColorStop(1, ink);
                    c.beginPath(); c.arc(m, m, r, 0, Math.PI * 2);
                    c.fillStyle = surface; c.fill();
                }
            }
            Canvas {
                width: parent.width * 0.38
                height: width
                anchors.centerIn: parent
                rotation: root.surfaceAngle
                opacity: 0.13 + root.heat * 0.2
                property color ink: root.sunColor
                onInkChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d"); c.reset();
                    for (var i = 0; i < 65; i++) {
                        var a = i * 2.39996, r = Math.sqrt(i / 65) * width * 0.46;
                        c.beginPath();
                        c.arc(width/2 + Math.cos(a)*r, height/2 + Math.sin(a)*r,
                              0.7 + i % 3 * 0.4, 0, Math.PI*2);
                        c.fillStyle = i % 2 ? Qt.lighter(ink, 2.4) : Qt.darker(ink, 1.5); c.fill();
                    }
                }
            }
        }

        // Flares: an expanding shockwave for each active warning.
        Repeater {
            model: Math.min(3, root.readinessSource.warningCount)
            Rectangle {
                id: flare
                required property int index
                anchors.centerIn: parent
                width: root.sunCanvasSize * 0.4
                height: width
                radius: width / 2
                color: "transparent"
                border.color: root.theme.urgentColor
                border.width: 2
                opacity: 0
                z: 0.2
                SequentialAnimation {
                    running: root.animating
                    loops: Animation.Infinite
                    PauseAnimation { duration: flare.index * 700 }
                    ParallelAnimation {
                        NumberAnimation { target: flare; property: "scale"; from: 0.6; to: 2.4; duration: 2100; easing.type: Easing.OutCubic }
                        NumberAnimation { target: flare; property: "opacity"; from: 0.7; to: 0; duration: 2100; easing.type: Easing.OutQuad }
                    }
                    PauseAnimation { duration: (2 - flare.index) * 700 }
                }
            }
        }

        ReadinessRing {
            opacity: Math.max(0, Math.min(1, root.ignition))
            width: Math.min(chamber.width * 0.43, Math.max(292, chamber.width * 0.33))
            height: width
            anchors.centerIn: parent
            z: 0.5
            theme: root.theme
            source: root.readinessSource
        }
        ReadinessRing {
            opacity: Math.max(0, Math.min(1, root.ignition))
            width: Math.min(chamber.width * 0.43, Math.max(292, chamber.width * 0.33))
            height: width
            anchors.centerIn: parent
            z: 3
            theme: root.theme
            source: root.readinessSource
            labelLayer: true
            // Docked cores are too small for readouts; arcs carry the state.
            visible: !root.docked
        }

        Repeater {
            model: 6
            Rectangle {
                required property int index
                readonly property real angle: root.corePhase * 2 + index * Math.PI * 2 / 6
                width: 5 + index
                height: width
                radius: width / 2
                x: root.orbitX(angle, chamber.width * 0.24 * root.ignition) - width / 2
                y: root.orbitY(angle, chamber.width * 0.24 * root.ignition) - height / 2
                z: Math.sin(angle) < 0 ? -1 : 1
                scale: 0.85 + Math.sin(angle) * 0.15
                color: root.theme.secondaryAccentColor
                opacity: 0.65 + Math.sin(angle) * 0.2
            }
        }

        Repeater {
            model: root.modules.length
            Item {
                id: planet
                required property int index
                readonly property real orbitRadius: root.planetOrbit(index)
                readonly property real angle: root.planetAngle(index, root.corePhase)
                readonly property real depth: Math.sin(angle)
                readonly property bool selected: root.selectedModule === index
                readonly property var status: root.planetState(index)
                width: Math.min(88, Math.max(root.docked ? 34 : 44, chamber.width * 0.078))
                height: width
                x: root.orbitX(angle, orbitRadius) - width / 2
                y: root.orbitY(angle, orbitRadius) - height / 2
                z: depth < 0 ? -1 : 2
                scale: 0.9 + depth * 0.13
                opacity: 0.82 + depth * 0.16
                // Distress pulse: expanding urgent ring while the module needs you.
                Rectangle {
                    id: distress
                    anchors.centerIn: parent
                    width: parent.width
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: root.theme.urgentColor
                    border.width: 2
                    visible: planet.status.alert
                    opacity: 0
                    SequentialAnimation {
                        running: distress.visible && root.animating
                        loops: Animation.Infinite
                        ParallelAnimation {
                            NumberAnimation { target: distress; property: "scale"; from: 1; to: 1.9; duration: 1300; easing.type: Easing.OutCubic }
                            NumberAnimation { target: distress; property: "opacity"; from: 0.9; to: 0; duration: 1300 }
                        }
                        PauseAnimation { duration: 500 }
                    }
                }
                Planet {
                    anchors.fill: parent
                    theme: root.theme
                    kind: root.modules[planet.index].kind
                    // Direction from this planet toward the sun, for lighting.
                    lightAngle: Math.atan2(chamber.height / 2 - planet.y - planet.height / 2,
                                           chamber.width / 2 - planet.x - planet.width / 2)
                    progress: planet.status.progress
                    heat: root.heat
                    alert: planet.status.alert
                    animating: root.animating
                }
                // Targeting reticle: spinning dashed ring with corner ticks.
                Item {
                    anchors.fill: parent
                    anchors.margins: -9
                    opacity: planet.selected ? 1 : pointer.containsMouse ? 0.55 : 0
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                    Canvas {
                        anchors.fill: parent
                        rotation: root.corePhase * 180 / Math.PI * 6
                        property color ink: root.theme.secondaryAccentColor
                        onInkChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.reset();
                            var m = width / 2;
                            c.strokeStyle = ink; c.lineWidth = 1.5;
                            for (var q = 0; q < 4; q++) {
                                var a = q * Math.PI / 2;
                                c.beginPath(); c.arc(m, m, m - 2, a + 0.25, a + Math.PI / 2 - 0.25); c.stroke();
                            }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    // Glyphs come from Omarchy's bundled Nerd Font,
                    // independent of the user's text face.
                    text: root.modules[planet.index].glyph
                    color: root.theme.foregroundColor
                    opacity: planet.selected || pointer.containsMouse ? 1 : 0.8
                    style: Text.Outline
                    styleColor: Qt.rgba(root.theme.backgroundColor.r, root.theme.backgroundColor.g, root.theme.backgroundColor.b, 0.7)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.max(12, planet.width * 0.3)
                }
                Rectangle {
                    visible: String(planet.status.badge).length > 0
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: -4
                    width: Math.max(18, badgeText.implicitWidth + 8)
                    height: 18
                    radius: 9
                    color: root.theme.urgentColor
                    border.color: root.theme.backgroundColor
                    border.width: 2
                    z: 4
                    Text {
                        id: badgeText
                        anchors.centerIn: parent
                        text: String(planet.status.badge)
                        color: root.theme.backgroundColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
                ToolTip.visible: pointer.containsMouse
                ToolTip.delay: 350
                ToolTip.text: root.modules[planet.index].name
                    + (planet.status.detail ? " · " + planet.status.detail : "")
                    + " · " + root.modules[planet.index].key + " to toggle · Enter to focus"
                MouseArea {
                    id: pointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: root.pointerPaused = containsMouse
                    onClicked: {
                        root.moduleSelected(planet.index);
                        root.focusPicker();
                    }
                    onDoubleClicked: root.moduleOpened(planet.index)
                }
            }
        }
    }

    Column {
        visible: !root.docked
        anchors.top: chamber.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "FORGE " + root.forgeState + "  //  "
                + (root.selectedModule >= 0
                    ? root.modules[root.selectedModule].name + " SELECTED  ·  [ ENTER ] TO FOCUS"
                    : root.modules.map(function(m) { return "[" + m.key + "] " + m.name.split(" ")[0]; }).join("  "))
            color: root.forgeState === "STABLE" ? root.theme.accentColor : root.theme.urgentColor
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontMicro
            font.bold: true
            font.letterSpacing: 1.3
        }
    }

    // Docked navigator: compact module index under the miniature core.
    Column {
        id: satelliteIndex
        visible: root.docked
        anchors.top: chamber.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4
        Text {
            text: "FORGE " + root.forgeState + "  ·  " + Math.round(root.heat * 100) + "% HEAT"
            color: root.forgeState === "STABLE" ? root.theme.accentColor : root.theme.urgentColor
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontMicro
            font.bold: true
            font.letterSpacing: 1.3
            bottomPadding: 4
        }
        Repeater {
            model: root.modules
            Rectangle {
                id: indexRow
                required property int index
                required property var modelData
                readonly property bool current: root.selectedModule === index
                width: satelliteIndex.width
                height: 28
                color: current ? Util.alpha(root.theme.accentColor, 0.14) : rowMouse.containsMouse ? root.theme.surfaceColor : "transparent"
                Rectangle {
                    width: 3; height: parent.height
                    color: root.theme.accentColor
                    visible: indexRow.current
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    spacing: 10
                    Text {
                        text: "[" + indexRow.modelData.key + "]"
                        color: indexRow.current ? root.theme.accentColor : root.theme.faintTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: root.theme.fontMicro
                        font.bold: true
                    }
                    Text {
                        text: indexRow.modelData.name
                        color: indexRow.current ? root.theme.foregroundColor : root.theme.dimmedTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: root.theme.fontSmall
                        font.bold: indexRow.current
                        font.letterSpacing: 1
                    }
                }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.moduleOpened(indexRow.index)
                }
            }
        }
    }
}
