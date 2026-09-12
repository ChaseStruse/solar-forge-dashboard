import QtQuick
import QtQuick.Controls
import qs.Commons

FocusScope {
    id: root
    required property DashboardTheme theme
    required property WorkspaceRadarSource source
    property bool selected: false
    property var selectedWindow: null
    signal dismissRequested()
    implicitHeight: 670

    function appGlyph(app) {
        var name = String(app || "").toLowerCase();
        if (/firefox|zen/.test(name)) return "󰈹";
        if (/chrom|brave|browser/.test(name)) return "󰊯";
        if (/foot|kitty|alacritty|terminal/.test(name)) return "󰆍";
        if (/code|cursor|zed|jetbrains/.test(name)) return "󰨞";
        if (/discord|slack|signal|telegram/.test(name)) return "󰭹";
        if (/spotify|music|vlc|mpv/.test(name)) return "󰎆";
        if (/obsidian/.test(name)) return "󱓧";
        return "󰣆";
    }

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
            height: 410

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

                    DropArea {
                        anchors.fill: parent
                        anchors.margins: -14
                        keys: ["solar-forge-window"]
                        onEntered: planetDropGlow.visible = true
                        onExited: planetDropGlow.visible = false
                        onDropped: function(drop) {
                            planetDropGlow.visible = false;
                            if (drop.source && root.source.moveWindow(drop.source.modelData.address, planet.modelData.id)) {
                                root.selectedWindow = drop.source.modelData;
                                drop.acceptProposedAction();
                            }
                        }
                    }
                    Rectangle {
                        id: planetDropGlow
                        anchors.fill: parent; anchors.margins: -15; radius: width/2
                        color: "transparent"
                        border.color: root.theme.urgentColor
                        border.width: 3
                        visible: false
                    }

                    Repeater {
                        model: planet.modelData.windows
                        Item {
                            id: moon
                            required property var modelData
                            required property int index
                            readonly property real moonAngle: index * Math.PI*2/Math.max(1, planet.modelData.windows.length)
                            width: 24; height: 24
                            x: planet.width/2 + Math.cos(moonAngle)*(planet.width/2+16) - width/2
                            y: planet.height/2 + Math.sin(moonAngle)*(planet.height/2+16) - height/2
                            Rectangle {
                                anchors.fill: parent; radius: width/2
                                color: moon.modelData.urgent ? root.theme.urgentColor : root.theme.foregroundColor
                                border.color: root.theme.backgroundColor
                                border.width: 2
                                opacity: moonPointer.containsMouse || root.selectedWindow === moon.modelData ? 1 : 0.78
                            }
                            Text {
                                anchors.centerIn: parent
                                text: root.appGlyph(moon.modelData.app)
                                color: root.theme.backgroundColor
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13; font.bold: true
                            }
                            Drag.active: moonPointer.drag.active
                            Drag.source: moon
                            Drag.keys: ["solar-forge-window"]
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2
                            z: moonPointer.drag.active ? 20 : 3
                            MouseArea {
                                id: moonPointer
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                drag.target: moon
                                drag.smoothed: false
                                onClicked: root.selectedWindow = moon.modelData
                                onDoubleClicked: root.source.focusWindow(moon.modelData.address)
                                onReleased: if (drag.active) moon.Drag.drop()
                            }
                            ToolTip.visible: moonPointer.containsMouse
                            ToolTip.text: moon.modelData.app + "\n" + moon.modelData.title
                        }
                    }

                    Column {
                        anchors.top: parent.bottom
                        anchors.topMargin: 9
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 1
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: planet.modelData.role
                            color: root.theme.dimmedTextColor
                            font.family: Style.font.menuFamily
                            font.pixelSize: 9
                            font.letterSpacing: 1
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: (planet.modelData.fullscreen ? "FULL  ·  " : "") + planet.modelData.windows.length + (planet.modelData.windows.length === 1 ? " SIGNAL" : " SIGNALS")
                            color: planet.modelData.windows.length >= 5 ? root.theme.urgentColor : root.theme.faintTextColor
                            font.family: Style.font.menuFamily
                            font.pixelSize: 8
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

        Rectangle {
            width: parent.width
            height: 82
            radius: 10
            color: root.theme.completedSurfaceColor
            border.color: root.selectedWindow ? root.theme.borderColor : "transparent"

            Text {
                anchors.centerIn: parent
                visible: !root.selectedWindow
                text: "SELECT A MOON FOR OPERATIONS  ·  DOUBLE-CLICK TO FOCUS  ·  DRAG TO REASSIGN"
                color: root.theme.faintTextColor
                font.family: Style.font.menuFamily
                font.pixelSize: 10
                font.letterSpacing: 1
            }
            Row {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                visible: root.selectedWindow !== null
                Text {
                    text: root.selectedWindow ? root.appGlyph(root.selectedWindow.app) : ""
                    color: root.theme.accentColor
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 28
                    anchors.verticalCenter: parent.verticalCenter
                }
                Column {
                    width: Math.max(120, parent.width - actionRow.width - 60)
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        width: parent.width
                        text: root.selectedWindow ? root.selectedWindow.app.toUpperCase() : ""
                        color: root.theme.foregroundColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 12; font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.selectedWindow ? root.selectedWindow.title : ""
                        color: root.theme.dimmedTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
                Row {
                    id: actionRow
                    spacing: 7
                    anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: [
                            { label: "FOCUS", destructive: false },
                            { label: "BRING HERE", destructive: false },
                            { label: "CLOSE", destructive: true }
                        ]
                        Rectangle {
                            required property var modelData
                            width: actionText.implicitWidth + 18; height: 30; radius: 6
                            color: actionMouse.containsMouse ? root.theme.surfaceColor : "transparent"
                            border.color: modelData.destructive ? root.theme.urgentColor : root.theme.borderColor
                            opacity: root.source.actionRunning ? 0.45 : 1
                            Text {
                                id: actionText
                                anchors.centerIn: parent
                                text: modelData.label
                                color: modelData.destructive ? root.theme.urgentColor : root.theme.foregroundColor
                                font.family: Style.font.menuFamily
                                font.pixelSize: 9; font.bold: true
                            }
                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !root.source.actionRunning
                                onClicked: {
                                    if (modelData.label === "FOCUS")
                                        root.source.focusWindow(root.selectedWindow.address);
                                    else if (modelData.label === "BRING HERE")
                                        root.source.moveWindow(root.selectedWindow.address, root.source.focusedWorkspaceId);
                                    else
                                        root.source.closeWindow(root.selectedWindow.address);
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            text: root.source.status + "  //  PLANET: SWITCH  ·  MOON: SELECT  ·  DRAG: MOVE"
            color: root.theme.dimmedTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }
}
