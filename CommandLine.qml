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
    // function(text) → [{ value, label, hint }]
    property var completer: null
    property var suggestions: []
    property int suggestionIndex: 0
    readonly property bool suggesting: input.activeFocus && input.text.length > 0 && suggestions.length > 0
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

        onTextChanged: {
            root.suggestions = root.completer && text.length ? root.completer(text) : [];
            root.suggestionIndex = 0;
        }
        Keys.onReturnPressed: submit()
        Keys.onEnterPressed: submit()
        Keys.onEscapePressed: {
            if (root.suggesting) {
                root.suggestions = [];
                return;
            }
            input.text = "";
            root.historyIndex = -1;
            root.dismissed();
        }
        Keys.onTabPressed: accept()
        Keys.onUpPressed: root.suggesting ? root.suggestionIndex = Math.max(0, root.suggestionIndex - 1) : recall(1)
        Keys.onDownPressed: root.suggesting ? root.suggestionIndex = Math.min(root.suggestions.length - 1, root.suggestionIndex + 1) : recall(-1)

        function accept() {
            var pick = root.suggestions[root.suggestionIndex];
            if (!pick)
                return;
            text = pick.value;
            cursorPosition = text.length;
        }

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

    Column {
        id: popup
        visible: root.suggesting
        anchors.left: parent.left
        anchors.leftMargin: 26 + promptText.implicitWidth + 50
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        width: Math.min(560, parent.width * 0.5)
        Repeater {
            model: root.suggestions
            Rectangle {
                required property var modelData
                required property int index
                readonly property bool current: index === root.suggestionIndex
                width: popup.width
                height: 30
                color: current ? Util.alpha(root.theme.accentColor, 0.22) : Util.alpha(root.theme.backgroundColor, 0.94)
                border.color: Util.alpha(root.theme.accentColor, current ? 0.8 : 0.25)
                Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: current ? root.theme.foregroundColor : root.theme.dimmedTextColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: root.theme.fontSmall
                    font.bold: current
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: (current ? "TAB  ·  " : "") + String(modelData.hint || "").toUpperCase()
                    color: root.theme.faintTextColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: root.theme.fontMicro
                    font.letterSpacing: 1
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { root.suggestionIndex = index; input.accept(); input.forceActiveFocus(); }
                }
            }
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
