import QtQuick
import qs.Commons

// Projected solar system: static painted lighting, scene-graph orbital motion.
Item {
    id: root
    required property DashboardTheme theme
    property bool animating: false
    property bool pointerPaused: false
    onAnimatingChanged: if (!animating) pointerPaused = false
    property real corePhase: 0
    property int selectedModule: -1
    signal moduleSelected(int module)
    signal moduleOpened(int module)
    readonly property real orbitTilt: 0.42
    readonly property real chamberSize: Math.min(width, 720)
    // Keep room for the control status beneath the orbit field.
    implicitHeight: chamberSize + 50
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
                || event.key === Qt.Key_Tab) {
            root.moduleSelected((root.selectedModule + 1) % 2);
            event.accepted = true;
        } else if (event.key === Qt.Key_T) {
            root.moduleSelected(0);
            event.accepted = true;
        } else if (event.key === Qt.Key_G) {
            root.moduleSelected(1);
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
        height: width
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
                for (var ring of [0.24, 0.38]) {
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
            width: chamber.width * 0.5
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
                halo.addColorStop(0, Qt.rgba(ink.r, ink.g, ink.b, 0.7));
                halo.addColorStop(0.36, Qt.rgba(ink.r, ink.g, ink.b, 0.22));
                halo.addColorStop(1, Qt.rgba(ink.r, ink.g, ink.b, 0));
                c.fillStyle = halo;
                c.fillRect(0, 0, width, height);
                var surface = c.createRadialGradient(m-r*0.3, m-r*0.3, 0, m, m, r);
                surface.addColorStop(0, "#fff9dd");
                surface.addColorStop(0.45, "#ffe9ab");
                surface.addColorStop(0.8, Qt.lighter(ink, 1.8));
                surface.addColorStop(1, ink);
                c.beginPath(); c.arc(m, m, r, 0, Math.PI * 2);
                c.fillStyle = surface; c.fill();
            }
        }
        Canvas {
            width: chamber.width * 0.19
            height: width
            anchors.centerIn: parent
            z: 0.1
            rotation: root.corePhase * 360 / (Math.PI * 2)
            opacity: 0.13
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var c = getContext("2d"); c.reset();
                for (var i = 0; i < 65; i++) {
                    var a = i * 2.39996, r = Math.sqrt(i / 65) * width * 0.46;
                    c.beginPath();
                    c.arc(width/2 + Math.cos(a)*r, height/2 + Math.sin(a)*r,
                          0.7 + i % 3 * 0.4, 0, Math.PI*2);
                    c.fillStyle = i % 2 ? "#ffffff" : "#7c361e"; c.fill();
                }
            }
        }

        Repeater {
            model: 3
            Rectangle {
                required property int index
                readonly property real angle: root.corePhase * 2 + index * Math.PI * 2 / 3
                width: 5 + index
                height: width
                radius: width / 2
                x: root.orbitX(angle, chamber.width * 0.24) - width / 2
                y: root.orbitY(angle, chamber.width * 0.24) - height / 2
                z: Math.sin(angle) < 0 ? -1 : 1
                scale: 0.85 + Math.sin(angle) * 0.15
                color: root.theme.accentColor
                opacity: 0.65 + Math.sin(angle) * 0.2
            }
        }

        Repeater {
            model: 2
            Item {
                id: planet
                required property int index
                readonly property real angle: root.corePhase + (index === 0 ? Math.PI : 0)
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
                    border.color: root.theme.accentColor
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
                    property color ink: root.theme.accentColor
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
                    text: planet.index === 0 ? "T" : "G"
                    color: "#ffffff"
                    style: Text.Outline
                    styleColor: "#10141f"
                    font.family: Style.font.menuFamily
                    font.pixelSize: Math.max(14, planet.width * 0.3)
                    font.bold: true
                }
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

    Text {
        anchors.top: chamber.bottom
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.selectedModule === 0
            ? "● OBJECTIVES SELECTED  //  [ ENTER ] TO FOCUS"
            : root.selectedModule === 1
                ? "● GITHUB INTEL SELECTED  //  [ ENTER ] TO FOCUS"
                : "● SELECT A MODULE  //  [ T ] OBJECTIVES  ·  [ G ] GITHUB"
        color: root.theme.urgentColor
        font.family: Style.font.menuFamily
        font.pixelSize: 11
        font.letterSpacing: 1.3
    }
}
