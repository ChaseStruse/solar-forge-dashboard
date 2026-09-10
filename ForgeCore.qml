import QtQuick
import qs.Commons

// A visual telemetry module. The public properties intentionally make this
// ready for a real inverter/battery source without coupling presentation to it.
Column {
    id: root
    required property DashboardTheme theme
    property real productionKw: 4.82
    property real batteryPercent: 78
    property real gridKw: 0.36
    property real corePhase: 0

    spacing: 8
    topPadding: 12

    Timer {
        interval: 80
        running: true
        repeat: true
        onTriggered: root.corePhase = (root.corePhase + 0.018) % (Math.PI * 2)
    }

    Text {
        width: parent.width
        text: "FORGE CORE // LIVE ENERGY TELEMETRY"
        color: root.theme.accentColor
        font.family: Style.font.menuFamily
        font.pixelSize: 14
        font.letterSpacing: 1.4
    }

    Rectangle {
        id: panel
        width: parent.width
        height: 258
        color: root.theme.surfaceColor
        border.color: root.theme.borderColor
        border.width: 1
        clip: true

        Rectangle {
            width: parent.width
            height: 1
            y: 36
            color: root.theme.borderColor
            opacity: 0.55
        }

        Text {
            x: 12
            y: 11
            text: "AUTONOMOUS POWER MATRIX"
            color: root.theme.dimmedTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: 11
            font.letterSpacing: 1.2
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12
            y: 11
            text: "● LINK STANDBY"
            color: root.theme.urgentColor
            font.family: Style.font.menuFamily
            font.pixelSize: 11
            font.letterSpacing: 1
        }

        Item {
            id: reactor
            width: Math.min(210, panel.width * 0.34)
            height: width
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 18
            x: Math.max(14, panel.width * 0.07)

            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    width: reactor.width - index * 42
                    height: width
                    radius: width / 2
                    anchors.centerIn: parent
                    color: "transparent"
                    border.color: root.theme.accentColor
                    border.width: 1
                    opacity: 0.16 + index * 0.1
                    rotation: root.corePhase * (index % 2 ? -12 : 9)
                }
            }
            Rectangle {
                id: core
                width: reactor.width * 0.36
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: root.theme.accentColor
                opacity: 0.18 + Math.sin(root.corePhase * 3) * 0.07
                scale: 0.94 + Math.sin(root.corePhase * 3) * 0.045
            }
            Rectangle {
                width: reactor.width * 0.18
                height: width
                radius: width / 2
                anchors.centerIn: parent
                color: root.theme.accentColor
                opacity: 0.9
            }
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 3
                text: "SOL\nCORE"
                horizontalAlignment: Text.AlignHCenter
                color: root.theme.backgroundColor
                font.family: Style.font.menuFamily
                font.pixelSize: Math.max(9, reactor.width * 0.065)
                font.bold: true
                lineHeight: 0.86
            }
        }

        Column {
            id: metrics
            anchors.left: reactor.right
            anchors.leftMargin: Math.max(20, panel.width * 0.06)
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: reactor.verticalCenter
            spacing: 12

            Repeater {
                model: [
                    { label: "ARRAY OUTPUT", value: root.productionKw.toFixed(2) + " kW", level: 0.82 },
                    { label: "BATTERY RESERVE", value: Math.round(root.batteryPercent) + "%", level: root.batteryPercent / 100 },
                    { label: "GRID EXCHANGE", value: root.gridKw.toFixed(2) + " kW", level: 0.36 }
                ]
                delegate: Column {
                    id: metricRow
                    required property var modelData
                    required property int index
                    width: metrics.width
                    spacing: 3
                    Row {
                        width: parent.width
                        Text {
                            width: parent.width * 0.55
                            text: modelData.label
                            color: root.theme.dimmedTextColor
                            font.family: Style.font.menuFamily
                            font.pixelSize: 11
                            font.letterSpacing: 0.8
                        }
                        Text {
                            width: parent.width * 0.45
                            text: modelData.value
                            horizontalAlignment: Text.AlignRight
                            color: root.theme.foregroundColor
                            font.family: Style.font.menuFamily
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 3
                        color: root.theme.borderColor
                        Rectangle {
                            width: parent.width * modelData.level
                            height: parent.height
                            color: root.theme.accentColor
                            opacity: 0.75 + Math.sin(root.corePhase * 3 + metricRow.index) * 0.2
                        }
                    }
                }
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            text: "ENERGY FLOW NOMINAL  //  SENSOR INTEGRATION PENDING"
            color: root.theme.faintTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: 10
            font.letterSpacing: 0.8
        }
    }
}
