import QtQuick
import QtQuick.Controls
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
    signal dismissRequested

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

    spacing: 8
    topPadding: 12

    Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: "TODAY'S OBJECTIVES // " + root.store.remaining + " ACTIVE"
        color: root.selected ? root.theme.urgentColor : root.theme.dimmedTextColor
        font.family: Style.font.menuFamily
        font.pixelSize: 14
        font.letterSpacing: 1.4
    }

    Rectangle {
        width: parent.width
        height: 42
        color: root.theme.surfaceColor
        border.color: newTodoInput.activeFocus ? root.theme.accentColor : root.theme.borderColor
        border.width: 1

        TextInput {
            id: newTodoInput
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
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
        height: reminderTaskId >= 0 ? 42 : 0
        visible: height > 0
        color: root.theme.completedSurfaceColor
        border.color: root.theme.accentColor
        clip: true
        Row {
            anchors.centerIn: parent
            spacing: 7
            Text {
                text: "REMIND IN"
                color: root.theme.dimmedTextColor
                font.family: Style.font.menuFamily
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
            Repeater {
                model: [5, 25, 50]
                Rectangle {
                    required property int modelData
                    width: 42; height: 26; radius: 5
                    color: presetMouse.containsMouse ? root.theme.surfaceColor : "transparent"
                    border.color: root.theme.borderColor
                    Text {
                        anchors.centerIn: parent
                        text: modelData + "m"
                        color: root.theme.foregroundColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 10; font.bold: true
                    }
                    MouseArea {
                        id: presetMouse
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.reminderSource.schedule(root.reminderTaskId, root.reminderTaskTitle, modelData))
                                root.reminderTaskId = -1;
                        }
                    }
                }
            }
        }
    }

    // Keep the command center compact even when the task backlog grows.
    // This viewport is exactly three task rows high; the scrollbar appears
    // only once there are more rows to browse.
    ListView {
        id: todoViewport
        objectName: "todoViewport"
        readonly property int rowHeight: 38
        readonly property int visibleRows: 3
        width: parent.width
        height: visibleRows * rowHeight + (visibleRows - 1) * spacing
        spacing: 8
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
            color: done ? root.theme.completedSurfaceColor : root.theme.surfaceColor
            border.color: root.theme.borderColor
            border.width: 1

            Rectangle {
                id: completionBox
                width: 16
                height: 16
                anchors.left: parent.left
                anchors.leftMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                color: done ? root.theme.accentColor : "transparent"
                border.color: root.theme.accentColor
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
                anchors.right: reminderButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: title
                textFormat: Text.PlainText
                color: done ? root.theme.faintTextColor : root.theme.foregroundColor
                font.family: Style.font.menuFamily
                font.pixelSize: 14
                elide: Text.ElideRight
                font.strikeout: done
            }
            Rectangle {
                id: reminderButton
                width: 28; height: 28; radius: 5
                anchors.right: parent.right; anchors.rightMargin: 5
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
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
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
    Column {
        width: parent.width
        spacing: 4
        visible: root.reminderSource.reminders.length > 0
        Text {
            text: "INBOUND TRANSMISSIONS // " + root.reminderSource.reminders.length
            color: root.theme.accentColor
            font.family: Style.font.menuFamily
            font.pixelSize: 10
            font.letterSpacing: 1
        }
        Repeater {
            model: root.reminderSource.reminders.slice(0, 3)
            Text {
                required property var modelData
                width: parent.width
                text: "◉ " + modelData.label + "  ·  T−" + root.countdown(modelData.at) + "  ·  ETA " + modelData.atTime
                color: root.theme.dimmedTextColor
                font.family: Style.font.menuFamily
                font.pixelSize: 10
                elide: Text.ElideRight
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
        visible: root.store.model.count === 0
        text: "No objectives queued. Add the first one above."
        color: root.theme.faintTextColor
        font.family: Style.font.menuFamily
        font.pixelSize: 13
    }
}
