import QtQuick
import qs.Commons

// Clipped-corner HUD chassis shared by every panel: notched outline, corner
// brackets, edge ticks, an optional designation tag, and a slow scan sweep.
Item {
    id: root
    required property DashboardTheme theme
    property color ink: theme.accentColor
    property string tag: ""
    property bool active: true
    property real fillOpacity: 0.9
    readonly property int notch: theme.notch

    Canvas {
        id: chassis
        anchors.fill: parent
        property color ink: root.ink
        property color fill: root.theme.backgroundColor
        property bool active: root.active
        onInkChanged: requestPaint()
        onFillChanged: requestPaint()
        onActiveChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var c = getContext("2d");
            c.reset();
            if (width < 4 || height < 4)
                return;
            var n = root.notch, w = width - 1, h = height - 1, b = root.theme.bracket;
            function outline() {
                c.beginPath();
                c.moveTo(n + 0.5, 0.5);
                c.lineTo(w, 0.5);
                c.lineTo(w, h - n);
                c.lineTo(w - n, h);
                c.lineTo(0.5, h);
                c.lineTo(0.5, n + 0.5);
                c.closePath();
            }
            outline();
            var g = c.createLinearGradient(0, 0, 0, height);
            g.addColorStop(0, Qt.rgba(ink.r, ink.g, ink.b, 0.07));
            g.addColorStop(0.3, Qt.rgba(fill.r, fill.g, fill.b, root.fillOpacity));
            g.addColorStop(1, Qt.rgba(fill.r, fill.g, fill.b, root.fillOpacity));
            c.fillStyle = g;
            c.fill();

            // Soft outer glow, then the crisp hairline.
            outline();
            c.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, active ? root.theme.glowAlpha : 0.08);
            c.lineWidth = 4;
            c.stroke();
            outline();
            c.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, active ? 0.6 : 0.3);
            c.lineWidth = 1;
            c.stroke();

            // Heavy brackets on the two unclipped corners.
            c.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, active ? 0.95 : 0.5);
            c.lineWidth = 2;
            c.beginPath();
            c.moveTo(w - b, 1); c.lineTo(w - 1, 1); c.lineTo(w - 1, b);
            c.moveTo(1, h - b); c.lineTo(1, h - 1); c.lineTo(b, h - 1);
            c.stroke();
            // Notch accents.
            c.beginPath();
            c.moveTo(1, n + 6); c.lineTo(n + 6, 1);
            c.moveTo(w - n - 6, h - 1); c.lineTo(w - 1, h - n - 6);
            c.stroke();

            // Ruler ticks along the top and bottom edges.
            c.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.35);
            c.lineWidth = 1;
            c.beginPath();
            for (var x = n + 24, i = 0; x < w - b - 8; x += 12, i++) {
                var len = i % 5 === 0 ? 6 : 3;
                c.moveTo(x + 0.5, 3); c.lineTo(x + 0.5, 3 + len);
            }
            for (var x2 = b + 8, j = 0; x2 < w - n - 24; x2 += 12, j++) {
                if (j % 5 === 0) { c.moveTo(x2 + 0.5, h - 3); c.lineTo(x2 + 0.5, h - 8); }
            }
            c.stroke();
        }
    }

    // Designation tag riding on the top border.
    Rectangle {
        visible: root.tag.length > 0
        x: root.notch + 18
        y: -height / 2
        width: tagText.implicitWidth + 16
        height: tagText.implicitHeight + 4
        color: root.theme.backgroundColor
        border.color: Util.alpha(root.ink, 0.6)
        Text {
            id: tagText
            anchors.centerIn: parent
            text: root.tag
            color: root.ink
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontMicro
            font.bold: true
            font.letterSpacing: 1.6
        }
    }

    // Slow scan sweep while the frame is live.
    Item {
        anchors.fill: parent
        anchors.margins: 2
        clip: true
        visible: root.active
        // Animation endpoints are captured at start; resync after resizes.
        onHeightChanged: if (sweepMotion.running) sweepMotion.restart()
        Rectangle {
            id: sweep
            width: parent.width
            height: 64
            opacity: 0.35
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.92; color: Util.alpha(root.ink, 0.06) }
                GradientStop { position: 1; color: Util.alpha(root.ink, 0.22) }
            }
            NumberAnimation on y {
                id: sweepMotion
                from: -sweep.height
                to: sweep.parent.height
                duration: 5200
                loops: Animation.Infinite
                running: root.active && root.visible
            }
        }
    }
}
