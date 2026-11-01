import QtQuick
import qs.Commons

// Left rail: rolling telemetry with sparklines, power, links, and host info.
Item {
    id: root
    required property DashboardTheme theme
    required property SystemReadinessSource source
    required property SystemBriefingSource briefing
    property string hostLine: ""
    readonly property int historyLength: 48
    property var cpuHistory: []
    property var memHistory: []
    property var gpuHistory: []

    function push(list, value) {
        var next = list.slice(Math.max(0, list.length - historyLength + 1));
        next.push(Math.max(0, value));
        return next;
    }

    // Sample on a fixed cadence so the sparkline time axis stays even.
    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: root.visible && root.source.cpuPercent >= 0
        onTriggered: {
            root.cpuHistory = root.push(root.cpuHistory, root.source.cpuPercent);
            root.memHistory = root.push(root.memHistory, root.source.memoryPercent);
            root.gpuHistory = root.push(root.gpuHistory, root.source.gpuPercent);
        }
    }

    component Caption: Text {
        color: root.theme.faintTextColor
        font.family: Style.font.menuFamily
        font.pixelSize: root.theme.fontMicro
        font.bold: true
        font.letterSpacing: 1.4
    }

    component Gauge: Column {
        id: gauge
        required property string label
        required property real value
        property var history: []
        property bool warning: value >= 90
        property real shown: value
        Behavior on shown { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        readonly property color ink: warning ? root.theme.urgentColor : root.theme.accentColor
        width: parent.width
        spacing: 6
        Row {
            width: parent.width
            Caption { text: gauge.label; width: parent.width - big.width }
            Text {
                id: big
                text: gauge.value < 0 ? "—" : Math.round(gauge.shown) + "%"
                color: gauge.ink
                font.family: Style.font.menuFamily
                font.pixelSize: 22
                font.bold: true
            }
        }
        Canvas {
            width: parent.width
            height: 34
            property var series: gauge.history
            property color ink: gauge.ink
            onSeriesChanged: requestPaint()
            onInkChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                var c = getContext("2d");
                c.reset();
                c.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.12);
                c.lineWidth = 1;
                for (var g = 0; g <= 2; g++) {
                    c.beginPath(); c.moveTo(0, g * (height - 1) / 2 + 0.5); c.lineTo(width, g * (height - 1) / 2 + 0.5); c.stroke();
                }
                if (series.length < 2)
                    return;
                var step = width / (root.historyLength - 1);
                var x0 = width - (series.length - 1) * step;
                c.beginPath();
                for (var i = 0; i < series.length; i++) {
                    var x = x0 + i * step, y = height - 2 - (height - 4) * Math.min(100, series[i]) / 100;
                    if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
                }
                c.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.95);
                c.lineWidth = 1.5;
                c.stroke();
                c.lineTo(width, height); c.lineTo(x0, height); c.closePath();
                var fill = c.createLinearGradient(0, 0, 0, height);
                fill.addColorStop(0, Qt.rgba(ink.r, ink.g, ink.b, 0.28));
                fill.addColorStop(1, Qt.rgba(ink.r, ink.g, ink.b, 0));
                c.fillStyle = fill;
                c.fill();
            }
        }
    }

    component Bar: Column {
        id: bar
        required property string label
        required property string detail
        required property real fraction
        property bool warning: false
        width: parent.width
        spacing: 5
        Row {
            width: parent.width
            Caption { text: bar.label; width: parent.width - detailText.width }
            Text {
                id: detailText
                text: bar.detail
                color: bar.warning ? root.theme.urgentColor : root.theme.foregroundColor
                font.family: Style.font.menuFamily
                font.pixelSize: root.theme.fontSmall
                font.bold: true
            }
        }
        // Segmented bar: 20 cells, lit up to the fraction.
        Row {
            width: parent.width
            spacing: 2
            Repeater {
                model: 20
                Rectangle {
                    required property int index
                    width: (bar.width - 38) / 20
                    height: 6
                    color: index < Math.round(Math.max(0, Math.min(1, bar.fraction)) * 20)
                        ? (bar.warning ? root.theme.urgentColor : root.theme.accentColor)
                        : Util.alpha(root.theme.foregroundColor, 0.08)
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }
        }
    }

    HudFrame {
        anchors.fill: parent
        theme: root.theme
        tag: "TELEMETRY // LIVE"
    }

    Column {
        anchors.fill: parent
        anchors.margins: 22
        anchors.topMargin: 28
        spacing: 18

        Gauge { label: "CPU FLUX"; value: root.source.cpuPercent; history: root.cpuHistory }
        Gauge { label: "MEMORY LATTICE"; value: root.source.memoryPercent; history: root.memHistory }
        Gauge {
            label: "GPU CORE" + (root.source.gpuTemperature >= 0 ? "  ·  " + root.source.gpuTemperature + "°C" : "")
            value: root.source.gpuPercent
            history: root.gpuHistory
            warning: root.source.gpuPercent >= 95 || root.source.gpuTemperature >= 85
        }

        Rectangle { width: parent.width; height: 1; color: Util.alpha(root.theme.accentColor, 0.2) }

        Bar {
            label: "STORAGE"
            detail: root.source.diskPercent < 0 ? "—" : root.source.diskPercent + "%"
            fraction: root.source.diskPercent / 100
            warning: root.source.diskPercent >= 90
        }
        Bar {
            label: root.source.acOnline ? "POWER // AC" : "POWER // CELL"
            detail: (root.source.batteryPresent ? root.source.batteryPercent + "%" : "AC")
                + (root.source.powerWatts >= 0 ? "  " + root.source.powerWatts.toFixed(1) + "W" : "")
            fraction: root.source.batteryPresent ? root.source.batteryPercent / 100 : 1
            warning: root.source.batteryPresent && !root.source.acOnline && root.source.batteryPercent <= 20
        }

        Rectangle { width: parent.width; height: 1; color: Util.alpha(root.theme.accentColor, 0.2) }

        Column {
            width: parent.width
            spacing: 8
            Repeater {
                model: [
                    { k: "UPLINK", v: root.source.networkOnline ? root.source.networkName : "OFFLINE", bad: !root.source.networkOnline },
                    { k: "BLUETOOTH", v: root.source.bluetoothConnected ? "LINKED" : root.source.bluetoothPowered ? "STANDBY" : "OFF", bad: false },
                    { k: "PROFILE", v: root.source.powerProfile.toUpperCase(), bad: false },
                    { k: "UPDATES", v: root.source.updatesAvailable ? "READY" : "CLEAR", bad: root.source.updatesAvailable },
                    { k: "UPTIME", v: root.briefing.uptime, bad: false },
                    { k: "HOST", v: root.hostLine, bad: false }
                ]
                Row {
                    required property var modelData
                    width: parent.width
                    Caption { text: modelData.k; width: 104 }
                    Text {
                        width: parent.width - 104
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideLeft
                        text: modelData.v
                        color: modelData.bad ? root.theme.urgentColor : root.theme.dimmedTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: root.theme.fontSmall
                    }
                }
            }
        }
    }
}
