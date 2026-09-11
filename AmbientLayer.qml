import QtQuick

Item {
    id: root
    opacity: 0.34
    Canvas {
        anchors.fill: parent
        opacity: 0.12
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = "#9fe8cf"
            ctx.lineWidth = 1
            for (var y = 3; y < height; y += 7) {
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
            }
        }
    }
    Rectangle {
        width: parent.width
        height: 1
        color: "#b6f4dd"
        opacity: 0.13
        NumberAnimation on y {
            from: 0; to: root.height
            duration: 11000
            loops: Animation.Infinite
            running: root.visible
        }
    }
}
