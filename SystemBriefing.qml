import QtQuick
import QtQuick.Layouts
import qs.Commons

Rectangle {
    id: root
    required property DashboardTheme theme
    required property SystemBriefingSource source
    required property MissionControlSource missionSource
    required property int objectiveCount
    property int stage: 0
    visible: false
    opacity: visible ? 1 : 0
    focus: visible
    color: Util.alpha(theme.backgroundColor, 0.94)
    z: 100
    Behavior on opacity { NumberAnimation { duration: 260 } }

    function play() {
        stage = 0
        visible = true
        reveal.restart()
        Qt.callLater(function() { root.forceActiveFocus() })
    }
    function dismiss() { visible = false }
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.dismiss()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            root.dismiss()
            event.accepted = true
        }
    }
    Timer { id: reveal; interval: 700; onTriggered: root.stage = 1 }

    MouseArea { anchors.fill: parent }
    Rectangle {
        width: Math.min(parent.width - 64, 720)
        height: briefingContent.implicitHeight + 48
        anchors.centerIn: parent
        radius: 12
        color: theme.backgroundColor
        border.color: Util.alpha(theme.accentColor, 0.55)
        Column {
            id: briefingContent
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 24; spacing: 18
            Text { text: "SOLAR FORGE  /  DAILY SYSTEM BRIEF"; color: theme.accentColor; font.family: Style.font.menuFamily; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.7 }
            Text { text: "Good " + (new Date().getHours() < 12 ? "morning" : new Date().getHours() < 18 ? "afternoon" : "evening") + "."; color: theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 30; font.bold: true }
            Text { width: parent.width; wrapMode: Text.Wrap; text: missionSource.weatherCondition === "—" ? "Local weather is unavailable." : missionSource.weatherCondition + " in " + missionSource.weatherLocation + ". " + missionSource.weatherValue + "."; color: theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 13 }
            GridLayout {
                width: parent.width; columns: 4; columnSpacing: 9; opacity: root.stage; Behavior on opacity { NumberAnimation { duration: 420 } }
                Repeater { model: [
                    { label: "CPU LOAD", value: source.cpuLoad },
                    { label: "MEMORY", value: source.memory },
                    { label: "DISK", value: source.disk },
                    { label: "UPTIME", value: source.uptime }
                ]; Rectangle { required property var modelData; Layout.fillWidth: true; Layout.preferredHeight: 72; radius: 6; color: theme.surfaceColor; border.color: theme.borderColor
                    Column { anchors.fill: parent; anchors.margins: 11; spacing: 7
                        Text { text: modelData.label; color: theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                        Text { width: parent.width; elide: Text.ElideRight; text: modelData.value; color: theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true }
                    }
                }}
            }
            RowLayout { width: parent.width; opacity: root.stage; Behavior on opacity { NumberAnimation { duration: 420 } }
                Column { Layout.fillWidth: true; spacing: 3
                    Text { text: "GPU  /  " + source.gpu; color: theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 11; font.bold: true }
                    Text { text: source.gpuDetail + "  ·  " + objectiveCount + " active objectives  ·  " + missionSource.repositories.length + " GitHub repositories synced"; color: theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 10 }
                }
            }
            Rectangle { width: parent.width; height: 54; radius: 6; color: Util.alpha(theme.accentColor, 0.09); border.color: Util.alpha(theme.accentColor, 0.32)
                RowLayout { anchors.fill: parent; anchors.margins: 12
                    Text { text: "RECOMMENDATION"; color: theme.accentColor; font.family: Style.font.menuFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                    Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: source.recommendation; color: theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 11 }
                }
            }
            RowLayout { width: parent.width; Item { Layout.fillWidth: true }
                Rectangle { implicitWidth: 100; implicitHeight: 32; radius: 16; color: theme.accentColor
                    Text { anchors.centerIn: parent; text: "ENTER FORGE"; color: theme.backgroundColor; font.family: Style.font.menuFamily; font.pixelSize: 9; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.dismiss() }
                }
            }
        }
    }
}
