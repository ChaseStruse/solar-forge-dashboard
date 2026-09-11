import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

Item {
    id: root
    required property DashboardTheme theme
    required property MissionControlSource source
    property bool selected: false
    signal dismissRequested()
    signal replayBriefing()
    implicitHeight: content.implicitHeight + 48

    readonly property color autonomousColor: "#62d6b3"
    readonly property color weatherColor: "#70b9df"

    function toneColor(tone) {
        if (tone === "autonomous") return autonomousColor;
        if (tone === "weather") return weatherColor;
        if (tone === "urgent") return theme.urgentColor;
        return theme.accentColor;
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

        RowLayout {
            width: parent.width
            Column {
                Layout.fillWidth: true
                spacing: 5
                Text {
                    text: "MISSION CONTROL  /  GITHUB + LOCAL WEATHER"
                    color: root.theme.accentColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.6
                }
                Text {
                    text: "Operational timeline"
                    color: root.theme.foregroundColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: 24
                    font.bold: true
                }
                Text {
                    text: "Real activity from your connected system services."
                    color: root.theme.dimmedTextColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: 11
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 134
                implicitHeight: 30
                radius: 15
                color: Util.alpha(root.autonomousColor, 0.10)
                border.color: Util.alpha(root.autonomousColor, 0.42)
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: root.autonomousColor }
                    Text { text: root.source.loading ? "SYNCING" : "SOURCES LIVE"; color: root.autonomousColor; font.family: Style.font.menuFamily; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8 }
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 122
                implicitHeight: 30
                radius: 15
                color: root.theme.surfaceColor
                border.color: root.theme.borderColor
                Text { anchors.centerIn: parent; text: "REPLAY BRIEFING"; color: root.theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 0.8 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.replayBriefing() }
            }
        }

        GridLayout {
            width: parent.width
            columns: 3
            columnSpacing: 10
            Repeater {
                model: [
                    { label: "REPOSITORIES", value: String(root.source.repositories.length), unit: "SYNCED", note: root.source.githubStatus, tone: "accent" },
                    { label: "LATEST ACTIVITY", value: root.source.events.length ? root.source.events[0].time : "—", unit: "LOCAL", note: root.source.events.length ? root.source.events[0].title : "No GitHub activity", tone: "autonomous" },
                    { label: "WEATHER", value: root.source.weatherCondition, unit: "", note: root.source.weatherLocation + " · " + root.source.weatherValue, tone: "weather" }
                ]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 94
                    radius: 7
                    color: root.theme.surfaceColor
                    border.color: root.theme.borderColor
                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6
                        Text { text: modelData.label; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.1 }
                        Row {
                            spacing: 6
                            Text { text: modelData.value; color: root.toneColor(modelData.tone); font.family: Style.font.menuFamily; font.pixelSize: 24; font.bold: true }
                            Text { anchors.baseline: parent.children[0].baseline; text: modelData.unit; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 10 }
                        }
                        Text { text: modelData.note; color: root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 9 }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 64
            radius: 7
            color: Util.alpha(root.theme.urgentColor, 0.07)
            border.color: Util.alpha(root.theme.urgentColor, 0.35)
            RowLayout {
                anchors.fill: parent
                anchors.margins: 13
                spacing: 12
                Rectangle {
                    implicitWidth: 30; implicitHeight: 30; radius: 15
                    color: Util.alpha(root.theme.urgentColor, 0.13)
                    Text { anchors.centerIn: parent; text: "!"; color: root.theme.urgentColor; font.family: Style.font.menuFamily; font.pixelSize: 15; font.bold: true }
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 3
                    Text { text: "SOURCE STATUS"; color: root.theme.urgentColor; font.family: Style.font.menuFamily; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                    Text { text: root.source.githubStatus + " · " + root.source.weatherStatus; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 10 }
                }
                Text { text: "LIVE DATA"; color: root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 9; font.letterSpacing: 1 }
            }
        }

        RowLayout {
            width: parent.width
            spacing: 26
            TimelineLane {
                Layout.fillWidth: true
                Layout.preferredWidth: 1.16
                theme: root.theme
                title: "RECENT REPOSITORY ACTIVITY"
                subtitle: "GITHUB"
                events: root.source.events
                future: false
                autonomousColor: root.autonomousColor
                weatherColor: root.weatherColor
            }
            Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: root.theme.borderColor }
            TimelineLane {
                Layout.fillWidth: true
                Layout.preferredWidth: 0.84
                theme: root.theme
                title: "CURRENT CONDITIONS"
                subtitle: "OMARCHY WEATHER"
                events: root.source.weatherEvents
                future: false
                autonomousColor: root.autonomousColor
                weatherColor: root.weatherColor
            }
        }

        Rectangle {
            width: parent.width
            height: 48
            radius: 7
            color: Util.alpha(root.autonomousColor, 0.07)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                Text { text: "DATA SOURCES"; color: root.autonomousColor; font.family: Style.font.menuFamily; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.2 }
                Text { Layout.fillWidth: true; text: "GitHub CLI · Omarchy weather location and service"; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 10 }
                Text { text: root.source.refreshedAt ? "UPDATED " + root.source.refreshedAt : "WAITING"; color: root.autonomousColor; font.family: Style.font.menuFamily; font.pixelSize: 9; font.bold: true }
            }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "[ M ] RETURN TO ORBIT   ·   [ ESC ] CLOSE"
            color: root.theme.faintTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: 9
            font.letterSpacing: 1
        }
    }
}
