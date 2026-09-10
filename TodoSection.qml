import QtQuick
import QtQuick.Controls
import qs.Commons

Column {
    id: root
    required property DashboardTheme theme
    required property TodoStore store
    property bool selected: false
    signal dismissRequested

    function focusInput() {
        newTodoInput.forceActiveFocus();
    }
    function submit() {
        if (store.add(newTodoInput.text))
            newTodoInput.text = "";
        focusInput();
    }

    spacing: 8
    topPadding: 12

    Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: "TODAY'S OBJECTIVES // " + root.store.remaining + " ACTIVE"
        color: root.selected ? root.theme.urgentColor : root.theme.dimmedTextColor
        font.family: root.theme.fontFamily
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
            font.family: root.theme.fontFamily
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
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: title
                textFormat: Text.PlainText
                color: done ? root.theme.faintTextColor : root.theme.foregroundColor
                font.family: root.theme.fontFamily
                font.pixelSize: 14
                elide: Text.ElideRight
                font.strikeout: done
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.store.setDone(taskId, !done)
            }
        }
        ScrollBar.vertical: ScrollBar {
            id: todoScrollbar
            policy: todoViewport.count > todoViewport.visibleRows ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
        }
    }
    Text {
        width: parent.width
        visible: root.store.error !== ""
        text: root.store.error
        color: root.theme.urgentColor
        wrapMode: Text.Wrap
        font.family: root.theme.fontFamily
    }

    Text {
        visible: root.store.model.count === 0
        text: "No objectives queued. Add the first one above."
        color: root.theme.faintTextColor
        font.family: root.theme.fontFamily
        font.pixelSize: 13
    }
}
