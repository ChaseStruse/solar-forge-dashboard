import QtQuick
import QtQuick.Controls
import qs.Commons

Item {
    id: root
    required property DashboardTheme theme
    required property SystemReadinessSource source

    function metricAt(index) {
        return source.metrics[index] || { label: "—", value: "—", warning: false }
    }

    Canvas {
        id: arcs
        anchors.fill: parent
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
            var gap = 0.075
            for (var i = 0; i < metrics.length; i++) {
                var start = -Math.PI / 2 + i * step + gap
                var end = -Math.PI / 2 + (i + 1) * step - gap
                c.beginPath()
                c.arc(center, center, radius, start, end)
                c.lineWidth = metrics[i].warning ? 5 : 2
                c.strokeStyle = metrics[i].warning ? warningColor : normalColor
                c.globalAlpha = metrics[i].warning ? 0.95 : 0.30
                c.stroke()
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width * 0.56
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: root.source.warningCount ? Util.alpha(root.theme.urgentColor, 0.45) : Util.alpha(root.theme.accentColor, 0.2)
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 6
        spacing: 1
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.metricAt(0).label + " " + root.metricAt(0).value + "  ·  " + root.metricAt(1).label + " " + root.metricAt(1).value; color: root.metricAt(0).warning || root.metricAt(1).warning ? root.theme.urgentColor : root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 9; font.bold: true }
    }
    Text {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        text: root.metricAt(2).label + " " + root.metricAt(2).value + "\n" + root.metricAt(3).label + " " + root.metricAt(3).value
        horizontalAlignment: Text.AlignLeft
        color: root.metricAt(2).warning || root.metricAt(3).warning ? root.theme.urgentColor : root.theme.dimmedTextColor
        font.family: Style.font.menuFamily; font.pixelSize: 9; font.bold: true
    }
    Text {
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        text: root.metricAt(6).label + " " + root.metricAt(6).value + "\n" + root.metricAt(7).label + " " + root.metricAt(7).value
        horizontalAlignment: Text.AlignRight
        color: root.metricAt(6).warning ? root.theme.urgentColor : root.theme.dimmedTextColor
        font.family: Style.font.menuFamily; font.pixelSize: 9; font.bold: true
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        spacing: 1
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.metricAt(4).label + " " + root.metricAt(4).value + "  ·  " + root.metricAt(5).label + " " + root.metricAt(5).value; color: root.metricAt(4).warning || root.metricAt(5).warning ? root.theme.urgentColor : root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 9; font.bold: true }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.source.powerSummary; color: root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 8 }
    }

    ToolTip.visible: ringMouse.containsMouse
    ToolTip.text: root.source.status + "\n" + root.source.gpuName + (root.source.gpuTemperature >= 0 ? " · " + root.source.gpuTemperature + "°C" : "") + "\n" + root.source.networkName + " · " + root.source.batteryStatus
    MouseArea { id: ringMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
}
