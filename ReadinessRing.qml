import QtQuick
import QtQuick.Controls
import qs.Commons

Item {
    id: root
    required property DashboardTheme theme
    required property SystemReadinessSource source
    // Render as two layers so readouts float above passing planets:
    // the arc layer (labelLayer: false) and a readout layer (labelLayer: true).
    property bool labelLayer: false

    function metricAt(index) {
        return source.metrics[index] || { label: "—", value: "—", warning: false }
    }

    // How full each segment's arc is drawn.
    function fillFor(metric) {
        if (metric.id === "cpu") return source.cpuPercent / 100
        if (metric.id === "memory") return source.memoryPercent / 100
        if (metric.id === "gpu") return source.gpuPercent / 100
        if (metric.id === "disk") return source.diskPercent / 100
        if (metric.id === "battery") return source.batteryPresent ? source.batteryPercent / 100 : 1
        if (metric.id === "updates") return source.updatesAvailable ? 1 : 0
        if (metric.id === "network") return source.networkOnline ? 1 : 0
        if (metric.id === "bluetooth") return source.bluetoothConnected ? 1 : source.bluetoothPowered ? 0.5 : 0
        return 0
    }

    function labelColor(a, b) {
        return metricAt(a).warning || (b >= 0 && metricAt(b).warning) ? theme.urgentColor : theme.dimmedTextColor
    }

    Canvas {
        id: arcs
        anchors.fill: parent
        visible: !root.labelLayer
        property color normalColor: root.theme.accentColor
        property color warningColor: root.theme.urgentColor
        property var telemetry: root.source.metrics
        onNormalColorChanged: requestPaint()
        onWarningColorChanged: requestPaint()
        onTelemetryChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var c = getContext("2d")
            c.reset()
            var metrics = root.source.metrics
            var center = width / 2
            var radius = width * 0.43
            var step = Math.PI * 2 / metrics.length
            var gap = 0.07
            for (var i = 0; i < metrics.length; i++) {
                var start = -Math.PI / 2 + i * step + gap
                var end = -Math.PI / 2 + (i + 1) * step - gap
                var ink = metrics[i].warning ? warningColor : normalColor
                // Track
                c.beginPath()
                c.arc(center, center, radius, start, end)
                c.lineWidth = 2
                c.strokeStyle = ink
                c.globalAlpha = 0.18
                c.stroke()
                // Filled portion
                var fill = Math.max(0, Math.min(1, root.fillFor(metrics[i])))
                if (fill > 0) {
                    c.beginPath()
                    c.arc(center, center, radius, start, start + (end - start) * fill)
                    c.lineWidth = metrics[i].warning ? 5 : 3
                    c.globalAlpha = metrics[i].warning ? 0.95 : 0.7
                    c.stroke()
                }
                // Segment end ticks
                c.globalAlpha = 0.4
                c.lineWidth = 1
                c.beginPath()
                c.moveTo(center + Math.cos(start) * (radius - 5), center + Math.sin(start) * (radius - 5))
                c.lineTo(center + Math.cos(start) * (radius + 5), center + Math.sin(start) * (radius + 5))
                c.stroke()
            }
        }
    }

    Rectangle {
        visible: !root.labelLayer
        anchors.centerIn: parent
        width: parent.width * 0.56
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: root.source.warningCount ? Util.alpha(root.theme.urgentColor, 0.45) : Util.alpha(root.theme.accentColor, 0.2)
    }

    component Chip: Rectangle {
        required property Item target
        x: target.x - 6; y: target.y - 3
        width: target.width + 12; height: target.height + 6
        color: Util.alpha(root.theme.backgroundColor, 0.82)
        border.color: Util.alpha(root.theme.accentColor, 0.25)
    }

    Item {
        anchors.fill: parent
        visible: root.labelLayer
        Chip { target: topLabel }
        Chip { target: rightLabel }
        Chip { target: leftLabel }
        Chip { target: bottomLabels }
        Text {
            id: topLabel
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 6
            text: root.metricAt(0).label + " " + root.metricAt(0).value + "  ·  " + root.metricAt(1).label + " " + root.metricAt(1).value
            color: root.labelColor(0, 1)
            font.family: Style.font.menuFamily; font.pixelSize: root.theme.fontMicro; font.bold: true; font.letterSpacing: 0.8
        }
        Text {
            id: rightLabel
            anchors.left: parent.right; anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: root.metricAt(2).label + " " + root.metricAt(2).value + "\n" + root.metricAt(3).label + " " + root.metricAt(3).value
            color: root.labelColor(2, 3)
            font.family: Style.font.menuFamily; font.pixelSize: root.theme.fontMicro; font.bold: true; font.letterSpacing: 0.8
        }
        Text {
            id: leftLabel
            anchors.right: parent.left; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            text: root.metricAt(6).label + " " + root.metricAt(6).value + "\n" + root.metricAt(7).label + " " + root.metricAt(7).value
            color: root.labelColor(6, 7)
            font.family: Style.font.menuFamily; font.pixelSize: root.theme.fontMicro; font.bold: true; font.letterSpacing: 0.8
        }
        Column {
            id: bottomLabels
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 6
            spacing: 2
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.metricAt(4).label + " " + root.metricAt(4).value + "  ·  " + root.metricAt(5).label + " " + root.metricAt(5).value; color: root.labelColor(4, 5); font.family: Style.font.menuFamily; font.pixelSize: root.theme.fontMicro; font.bold: true; font.letterSpacing: 0.8 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.source.powerSummary; color: root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: root.theme.fontMicro }
        }
    }

    ToolTip.visible: !root.labelLayer && ringMouse.containsMouse
    ToolTip.text: root.source.status + "\n" + root.source.gpuName + (root.source.gpuTemperature >= 0 ? " · " + root.source.gpuTemperature + "°C" : "") + "\n" + root.source.networkName + " · " + root.source.batteryStatus
    MouseArea { id: ringMouse; enabled: !root.labelLayer; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
}
