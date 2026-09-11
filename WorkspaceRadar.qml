import QtQuick
import QtQuick.Controls
import qs.Commons

FocusScope {
    id: root
    required property DashboardTheme theme
    required property WorkspaceRadarSource source
    property bool selected: false
    signal dismissRequested()
    implicitHeight: 620

    Keys.onEscapePressed: root.dismissRequested()

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: root.theme.surfaceColor
        border.color: root.theme.borderColor
    }

    Column {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 10

        Row {
            width: parent.width
            spacing: 12
            Text {
                text: "WORKSPACE RADAR"
                color: root.theme.accentColor
                font.family: Style.font.menuFamily
                font.pixelSize: 17
                font.bold: true
                font.letterSpacing: 2
            }
            Text {
                text: "HYPRLAND ORBITAL TOPOLOGY"
                color: root.theme.faintTextColor
                font.family: Style.font.menuFamily
                font.pixelSize: 11
                anchors.baseline: parent.children[0].baseline
            }
        }

        Item {
            id: field
            width: parent.width
            height: 500

            Canvas {
                anchors.fill: parent
                property color ink: root.theme.accentColor
                onInkChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d"); c.reset();
                    c.strokeStyle = ink; c.lineWidth = 1;
                    for (var r of [0.23, 0.36, 0.49]) {
                        c.beginPath();
                        c.ellipse(width/2, height/2, width*r, height*r*0.58, 0, 0, Math.PI*2);
                        c.globalAlpha = 0.13; c.stroke();
                    }
                    c.beginPath(); c.moveTo(width/2-18, height/2); c.lineTo(width/2+18, height/2);
                    c.moveTo(width/2, height/2-18); c.lineTo(width/2, height/2+18);
                    c.globalAlpha = 0.28; c.stroke();
                }
            }

            Repeater {
                model: root.source.workspaces
                Item {
                    id: planet
                    required property var modelData
                    required property int index
                    readonly property int count: Math.max(1, root.source.workspaces.length)
                    readonly property real angle: -Math.PI/2 + index * Math.PI*2/count
                    readonly property real orbitX: field.width * (count <= 4 ? 0.29 : 0.40)
                    readonly property real orbitY: field.height * (count <= 4 ? 0.25 : 0.36)
                    readonly property bool focused: modelData.id === root.source.focusedWorkspaceId
                    width: focused ? 66 : 58
                    height: width
                    x: field.width/2 + Math.cos(angle)*orbitX - width/2
                    y: field.height/2 + Math.sin(angle)*orbitY - height/2

                    Rectangle {
                        id: distress
                        anchors.centerIn: parent
                        width: parent.width + 20; height: width; radius: width/2
                        color: "transparent"
                        border.width: 2
                        border.color: root.theme.urgentColor
                        visible: modelData.urgent
                        SequentialAnimation on opacity {
                            running: distress.visible; loops: Animation.Infinite
                            NumberAnimation { from: 0.15; to: 0.9; duration: 550 }
                            NumberAnimation { from: 0.9; to: 0.15; duration: 550 }
                        }
                        SequentialAnimation on scale {
                            running: distress.visible; loops: Animation.Infinite
                            NumberAnimation { from: 0.9; to: 1.18; duration: 1100 }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: width/2
                        color: planet.focused ? root.theme.accentColor : root.theme.secondaryAccentColor
                        border.width: planet.focused ? 3 : 1
                        border.color: root.theme.foregroundColor
                        layer.enabled: planet.focused
                        opacity: planetPointer.containsMouse ? 1 : 0.88
                    }
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -9; radius: width/2
                        color: "transparent"
                        border.color: root.theme.accentColor
                        border.width: 2
                        opacity: planet.focused ? 0.58 : 0
                    }
                    Text {
                        anchors.centerIn: parent
                        text: planet.modelData.id
                        color: root.theme.backgroundColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 19
                        font.bold: true
                    }
                    MouseArea {
                        id: planetPointer
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.source.focusWorkspace(planet.modelData.id)
                    }
                    ToolTip.visible: planetPointer.containsMouse
                    ToolTip.text: "Workspace " + modelData.name + " · " + modelData.windows.length + " windows"

                    Repeater {
                        model: planet.modelData.windows
                        Item {
                            id: moon
                            required property var modelData
                            required property int index
                            readonly property real moonAngle: index * Math.PI*2/Math.max(1, planet.modelData.windows.length)
                            width: 18; height: 18
                            x: planet.width/2 + Math.cos(moonAngle)*(planet.width/2+16) - width/2
                            y: planet.height/2 + Math.sin(moonAngle)*(planet.height/2+16) - height/2
                            Rectangle {
                                anchors.fill: parent; radius: width/2
                                color: moon.modelData.urgent ? root.theme.urgentColor : root.theme.foregroundColor
                                border.color: root.theme.backgroundColor
                                border.width: 2
                                opacity: moonPointer.containsMouse ? 1 : 0.78
                            }
                            Text {
                                anchors.centerIn: parent
                                text: moon.modelData.app.charAt(0).toUpperCase()
                                color: root.theme.backgroundColor
                                font.pixelSize: 9; font.bold: true
                            }
                            MouseArea {
                                id: moonPointer
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.source.focusWindow(moon.modelData.address)
                            }
                            ToolTip.visible: moonPointer.containsMouse
                            ToolTip.text: moon.modelData.app + "\n" + moon.modelData.title
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.source.workspaces.length === 0
                text: root.source.loading ? "SCANNING…" : "NO ORBITS"
                color: root.theme.dimmedTextColor
                font.family: Style.font.menuFamily
                font.pixelSize: 14
                font.letterSpacing: 2
            }
        }

        Text {
            width: parent.width
            text: root.source.status + "  //  PLANET: SWITCH WORKSPACE  ·  MOON: FOCUS WINDOW"
            color: root.theme.dimmedTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
}
