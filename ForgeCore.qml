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

    Timer {
        interval: 65
        running: true
        repeat: true
        onTriggered: root.corePhase = (root.corePhase + 0.014) % (Math.PI * 2)
    }

    Rectangle {
        id: chamber
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.chamberSize
        height: width
        radius: width / 2
        color: "transparent"

        Repeater {
            model: 36
            delegate: Rectangle {
                required property int index
                width: index % 7 === 0 ? 3 : 1
                height: width
                radius: width / 2
                x: ((index * 47) % 97) / 100 * parent.width
                y: ((index * 71) % 89) / 100 * parent.height
                color: root.theme.foregroundColor
                opacity: 0.08 + (Math.sin(root.corePhase * 2 + index) + 1) * 0.08
            }
        }

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
            transform: Scale {
                origin.x: parent.width / 2
                origin.y: parent.height / 2
                yScale: root.orbitTilt
            }
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
            transform: Scale {
                origin.x: parent.width / 2
                origin.y: parent.height / 2
                yScale: root.orbitTilt
            }
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
            transform: Scale {
                origin.x: parent.width / 2
                origin.y: parent.height / 2
                yScale: root.orbitTilt
            }
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
                x: root.orbitX(root.corePhase * 2 + index * Math.PI / 2, chamber.width * 0.31) - width / 2
                y: root.orbitY(root.corePhase * 2 + index * Math.PI / 2, chamber.width * 0.31) - height / 2
                color: root.theme.accentColor
                opacity: 0.6 + Math.sin(root.corePhase * 4 + index) * 0.25
            }
        }

        Rectangle {
            id: glow
            width: parent.width * 0.46
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: root.theme.accentColor
            opacity: 0.08 + Math.sin(root.corePhase * 3) * 0.03
            scale: 0.9 + Math.sin(root.corePhase * 3) * 0.06
        }
        Rectangle {
            width: parent.width * 0.31
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: root.theme.accentColor
            opacity: 0.20 + Math.sin(root.corePhase * 3 + 1) * 0.05
            scale: 0.95 + Math.sin(root.corePhase * 3 + 1) * 0.04
        }
        Rectangle {
            id: core
            width: parent.width * 0.17
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: root.theme.accentColor
            border.color: root.theme.foregroundColor
            border.width: 1
            opacity: 0.95
            scale: 0.96 + Math.sin(root.corePhase * 3) * 0.04
        }
        Item {
            id: objectivesNode
            width: Math.max(36, parent.width * 0.10)
            height: Math.max(36, parent.width * 0.10)
            x: root.orbitX(root.corePhase * 0.72 + Math.PI, parent.width * 0.38) - width / 2
            y: root.orbitY(root.corePhase * 0.72 + Math.PI, parent.width * 0.38) - height / 2

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
                    font.family: root.theme.fontFamily
                    font.bold: true
                }
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

        Item {
            id: githubNode
            width: Math.max(36, parent.width * 0.10)
            height: Math.max(36, parent.width * 0.10)
            x: root.orbitX(root.corePhase * 0.72, parent.width * 0.38) - width / 2
            y: root.orbitY(root.corePhase * 0.72, parent.width * 0.38) - height / 2

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
                    font.family: root.theme.fontFamily
                    font.bold: true
                }
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
        font.family: root.theme.fontFamily
        font.pixelSize: 11
        font.letterSpacing: 1.3
    }
}
