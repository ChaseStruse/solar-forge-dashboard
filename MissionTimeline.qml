import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons

Item {
    id: root
    required property DashboardTheme theme
    required property MissionControlSource source
    required property TodoStore taskStore
    required property ReminderBridgeSource reminderSource
    property bool selected: false
    property bool audioEnabled: false
    property real eventGlow: 0
    property double currentTime: Date.now()
    signal dismissRequested()
    signal replayBriefing()
    implicitHeight: content.implicitHeight + 48

    readonly property color autonomousColor: "#62d6b3"
    readonly property color weatherColor: "#70b9df"

    function outstandingTasks(limit) {
        var result = []
        for (var i = 0; i < taskStore.model.count && result.length < limit; i++) {
            var task = taskStore.model.get(i)
            if (!task.done)
                result.push({ title: task.title, reminderDue: Number(task.reminderDue || 0) })
        }
        return result
    }

    function upcomingReminders(limit) {
        return reminderSource.reminders.slice().sort(function(left, right) {
            return Number(left.at || 0) - Number(right.at || 0)
        }).slice(0, limit)
    }

    function countdown(due) {
        var seconds = Math.max(0, Math.ceil((Number(due) - currentTime) / 1000))
        var hours = Math.floor(seconds / 3600)
        var minutes = Math.floor((seconds % 3600) / 60)
        if (hours > 0)
            return hours + "h " + minutes + "m"
        return minutes + "m"
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.visible && root.reminderSource.reminders.length > 0
        onTriggered: root.currentTime = Date.now()
    }

    onSourceChanged: eventGlow = 0
    Connections {
        target: root.source
        function onRefreshedAtChanged() {
            if (!root.source.refreshedAt) return
            updatePulse.restart()
            if (root.audioEnabled && !audioCue.running) audioCue.running = true
        }
    }
    SequentialAnimation {
        id: updatePulse
        NumberAnimation { target: root; property: "eventGlow"; to: 0.12; duration: 130 }
        NumberAnimation { target: root; property: "eventGlow"; to: 0; duration: 720 }
    }
    Process {
        id: audioCue
        command: ["canberra-gtk-play", "-i", "message-new-instant"]
    }

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
    Rectangle { anchors.fill: parent; radius: 12; color: root.autonomousColor; opacity: root.eventGlow }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 24
        spacing: 20

        GridLayout {
            width: parent.width
            columns: 3
            columnSpacing: 10
            rowSpacing: 16
            Column {
                Layout.columnSpan: 3
                Layout.fillWidth: true
                spacing: 5
                Text {
                    text: "MISSION CONTROL"
                    color: root.theme.accentColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: 12
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
                    font.pixelSize: 12
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 158
                implicitHeight: 30
                radius: 15
                color: Util.alpha(root.autonomousColor, 0.10)
                border.color: Util.alpha(root.autonomousColor, 0.42)
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Rectangle {
                        width: 7; height: 7; radius: 4; color: root.autonomousColor
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.source.loading
                            NumberAnimation { to: 0.25; duration: 520 }
                            NumberAnimation { to: 1; duration: 520 }
                        }
                    }
                    Text { text: root.source.loading ? "SYNCING" : "SYNC COMPLETE"; color: root.autonomousColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.8 }
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 92
                implicitHeight: 30
                radius: 15
                color: root.audioEnabled ? Util.alpha(root.autonomousColor, 0.11) : root.theme.surfaceColor
                border.color: root.audioEnabled ? Util.alpha(root.autonomousColor, 0.5) : root.theme.borderColor
                Text { anchors.centerIn: parent; text: root.audioEnabled ? "SFX  ON" : "SFX  OFF"; color: root.audioEnabled ? root.autonomousColor : root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.8 }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.audioEnabled = !root.audioEnabled
                        if (root.audioEnabled && !audioCue.running) audioCue.running = true
                    }
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 158
                implicitHeight: 30
                radius: 15
                color: root.theme.surfaceColor
                border.color: root.theme.borderColor
                Text { anchors.centerIn: parent; text: "REPLAY BRIEFING"; color: root.theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 0.8 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.replayBriefing() }
            }
        }

        GridLayout {
            width: parent.width
            columns: root.width < 800 ? 2 : 5
            columnSpacing: 10
            Repeater {
                model: [
                    { label: "REPOSITORIES", value: String(root.source.repositories.length), unit: "SYNCED", note: root.source.githubStatus, tone: "accent" },
                    { label: "LATEST ACTIVITY", value: root.source.events.length ? root.source.events[0].time : "—", unit: "LOCAL", note: root.source.events.length ? root.source.events[0].title : "No GitHub activity", tone: "autonomous" },
                    { label: "OUTSTANDING", value: String(root.taskStore.remaining), unit: "TASKS", note: root.taskStore.remaining ? "Objectives awaiting completion" : "All objectives complete", tone: "urgent" },
                    { label: "REMINDERS", value: String(root.reminderSource.reminders.length), unit: "UPCOMING", note: root.reminderSource.status, tone: "accent" },
                    { label: "WEATHER", value: root.source.weatherCondition, unit: "", note: root.source.weatherLocation + " · " + root.source.weatherValue, tone: "weather" }
                ]
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 126
                    radius: 7
                    color: root.theme.surfaceColor
                    border.color: root.theme.borderColor
                    Column {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 6
                        Text { text: modelData.label; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.1 }
                        RowLayout {
                            width: parent.width
                            spacing: 6
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; textFormat: Text.PlainText; text: modelData.value; color: root.toneColor(modelData.tone); font.family: Style.font.menuFamily; font.pixelSize: 24; font.bold: true }
                            Text { Layout.alignment: Qt.AlignBaseline; text: modelData.unit; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 12 }
                        }
                        Text { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText; text: modelData.note; color: root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 12 }
                    }
                }
            }
        }

        Rectangle {
            id: ticker
            width: parent.width
            height: 28
            clip: true
            color: Util.alpha(root.theme.foregroundColor, 0.025)
            border.color: root.theme.borderColor
            Text {
                id: tickerText
                anchors.verticalCenter: parent.verticalCenter
                text: "GITHUB  //  " + (root.source.events.length ? root.source.events[0].title : root.source.githubStatus)
                    + "     WEATHER  //  " + root.source.weatherCondition + " · " + root.source.weatherValue
                    + "     LAST SYNC  //  " + (root.source.refreshedAt || "WAITING")
                color: root.theme.dimmedTextColor
                font.family: Style.font.menuFamily
                font.pixelSize: 12
                font.letterSpacing: 1
                NumberAnimation on x {
                    from: ticker.width
                    to: -tickerText.implicitWidth
                    duration: 19000
                    loops: Animation.Infinite
                    running: root.visible
                }
            }
        }

        Rectangle {
            width: parent.width
            height: Math.max(76, statusText.implicitHeight + 48)
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
                    Text { text: "SOURCE STATUS"; color: root.theme.urgentColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1 }
                    Text { id: statusText; width: parent.width; wrapMode: Text.Wrap; textFormat: Text.PlainText; text: root.source.githubStatus + " · " + root.source.weatherStatus; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 12 }
                }
                Text { text: "LIVE DATA"; color: root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.letterSpacing: 1 }
            }
        }

        GridLayout {
            width: parent.width
            columns: root.width < 800 ? 1 : 2
            columnSpacing: 28
            rowSpacing: 24
            TimelineLane {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                theme: root.theme
                title: "RECENT REPOSITORY ACTIVITY"
                subtitle: "GITHUB"
                events: root.source.events
                future: false
                autonomousColor: root.autonomousColor
                weatherColor: root.weatherColor
            }
            TimelineLane {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                theme: root.theme
                title: "CURRENT CONDITIONS"
                subtitle: "OMARCHY WEATHER"
                events: root.source.weatherEvents
                future: false
                autonomousColor: root.autonomousColor
                weatherColor: root.weatherColor
            }
            Rectangle {
                objectName: "outstandingTasksLane"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                implicitHeight: taskLane.implicitHeight + 28
                radius: 7
                color: root.theme.surfaceColor
                border.color: root.theme.borderColor
                Column {
                    id: taskLane
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 8
                    Text { text: "OUTSTANDING TASKS"; color: root.theme.urgentColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.1 }
                    Text { visible: root.taskStore.remaining === 0; text: "No outstanding objectives."; color: root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 12 }
                    Repeater {
                        model: root.outstandingTasks(5)
                        RowLayout {
                            required property var modelData
                            width: taskLane.width
                            spacing: 8
                            Text { text: "□"; color: root.theme.urgentColor; font.family: Style.font.menuFamily; font.pixelSize: 13 }
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; textFormat: Text.PlainText; text: modelData.title; color: root.theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 12 }
                            Text { visible: modelData.reminderDue > 0; text: "REMINDER SET"; color: root.theme.accentColor; font.family: Style.font.menuFamily; font.pixelSize: 10; font.bold: true }
                        }
                    }
                    Text { visible: root.taskStore.remaining > 5; text: "+ " + (root.taskStore.remaining - 5) + " more objectives"; color: root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 11 }
                }
            }
            Rectangle {
                objectName: "upcomingRemindersLane"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignTop
                implicitHeight: reminderLane.implicitHeight + 28
                radius: 7
                color: root.theme.surfaceColor
                border.color: root.theme.borderColor
                Column {
                    id: reminderLane
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 8
                    Text { text: "UPCOMING REMINDERS"; color: root.theme.accentColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.1 }
                    Text { visible: root.reminderSource.reminders.length === 0; text: "No reminders scheduled."; color: root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 12 }
                    Repeater {
                        model: root.upcomingReminders(5)
                        RowLayout {
                            required property var modelData
                            width: reminderLane.width
                            spacing: 8
                            Text { text: "◉"; color: root.theme.accentColor; font.family: Style.font.menuFamily; font.pixelSize: 11 }
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; textFormat: Text.PlainText; text: modelData.label; color: root.theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 12 }
                            Text { text: "T−" + root.countdown(modelData.at) + " · " + modelData.atTime; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 10 }
                        }
                    }
                    Text { visible: root.reminderSource.reminders.length > 5; text: "+ " + (root.reminderSource.reminders.length - 5) + " more reminders"; color: root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 11 }
                }
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
                Text { text: "DATA SOURCES"; color: root.autonomousColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.2 }
                Text { Layout.fillWidth: true; elide: Text.ElideRight; text: "Local objectives · Omarchy reminders · GitHub CLI · Omarchy weather"; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 12 }
                Text { text: root.source.refreshedAt ? "UPDATED " + root.source.refreshedAt : "WAITING"; color: root.autonomousColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true }
            }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "[ M ] RETURN TO ORBIT   ·   [ ESC ] RELEASE FOCUS"
            color: root.theme.faintTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: 12
            font.letterSpacing: 1
        }
    }
}
