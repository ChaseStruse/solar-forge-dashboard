import QtQuick
import QtQuick.Controls
import qs.Commons

// Projected solar system: static painted lighting, scene-graph orbital motion.
Item {
    id: root
    required property DashboardTheme theme
    required property SystemReadinessSource readinessSource
    property bool animating: false
    property bool pointerPaused: false
    onAnimatingChanged: if (!animating) pointerPaused = false
    property real corePhase: 0
    property int selectedModule: -1
    signal moduleSelected(int module)
    signal moduleNavigated(int module)
    signal moduleOpened(int module)
    readonly property real orbitTilt: 0.42
    readonly property real chamberSize: Math.min(width, 860)
    readonly property real sunCanvasSize: Math.min(256, chamberSize * 0.5)
    // Keep room for the control status beneath the orbit field.
    implicitHeight: chamber.height + navigation.implicitHeight + telemetry.implicitHeight + 48
    focus: true

    function focusPicker() {
        forceActiveFocus();
    }

    function orbitX(angle, radius) {
        return chamber.width / 2 + Math.cos(angle) * radius;
    }

    function orbitY(angle, radius) {
        return chamber.height / 2 + Math.sin(angle) * radius * orbitTilt;
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Up
                || event.key === Qt.Key_Right || event.key === Qt.Key_Down
                || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.moduleNavigated((root.selectedModule + 1) % 6);
            event.accepted = true;
        } else if (event.key === Qt.Key_T) {
            if (!event.isAutoRepeat) root.moduleSelected(0);
            event.accepted = true;
        } else if (event.key === Qt.Key_G) {
            if (!event.isAutoRepeat) root.moduleSelected(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_M) {
            if (!event.isAutoRepeat) root.moduleSelected(2);
            event.accepted = true;
        } else if (event.key === Qt.Key_F) {
            if (!event.isAutoRepeat) root.moduleSelected(3);
            event.accepted = true;
        } else if (event.key === Qt.Key_W) {
            if (!event.isAutoRepeat) root.moduleSelected(4);
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            if (!event.isAutoRepeat) root.moduleSelected(5);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            if (root.selectedModule >= 0)
                root.moduleOpened(root.selectedModule);
            event.accepted = true;
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

    Item {
        id: chamber
        width: root.chamberSize
        height: width * 0.66
        anchors.horizontalCenter: parent.horizontalCenter

        Repeater {
            model: 24
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

        // Static tracks share the same projection and radii as their nodes.
        Canvas {
            anchors.fill: parent
            z: -2
            property color ink: root.theme.accentColor
            onInkChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var c = getContext("2d");
                c.reset();
                for (var ring of [0.38]) {
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

        // Paint the soft corona and luminous sphere once, then move its
        // faint surface texture with a scene-graph rotation.
        Canvas {
            id: sun
            width: root.sunCanvasSize
            height: width
            anchors.centerIn: parent
            z: 0
            property color ink: root.theme.accentColor
            onInkChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var c = getContext("2d");
                c.reset();
                var m = width / 2, r = width * 0.19;
                var halo = c.createRadialGradient(m, m, r * 0.65, m, m, m);
                halo.addColorStop(0, Qt.rgba(ink.r, ink.g, ink.b, 0.24));
                halo.addColorStop(0.36, Qt.rgba(ink.r, ink.g, ink.b, 0.06));
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
        ReadinessRing {
            width: Math.min(292, chamber.width * 0.43)
            height: width
            anchors.centerIn: parent
            z: 0.5
            theme: root.theme
            source: root.readinessSource
        }
        Canvas {
            width: root.sunCanvasSize * 0.38
            height: width
            anchors.centerIn: parent
            z: 0.1
            rotation: root.corePhase * 360 / (Math.PI * 2)
            opacity: 0.13
            property color ink: root.theme.accentColor
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

        Repeater {
            model: 6
            Rectangle {
                visible: false
                required property int index
                readonly property real angle: root.corePhase * 2 + index * Math.PI * 2 / 6
                width: 5 + index
                height: width
                radius: width / 2
                x: root.orbitX(angle, chamber.width * 0.24) - width / 2
                y: root.orbitY(angle, chamber.width * 0.24) - height / 2
                z: Math.sin(angle) < 0 ? -1 : 1
                scale: 0.85 + Math.sin(angle) * 0.15
                color: root.theme.secondaryAccentColor
                opacity: 0.65 + Math.sin(angle) * 0.2
            }
        }

        Repeater {
            model: 6
            Item {
                id: planet
                required property int index
                readonly property real angle: root.corePhase + index * Math.PI * 2 / 6
                readonly property real depth: Math.sin(angle)
                readonly property bool selected: root.selectedModule === index
                width: Math.max(44, chamber.width * 0.078)
                height: width
                x: root.orbitX(angle, chamber.width * 0.38) - width / 2
                y: root.orbitY(angle, chamber.width * 0.38) - height / 2
                z: depth < 0 ? -1 : 2
                scale: 0.9 + depth * 0.13
                opacity: 0.82 + depth * 0.16
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -5
                    radius: width / 2
                    color: "transparent"
                    border.color: root.theme.secondaryAccentColor
                    opacity: planet.selected ? 0.9 : pointer.containsMouse ? 0.5 : 0
                    scale: planet.selected ? 1.08 : 1
                    Behavior on opacity { NumberAnimation { duration: 220 } }
                    Behavior on scale { NumberAnimation { duration: 220 } }
                }
                Canvas {
                    anchors.fill: parent
                    // Rotate the lighting toward the sun; keep the label upright.
                    rotation: Math.atan2(chamber.height/2 - planet.y - planet.height/2,
                                         chamber.width/2 - planet.x - planet.width/2) * 180 / Math.PI
                    property color ink: root.theme.secondaryAccentColor
                    onInkChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        var c = getContext("2d"); c.reset();
                        var m = width / 2, r = m - 1;
                        var g = c.createRadialGradient(m+r*0.65, m-r*0.15, 0, m, m, r);
                        g.addColorStop(0, Qt.lighter(ink, 2.3));
                        g.addColorStop(0.45, ink);
                        g.addColorStop(1, "#10141f");
                        c.beginPath(); c.arc(m, m, r, 0, Math.PI*2);
                        c.fillStyle = g; c.fill();
                    }
                }
                Text {
                    anchors.centerIn: parent
                    // Font Awesome checklist and GitHub marks in Omarchy's
                    // bundled Nerd Font; independent of the user's text face.
                    text: planet.index === 0 ? "\uf0ae" : planet.index === 1 ? "\uf09b" : planet.index === 2 ? "\uf017" : planet.index === 3 ? "󰈐" : planet.index === 4 ? "󰍹" : "󰏘"
                    color: root.theme.foregroundColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.max(18, planet.width * 0.4)
                }
                ToolTip.visible: pointer.containsMouse
                ToolTip.delay: 350
                ToolTip.text: planet.index === 0
                    ? "Objectives · T to toggle · Enter to focus"
                    : planet.index === 1
                        ? "GitHub Intel · G to toggle · Enter to focus"
                        : planet.index === 2
                            ? "Mission timeline · M to toggle · Enter to focus"
                            : planet.index === 3
                                ? "Flight Modes · F to toggle · Enter to focus"
                                : planet.index === 4
                                    ? "Workspace Radar · W to toggle · Enter to focus"
                                    : "Theme Reactor · R to toggle · Enter to focus"
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

    Flow {
        id: navigation
        anchors.top: chamber.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        spacing: 8
        Repeater {
            model: ["T  Tasks", "G  GitHub", "M  Mission", "F  Flight", "W  Radar", "R  Themes"]
            delegate: Button {
                required property string modelData
                required property int index
                text: modelData
                onClicked: root.moduleSelected(index)
                background: Rectangle {
                    radius: 6
                    color: parent.hovered || root.selectedModule === parent.index ? root.theme.surfaceColor : "transparent"
                    border.color: root.selectedModule === parent.index ? root.theme.accentColor : "transparent"
                }
                contentItem: Text {
                    text: parent.text
                    color: root.theme.dimmedTextColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: 11
                }
            }
        }
    }
    Flow {
        id: telemetry
        anchors.top: navigation.bottom
        anchors.topMargin: 16
        width: parent.width
        spacing: 14
        Repeater {
            model: root.readinessSource.metrics
            Text {
                required property var modelData
                text: modelData.label + "  " + modelData.value
                color: modelData.warning ? root.theme.urgentColor : root.theme.dimmedTextColor
                font.family: Style.font.menuFamily
                font.pixelSize: 11
            }
        }
        Text {
            text: root.readinessSource.powerSummary
            color: root.theme.faintTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: 10
        }
    }
    Text {
        visible: false
        text: root.selectedModule === 0
            ? "● OBJECTIVES SELECTED  //  [ ENTER ] TO FOCUS"
            : root.selectedModule === 1
                ? "● GITHUB INTEL SELECTED  //  [ ENTER ] TO FOCUS"
                : root.selectedModule === 2
                    ? "● MISSION TIMELINE SELECTED  //  [ ENTER ] TO FOCUS"
                    : root.selectedModule === 3
                        ? "● FLIGHT MODES SELECTED  //  [ ENTER ] TO FOCUS"
                        : root.selectedModule === 4
                            ? "● WORKSPACE RADAR SELECTED  //  [ ENTER ] TO FOCUS"
                            : root.selectedModule === 5
                                ? "● THEME REACTOR SELECTED  //  [ ENTER ] TO FOCUS"
                                : "● SELECT  //  [ T ] TASKS  ·  [ G ] GITHUB  ·  [ M ] TIMELINE  ·  [ F ] FLIGHT  ·  [ W ] RADAR  ·  [ R ] REACTOR"
        color: root.theme.urgentColor
        font.family: Style.font.menuFamily
        font.pixelSize: 11
        font.letterSpacing: 1.3
    }
}
