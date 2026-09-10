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
    property int selectedModule: -1
    signal moduleSelected(int module)
    signal moduleOpened(int module)
    readonly property real chamberSize: Math.min(width, 560)
    // The circular chamber begins 30px below the title and the status sits
    // beneath it, so reserve its full visual footprint in the command deck.
    implicitHeight: chamberSize + 80
    focus: true

    function focusPicker() {
        forceActiveFocus();
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
        width: root.chamberSize
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

        Rectangle {
            x: objectivesNode.x + objectivesNode.width * 0.55
            y: objectivesNode.y + objectivesNode.height / 2
            width: Math.max(0, core.x - x)
            height: 1
            color: root.theme.accentColor
            opacity: root.selectedModule === 0 ? 0.9 : 0.2
        }
        Item {
            id: objectivesNode
            width: parent.width * 0.25
            height: Math.max(36, parent.width * 0.10)
            x: parent.width * 0.10
            y: parent.height * 0.63

            Rectangle {
                id: objectivesBeacon
                width: parent.height
                height: width
                radius: width / 2
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: root.selectedModule === 0 ? root.theme.accentColor : root.theme.surfaceColor
                border.color: root.theme.accentColor
                border.width: root.selectedModule === 0 ? 2 : 1
                scale: root.selectedModule === 0 ? 1.12 : 1
                Text {
                    anchors.centerIn: parent
                    text: "T"
                    color: root.selectedModule === 0 ? root.theme.backgroundColor : root.theme.accentColor
                    font.family: Style.font.menuFamily
                    font.bold: true
                }
            }
            Text {
                anchors.left: objectivesBeacon.right
                anchors.leftMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                text: "OBJECTIVES"
                color: root.selectedModule === 0 ? root.theme.foregroundColor : root.theme.dimmedTextColor
                font.family: Style.font.menuFamily
                font.pixelSize: Math.max(9, chamber.width * 0.027)
                font.letterSpacing: 0.7
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.moduleSelected(0);
                    root.focusPicker();
                }
                onDoubleClicked: root.moduleOpened(0)
            }
        }

        Rectangle {
            x: core.x + core.width
            y: githubNode.y + githubNode.height / 2
            width: Math.max(0, githubNode.x + githubNode.width * 0.45 - x)
            height: 1
            color: root.theme.accentColor
            opacity: root.selectedModule === 1 ? 0.9 : 0.2
        }
        Item {
            id: githubNode
            width: parent.width * 0.25
            height: Math.max(36, parent.width * 0.10)
            x: parent.width * 0.65
            y: parent.height * 0.63

            Rectangle {
                id: githubBeacon
                width: parent.height
                height: width
                radius: width / 2
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                color: root.selectedModule === 1 ? root.theme.accentColor : root.theme.surfaceColor
                border.color: root.theme.accentColor
                border.width: root.selectedModule === 1 ? 2 : 1
                scale: root.selectedModule === 1 ? 1.12 : 1
                Text {
                    anchors.centerIn: parent
                    text: "G"
                    color: root.selectedModule === 1 ? root.theme.backgroundColor : root.theme.accentColor
                    font.family: Style.font.menuFamily
                    font.bold: true
                }
            }
            Text {
                anchors.right: githubBeacon.left
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                text: "GITHUB INTEL"
                color: root.selectedModule === 1 ? root.theme.foregroundColor : root.theme.dimmedTextColor
                font.family: Style.font.menuFamily
                font.pixelSize: Math.max(9, chamber.width * 0.027)
                font.letterSpacing: 0.7
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.moduleSelected(1);
                    root.focusPicker();
                }
                onDoubleClicked: root.moduleOpened(1)
            }
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
