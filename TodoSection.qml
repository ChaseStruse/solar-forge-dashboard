import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

Column {
    id: root
    required property DashboardTheme theme
    required property TodoStore store
    required property ReminderBridgeSource reminderSource
    property bool selected: false
    property int reminderTaskId: -1
    property string reminderTaskTitle: ""
    property double currentTime: Date.now()
    readonly property alias viewport: todoViewport
    signal dismissRequested

    spacing: 12
    topPadding: 8
    bottomPadding: 4

    function focusInput() {
        newTodoInput.forceActiveFocus();
    }
    function submit() {
        if (store.add(newTodoInput.text))
            newTodoInput.text = "";
        focusInput();
    }
    function countdown(due) {
        var seconds = Math.max(0, Math.ceil((Number(due) - currentTime) / 1000));
        var minutes = Math.floor(seconds / 60);
        var remainder = seconds % 60;
        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.reminderSource.reminders.length > 0
        onTriggered: root.currentTime = Date.now()
    }

    RowLayout {
        width: parent.width
        Text {
            Layout.fillWidth: true
            text: "OBJECTIVES COMMAND CENTER"
            color: root.theme.urgentColor
            font.family: Style.font.menuFamily
            font.pixelSize: 17
            font.bold: true
            font.letterSpacing: 1.7
        }
        Text {
            text: root.store.error ? "STORAGE DEGRADED" : "LOCAL DATA ONLINE"
            color: root.store.error ? root.theme.urgentColor : root.theme.secondaryAccentColor
            font.family: Style.font.menuFamily
            font.pixelSize: 11
            font.bold: true
        }
    }

    GridLayout {
        width: parent.width
        columns: root.width < 650 ? 2 : 4
        columnSpacing: 10
        rowSpacing: 10
        Repeater {
            model: [
                { label: "ACTIVE", value: root.store.activeCount, tone: "urgent" },
                { label: "CLOSED", value: root.store.closedCount, tone: "autonomous" },
                { label: "REMINDERS", value: root.reminderSource.reminders.length, tone: "accent" },
                { label: "TOTAL", value: root.store.totalCount, tone: "neutral" }
            ]
            delegate: Rectangle {
                required property int index
                required property var modelData
                readonly property color toneColor: modelData.tone === "urgent" ? root.theme.urgentColor
                    : modelData.tone === "autonomous" ? root.theme.secondaryAccentColor
                    : modelData.tone === "accent" ? root.theme.accentColor : root.theme.foregroundColor
                Layout.fillWidth: true
                implicitWidth: 150
                implicitHeight: 72
                color: Util.alpha(toneColor, 0.07)
                border.color: Util.alpha(toneColor, 0.3)
                border.width: 1
                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: String(modelData.value)
                        color: parent.parent.toneColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 23
                        font.bold: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        color: root.theme.dimmedTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 10
                        font.letterSpacing: 1
                    }
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 48
        color: root.theme.surfaceColor
        border.color: newTodoInput.activeFocus ? root.theme.accentColor : root.theme.borderColor
        border.width: 1

        TextInput {
            id: newTodoInput
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            verticalAlignment: TextInput.AlignVCenter
            color: root.theme.foregroundColor
            font.family: Style.font.menuFamily
            font.pixelSize: 14
            clip: true
            onAccepted: root.submit()
            Keys.onEscapePressed: root.dismissRequested()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !newTodoInput.text
                text: "+ add an objective, then press Enter"
                color: root.theme.faintTextColor
                font: newTodoInput.font
            }
        }
    }

    Rectangle {
        width: parent.width
        height: root.reminderTaskId >= 0 ? 46 : 0
        visible: height > 0
        color: root.theme.completedSurfaceColor
        border.color: root.theme.accentColor
        clip: true
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: "REMINDER UPLINK // " + root.reminderTaskTitle
                color: root.theme.dimmedTextColor
                font.family: Style.font.menuFamily
                font.pixelSize: 10
                font.bold: true
            }
            Repeater {
                model: [5, 25, 50]
                Rectangle {
                    required property int modelData
                    width: 48
                    height: 28
                    radius: 4
                    color: presetMouse.containsMouse ? root.theme.surfaceColor : "transparent"
                    border.color: root.theme.borderColor
                    Text {
                        anchors.centerIn: parent
                        text: modelData + "m"
                        color: root.theme.foregroundColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 10
                        font.bold: true
                    }
                    MouseArea {
                        id: presetMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.reminderSource.schedule(root.reminderTaskId, root.reminderTaskTitle, modelData))
                                root.reminderTaskId = -1;
                        }
                    }
                }
            }
            Text {
                text: "×"
                color: root.theme.faintTextColor
                font.pixelSize: 18
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.reminderTaskId = -1
                }
            }
        }
    }

    GridLayout {
        width: parent.width
        columns: root.width < 720 ? 1 : 3
        columnSpacing: 12
        rowSpacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.columnSpan: root.width < 720 ? 1 : 2
            Layout.preferredWidth: root.width * 0.66
            implicitHeight: 326
            color: root.theme.surfaceColor
            border.color: root.theme.borderColor
            border.width: 1

            Text {
                id: queueHeader
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 12
                text: "OBJECTIVE QUEUE  //  " + root.store.totalCount
                color: root.theme.foregroundColor
                font.family: Style.font.menuFamily
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1
            }

            ListView {
                id: todoViewport
                objectName: "todoViewport"
                readonly property int rowHeight: 40
                readonly property int visibleRows: 6
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: queueHeader.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 12
                anchors.topMargin: 10
                spacing: 7
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.store.model
                delegate: Rectangle {
                    required property int taskId
                    required property string title
                    required property bool done
                    required property string reminderUnit
                    required property double reminderDue
                    width: todoViewport.width - (todoScrollbar.visible ? todoScrollbar.width + 6 : 0)
                    height: todoViewport.rowHeight
                    color: done ? root.theme.completedSurfaceColor : "transparent"
                    border.color: done ? root.theme.borderColor : Util.alpha(root.theme.accentColor, 0.24)
                    border.width: 1

                    Rectangle {
                        id: completionBox
                        width: 17
                        height: 17
                        anchors.left: parent.left
                        anchors.leftMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        color: done ? root.theme.secondaryAccentColor : "transparent"
                        border.color: done ? root.theme.secondaryAccentColor : root.theme.accentColor
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: done ? "✓" : ""
                            color: root.theme.backgroundColor
                            font.bold: true
                            font.pixelSize: 13
                        }
                    }
                    Text {
                        anchors.left: completionBox.right
                        anchors.leftMargin: 10
                        anchors.right: taskState.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: title
                        textFormat: Text.PlainText
                        color: done ? root.theme.faintTextColor : root.theme.foregroundColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        font.strikeout: done
                    }
                    Text {
                        id: taskState
                        anchors.right: reminderButton.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: done ? "CLOSED" : reminderUnit ? "T−" + root.countdown(reminderDue) : "ACTIVE"
                        color: done ? root.theme.faintTextColor : reminderUnit ? root.theme.accentColor : root.theme.urgentColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 9
                        font.bold: true
                    }
                    Rectangle {
                        id: reminderButton
                        width: 28
                        height: 28
                        radius: 4
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: reminderUnit ? root.theme.accentColor : "transparent"
                        border.color: reminderUnit ? root.theme.accentColor : root.theme.borderColor
                        visible: !done
                        Text {
                            anchors.centerIn: parent
                            text: reminderUnit ? "󰃰" : "󰔛"
                            color: reminderUnit ? root.theme.backgroundColor : root.theme.dimmedTextColor
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.reminderTaskId = taskId;
                                root.reminderTaskTitle = title;
                            }
                        }
                        ToolTip.visible: reminderHover.containsMouse
                        ToolTip.text: reminderUnit ? "Reminder linked" : "Turn into reminder"
                        MouseArea { id: reminderHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    }
                    MouseArea {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: reminderButton.left
                        onClicked: {
                            if (!done && reminderUnit) root.reminderSource.cancel(reminderUnit);
                            root.store.setDone(taskId, !done);
                        }
                    }
                }
                ScrollBar.vertical: ScrollBar {
                    id: todoScrollbar
                    policy: todoViewport.count > todoViewport.visibleRows ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                }
            }

            Text {
                anchors.centerIn: parent
                visible: root.store.model.count === 0
                text: "No objectives queued. Add the first one above."
                color: root.theme.faintTextColor
                font.family: Style.font.menuFamily
                font.pixelSize: 13
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredWidth: root.width * 0.34
            implicitHeight: 326
            color: Util.alpha(root.theme.accentColor, 0.04)
            border.color: root.theme.borderColor
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 9
                Text {
                    width: parent.width
                    text: "INBOUND TRANSMISSIONS  //  " + root.reminderSource.reminders.length
                    color: root.theme.accentColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 0.8
                }
                Repeater {
                    model: root.reminderSource.reminders.slice(0, 5)
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width
                        height: 42
                        color: root.theme.surfaceColor
                        border.color: Util.alpha(root.theme.accentColor, 0.25)
                        border.width: 1
                        Column {
                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 2
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: modelData.label
                                color: root.theme.foregroundColor
                                font.family: Style.font.menuFamily
                                font.pixelSize: 10
                            }
                            Text {
                                text: "T−" + root.countdown(modelData.at) + "  ·  ETA " + modelData.atTime
                                color: root.theme.accentColor
                                font.family: Style.font.menuFamily
                                font.pixelSize: 9
                                font.bold: true
                            }
                        }
                    }
                }
                Text {
                    width: parent.width
                    visible: root.reminderSource.reminders.length === 0
                    wrapMode: Text.Wrap
                    text: "No reminders linked. Use the bell beside an active objective to schedule one."
                    color: root.theme.faintTextColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: 11
                }
            }
        }
    }

    Text {
        width: parent.width
        visible: root.store.error !== ""
        text: root.store.error
        color: root.theme.urgentColor
        wrapMode: Text.Wrap
        font.family: Style.font.menuFamily
    }

    Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "[ ENTER ] ADD OBJECTIVE  ·  [ CLICK ] TOGGLE STATUS  ·  [ ESC ] ORBIT"
        color: root.theme.faintTextColor
        font.family: Style.font.menuFamily
        font.pixelSize: 10
    }
}
