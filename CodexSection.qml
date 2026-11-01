import QtQuick
import qs.Commons

// Keybind codex: every described Hyprland binding, searchable as you type.
FocusScope {
    id: root
    required property DashboardTheme theme
    required property ScriptSource source
    property bool selected: false
    property real availableHeight: 640
    property string query: ""
    signal dismissRequested()
    implicitHeight: Math.max(480, availableHeight)

    onSelectedChanged: if (selected) Qt.callLater(focusControls)
    function focusControls() {
        filter.forceActiveFocus();
        filter.selectAll();
    }
    function search(text) {
        query = String(text || "");
    }

    function chord(bind) {
        var mods = [];
        var m = Number(bind.modmask || 0);
        if (m & 64) mods.push("SUPER");
        if (m & 4) mods.push("CTRL");
        if (m & 8) mods.push("ALT");
        if (m & 1) mods.push("SHIFT");
        var key = String(bind.key || "");
        if (bind.mouse) key = key.replace("mouse:272", "LMB").replace("mouse:273", "RMB");
        key = key.replace(/^XF86/, "").replace("RETURN", "ENTER");
        return mods.concat([key.toUpperCase()]).join(" + ");
    }
    readonly property var binds: ((source.data || {}).binds || []).map(function(b) {
        return { chord: chord(b), description: String(b.description), haystack: (chord(b) + " " + b.description).toLowerCase() };
    })
    readonly property var matches: {
        var terms = query.toLowerCase().split(/\s+/).filter(function(t) { return t.length; });
        return binds.filter(function(b) {
            return terms.every(function(t) { return b.haystack.indexOf(t) >= 0; });
        });
    }

    Column {
        id: layout
        width: parent.width
        spacing: 18

        PanelHeader {
            theme: root.theme
            eyebrow: "KEYBIND CODEX"
            title: root.binds.length + " CHORDS INDEXED"
            subtitle: "Type to filter by key or action, e.g. \"super shift\" or \"screenshot\". Read live from Hyprland."
            status: root.matches.length + " MATCHES"
            busy: root.source.loading
        }

        Rectangle {
            width: parent.width
            height: 50
            color: Util.alpha(root.theme.accentColor, 0.06)
            border.color: filter.activeFocus ? root.theme.accentColor : root.theme.borderColor
            Text {
                id: filterPrompt
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "SEARCH ❯"
                color: root.theme.secondaryAccentColor
                font.family: Style.font.menuFamily
                font.pixelSize: 16
                font.bold: true
                font.letterSpacing: 2
            }
            TextInput {
                id: filter
                anchors.left: filterPrompt.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.query
                onTextChanged: root.query = text
                color: root.theme.foregroundColor
                font.family: Style.font.menuFamily
                font.pixelSize: 18
                clip: true
                Keys.onEscapePressed: if (text.length) text = ""; else root.dismissRequested()
                Keys.onDownPressed: grid.contentY = Math.min(grid.contentY + 60, Math.max(0, grid.contentHeight - grid.height))
                Keys.onUpPressed: grid.contentY = Math.max(0, grid.contentY - 60)
            }
        }

        GridView {
            id: grid
            width: parent.width
            height: Math.max(300, root.availableHeight - 170)
            clip: true
            cellWidth: width / Math.max(1, Math.floor(width / 420))
            cellHeight: 46
            model: root.matches
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    color: hover.containsMouse ? root.theme.surfaceColor : "transparent"
                    border.color: Util.alpha(root.theme.accentColor, 0.18)
                    Text {
                        id: keys
                        x: 12
                        width: Math.min(parent.width * 0.48, implicitWidth)
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: modelData.chord
                        color: root.theme.accentColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: root.theme.fontMicro
                        font.bold: true
                    }
                    Text {
                        anchors.left: keys.right
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: modelData.description
                        color: root.theme.foregroundColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: root.theme.fontSmall
                    }
                    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true }
                }
            }
        }
    }
}
