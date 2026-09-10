import QtQuick
import qs.Commons

// The dashboard's visual anchor. Values remain public so a future hardware
// source can drive this without changing the command-center composition.
Item {
    id: root
    required property DashboardTheme theme
    property real productionKw: 4.82
    property real batteryPercent: 78
    property real gridKw: 0.36
    property real corePhase: 0
    implicitHeight: 458

    Timer {
        interval: 65
        running: true
        repeat: true
        onTriggered: root.corePhase = (root.corePhase + 0.014) % (Math.PI * 2)
    }

    Text {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        text: "FORGE CORE"
        color: root.theme.accentColor
        font.family: Style.font.menuFamily
        font.pixelSize: 14
        font.letterSpacing: 3.2
    }

    Rectangle {
        id: chamber
        anchors.top: parent.top
        anchors.topMargin: 30
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, 440)
        height: width
        radius: width / 2
        color: root.theme.surfaceColor
        border.color: root.theme.borderColor
        border.width: 1

        Rectangle {
            width: parent.width * 0.86
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: "transparent"
            border.color: root.theme.accentColor
            border.width: 1
            opacity: 0.16
            rotation: root.corePhase * 5
        }
        Rectangle {
            width: parent.width * 0.67
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: "transparent"
            border.color: root.theme.accentColor
            border.width: 1
            opacity: 0.25
            rotation: -root.corePhase * 9
        }
        Rectangle {
            width: parent.width * 0.48
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: "transparent"
            border.color: root.theme.accentColor
            border.width: 1
            opacity: 0.38
            rotation: root.corePhase * 12
        }

        Rectangle {
            width: parent.width * 0.78
            height: 1
            anchors.centerIn: parent
            color: root.theme.accentColor
            opacity: 0.12
        }
        Rectangle {
            width: 1
            height: parent.height * 0.78
            anchors.centerIn: parent
            color: root.theme.accentColor
            opacity: 0.12
        }

        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                width: 7
                height: width
                radius: width / 2
                x: chamber.width / 2 + Math.cos(root.corePhase * 2 + index * Math.PI / 2) * chamber.width * 0.31 - width / 2
                y: chamber.height / 2 + Math.sin(root.corePhase * 2 + index * Math.PI / 2) * chamber.height * 0.31 - height / 2
                color: root.theme.accentColor
                opacity: 0.6 + Math.sin(root.corePhase * 4 + index) * 0.25
            }
        }

        Rectangle {
            id: glow
            width: parent.width * 0.34
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: root.theme.accentColor
            opacity: 0.12 + Math.sin(root.corePhase * 3) * 0.04
            scale: 0.9 + Math.sin(root.corePhase * 3) * 0.05
        }
        Rectangle {
            id: core
            width: parent.width * 0.19
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: root.theme.accentColor
            border.color: root.theme.foregroundColor
            border.width: 1
            opacity: 0.92
            scale: 0.96 + Math.sin(root.corePhase * 3) * 0.04
        }
        Text {
            anchors.centerIn: core
            text: "SOL\nCORE"
            horizontalAlignment: Text.AlignHCenter
            color: root.theme.backgroundColor
            font.family: Style.font.menuFamily
            font.pixelSize: Math.max(9, chamber.width * 0.036)
            font.bold: true
            lineHeight: 0.82
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: parent.width * 0.10
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -parent.height * 0.20
            text: "ARRAY INPUT\n" + root.productionKw.toFixed(2) + " kW"
            color: root.theme.foregroundColor
            font.family: Style.font.menuFamily
            font.pixelSize: Math.max(10, chamber.width * 0.032)
            font.bold: true
            lineHeight: 1.15
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: parent.width * 0.10
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -parent.height * 0.20
            text: "BATTERY\n" + Math.round(root.batteryPercent) + "%"
            horizontalAlignment: Text.AlignRight
            color: root.theme.foregroundColor
            font.family: Style.font.menuFamily
            font.pixelSize: Math.max(10, chamber.width * 0.032)
            font.bold: true
            lineHeight: 1.15
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.11
            text: "GRID EXCHANGE  //  " + root.gridKw.toFixed(2) + " kW"
            color: root.theme.dimmedTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: Math.max(9, chamber.width * 0.026)
            font.letterSpacing: 0.8
        }
    }

    Text {
        anchors.top: chamber.bottom
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        text: "● ENERGY FLOW NOMINAL"
        color: root.theme.urgentColor
        font.family: Style.font.menuFamily
        font.pixelSize: 11
        font.letterSpacing: 1.3
    }
}
