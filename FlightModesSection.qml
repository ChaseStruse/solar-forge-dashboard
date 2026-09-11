import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

Item {
    id: root
    required property DashboardTheme theme
    required property FlightModesSource source
    property bool selected: false
    signal dismissRequested()
    implicitHeight: content.implicitHeight + 48

    onSelectedChanged: {
        if (selected)
            Qt.callLater(focusControls);
    }

    function focusControls() {
        modeGrid.forceActiveFocus();
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Util.alpha(root.theme.backgroundColor, 0.96)
        border.color: root.theme.borderColor
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 24
        spacing: 20

        Column {
            width: parent.width
            spacing: 5
            Text {
                text: "FLIGHT MODES"
                color: root.theme.accentColor
                font.family: Style.font.menuFamily
                font.pixelSize: 12
                font.bold: true
                font.letterSpacing: 1.6
            }
            Text {
                text: "Reconfigure the forge"
                color: root.theme.foregroundColor
                font.family: Style.font.menuFamily
                font.pixelSize: 24
                font.bold: true
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: "Coordinated Omarchy presets for attention, power, idle behavior, and display temperature."
                color: root.theme.dimmedTextColor
                font.family: Style.font.menuFamily
                font.pixelSize: 12
            }
        }

        GridLayout {
            width: parent.width
            columns: root.width < 720 ? 2 : 4
            columnSpacing: 10
            rowSpacing: 10
            Repeater {
                model: [
                    { label: "COMMS", value: root.source.doNotDisturb ? "QUIET" : "OPEN" },
                    { label: "IDLE", value: root.source.stayAwake ? "HELD" : "ALLOWED" },
                    { label: "POWER", value: root.source.powerProfile.toUpperCase() },
                    { label: "NIGHTLIGHT", value: root.source.nightlight ? "ON" : "OFF" }
                ]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 7
                    color: root.theme.surfaceColor
                    border.color: root.theme.borderColor
                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.value; color: root.theme.accentColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true }
                    }
                }
            }
        }

        GridLayout {
            id: modeGrid
            width: parent.width
            columns: root.width < 720 ? 1 : 2
            columnSpacing: 12
            rowSpacing: 12
            focus: true
            property int keyboardIndex: 0
            Keys.onPressed: function(event) {
                var count = root.source.modes.length;
                var columnCount = columns;
                if (event.key === Qt.Key_Left) {
                    keyboardIndex = (keyboardIndex + count - 1) % count;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
                    keyboardIndex = (keyboardIndex + 1) % count;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    keyboardIndex = (keyboardIndex + count - columnCount) % count;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    keyboardIndex = (keyboardIndex + columnCount) % count;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.source.apply(root.source.modes[keyboardIndex].id);
                    event.accepted = true;
                } else if (event.key === Qt.Key_R) {
                    root.source.refresh();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_F) {
                    root.dismissRequested();
                    event.accepted = true;
                }
            }

            Repeater {
                model: root.source.modes
                Rectangle {
                    id: modeCard
                    required property int index
                    required property var modelData
                    readonly property bool active: root.source.activeMode === modelData.id
                    readonly property bool pending: root.source.pendingMode === modelData.id
                    Layout.fillWidth: true
                    Layout.preferredHeight: 142
                    radius: 8
                    color: active || pending ? Util.alpha(root.theme.accentColor, 0.12) : root.theme.surfaceColor
                    border.width: modeGrid.keyboardIndex === index || active ? 2 : 1
                    border.color: active || pending || modeGrid.keyboardIndex === index ? root.theme.accentColor : root.theme.borderColor

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 14
                        Text {
                            text: modelData.glyph
                            color: root.theme.accentColor
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 28
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5
                            RowLayout {
                                Layout.fillWidth: true
                                Text { Layout.fillWidth: true; text: modelData.name; color: root.theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 17; font.bold: true; font.letterSpacing: 1.2 }
                                Text { text: modeCard.pending ? "ENGAGING" : modeCard.active ? "ACTIVE" : "READY"; color: modeCard.active || modeCard.pending ? root.theme.accentColor : root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                            }
                            Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: modelData.description; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 12 }
                            Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: modelData.detail; color: root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.5 }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.source.loading
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onEntered: modeGrid.keyboardIndex = modeCard.index
                        onClicked: {
                            modeGrid.keyboardIndex = modeCard.index;
                            modeGrid.forceActiveFocus();
                            root.source.apply(modeCard.modelData.id);
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 46
            radius: 7
            color: Util.alpha(root.theme.accentColor, 0.07)
            border.color: root.theme.borderColor
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10
                Rectangle {
                    width: 7; height: 7; radius: 4
                    color: root.source.loading ? root.theme.urgentColor : root.theme.accentColor
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.source.loading
                        NumberAnimation { to: 0.25; duration: 460 }
                        NumberAnimation { to: 1; duration: 460 }
                    }
                }
                Text { Layout.fillWidth: true; text: root.source.status; elide: Text.ElideRight; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 11; font.bold: true; font.letterSpacing: 0.8 }
                Text { text: "[ R ] RESCAN"; color: root.theme.accentColor; font.family: Style.font.menuFamily; font.pixelSize: 10; font.bold: true }
                MouseArea { Layout.preferredWidth: 78; Layout.fillHeight: true; enabled: !root.source.loading; cursorShape: Qt.PointingHandCursor; onClicked: root.source.refresh() }
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "[ F ] RETURN TO ORBIT   ·   ARROWS SELECT   ·   [ ENTER ] ENGAGE"
            color: root.theme.faintTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: 12
            font.letterSpacing: 1
        }
    }
}
