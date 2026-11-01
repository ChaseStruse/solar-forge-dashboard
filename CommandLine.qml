import QtQuick
import qs.Commons

// Bottom command prompt. Emits raw command text; Dashboard interprets it.
Item {
    id: root
    required property DashboardTheme theme
    property string prompt: "forge@omarchy"
    property string hint: ""
    property var history: []
    property int historyIndex: -1
    signal submitted(string command)
    signal dismissed()
    readonly property bool active: input.activeFocus
    implicitHeight: 52

    function focusInput(prefill) {
        if (prefill !== undefined)
            input.text = prefill;
        input.forceActiveFocus();
        input.cursorPosition = input.text.length;
    }

    HudFrame {
        anchors.fill: parent
        theme: root.theme
        active: root.active
        tag: ""
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 26
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Text {
            id: promptText
            text: root.prompt
            color: root.theme.secondaryAccentColor
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontBody + 2
            font.bold: true
        }
        Text {
            text: "~ ❯"
            color: root.theme.accentColor
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontBody + 2
            font.bold: true
        }
    }

    TextInput {
        id: input
        anchors.left: parent.left
        anchors.leftMargin: 26 + promptText.implicitWidth + 50
        anchors.right: hintText.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        color: root.theme.foregroundColor
        selectionColor: Util.alpha(root.theme.accentColor, 0.4)
        font.family: Style.font.menuFamily
        font.pixelSize: root.theme.fontBody + 2
        clip: true
        cursorDelegate: Rectangle {
            width: 9
            color: root.theme.accentColor
            visible: input.activeFocus
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: input.activeFocus
                NumberAnimation { to: 0; duration: 0 }
                PauseAnimation { duration: 480 }
                NumberAnimation { to: 1; duration: 0 }
                PauseAnimation { duration: 480 }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !input.text.length
            text: input.activeFocus ? "type help for commands" : "press  :  to command the forge"
            color: root.theme.faintTextColor
            font: input.font
        }

        Keys.onReturnPressed: submit()
        Keys.onEnterPressed: submit()
        Keys.onEscapePressed: {
            input.text = "";
            root.historyIndex = -1;
            root.dismissed();
        }
        Keys.onUpPressed: recall(1)
        Keys.onDownPressed: recall(-1)

        function submit() {
            var command = text.trim();
            text = "";
            root.historyIndex = -1;
            if (!command.length)
                return;
            root.history = [command].concat(root.history.filter(function(h) { return h !== command; })).slice(0, 50);
            root.submitted(command);
        }
        function recall(delta) {
            if (!root.history.length)
                return;
            root.historyIndex = Math.max(-1, Math.min(root.history.length - 1, root.historyIndex + delta));
            text = root.historyIndex < 0 ? "" : root.history[root.historyIndex];
            cursorPosition = text.length;
        }
    }

    Text {
        id: hintText
        anchors.right: parent.right
        anchors.rightMargin: 26
        anchors.verticalCenter: parent.verticalCenter
        text: root.hint
        color: root.theme.faintTextColor
        font.family: Style.font.menuFamily
        font.pixelSize: root.theme.fontMicro
        font.letterSpacing: 1.2
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: root.focusInput()
    }
}
