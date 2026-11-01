import QtQuick
import qs.Commons

// CRT overlay: theme-tinted scanlines, a slow refresh bar, and a vignette.
Item {
    id: root
    required property DashboardTheme theme
    opacity: 0.34
    Canvas {
        anchors.fill: parent
        opacity: 0.12
        property color ink: root.theme.accentColor
        onInkChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = ink
            ctx.lineWidth = 1
            for (var y = 3; y < height; y += 7) {
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
            }
        }
    }
    Canvas {
        anchors.fill: parent
        property color shade: root.theme.backgroundColor
        onShadeChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var r = Math.max(width, height) * 0.75
            var g = ctx.createRadialGradient(width / 2, height / 2, r * 0.45, width / 2, height / 2, r)
            g.addColorStop(0, Qt.rgba(shade.r, shade.g, shade.b, 0))
            g.addColorStop(1, Qt.darker(shade, 2.2))
            ctx.fillStyle = g
            ctx.fillRect(0, 0, width, height)
        }
    }
    Rectangle {
        width: parent.width
        height: 1
        color: Qt.lighter(root.theme.accentColor, 1.3)
        opacity: 0.13
        NumberAnimation on y {
            from: 0; to: root.height
            duration: 11000
            loops: Animation.Infinite
            running: root.visible
        }
    }
}
