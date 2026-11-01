import QtQuick
import Quickshell
import qs.Commons

// Hangar: fuzzy-launch installed apps (like SUPER + SPACE) and jump to or
// close windows that are already running.
FocusScope {
    id: root
    required property DashboardTheme theme
    required property WorkspaceRadarSource radar
    property bool selected: false
    property real availableHeight: 640
    property string query: ""
    property int appIndex: 0
    property int windowIndex: 0
    property bool runningFocus: false
    signal dismissRequested()
    signal launched(string name)
    signal windowFocused(string title)
    signal windowClosed(string title)
    implicitHeight: Math.max(520, availableHeight)

    onSelectedChanged: if (selected) Qt.callLater(focusControls)

    function focusControls() {
        runningFocus = false;
        search.forceActiveFocus();
        search.selectAll();
    }

    // Lower is better; -1 means no match.
    function score(entry, q) {
        var name = String(entry.name || "").toLowerCase();
        if (!q.length) return 1000;
        if (name === q) return 0;
        if (name.indexOf(q) === 0) return 10 + name.length / 100;
        var words = name.split(/[\s\-_.]+/);
        for (var i = 0; i < words.length; i++)
            if (words[i].indexOf(q) === 0) return 20 + i;
        if (name.indexOf(q) > 0) return 40 + name.indexOf(q);
        var extra = (String(entry.genericName || "") + " " + String(entry.comment || "") + " "
            + (entry.keywords ? Array.prototype.join.call(entry.keywords, " ") : "")).toLowerCase();
        if (extra.indexOf(q) >= 0) return 70;
        // Subsequence: "vsc" → "visual studio code".
        var at = 0, gaps = 0;
        for (var c = 0; c < q.length; c++) {
            var found = name.indexOf(q.charAt(c), at);
            if (found < 0) return -1;
            gaps += found - at;
            at = found + 1;
        }
        return 90 + gaps;
    }

    readonly property var apps: {
        var q = query.trim().toLowerCase();
        var values = DesktopEntries.applications.values || [];
        var ranked = [];
        for (var i = 0; i < values.length; i++) {
            var entry = values[i];
            if (!entry || entry.noDisplay) continue;
            var s = score(entry, q);
            if (s >= 0) ranked.push({ entry: entry, score: s });
        }
        ranked.sort(function(a, b) {
            return a.score - b.score || String(a.entry.name).localeCompare(String(b.entry.name));
        });
        return ranked.slice(0, 40).map(function(r) { return r.entry; });
    }
    readonly property var windows: {
        var out = [];
        var spaces = radar.workspaces || [];
        for (var i = 0; i < spaces.length; i++)
            for (var j = 0; j < spaces[i].windows.length; j++) {
                var w = spaces[i].windows[j];
                if (w.title === "Solar Forge Dashboard") continue;
                out.push({ address: w.address, title: w.title, app: w.app, workspace: spaces[i].name || spaces[i].id, urgent: w.urgent === true });
            }
        return out;
    }
    onAppsChanged: appIndex = Math.min(appIndex, Math.max(0, apps.length - 1))
    onWindowsChanged: windowIndex = Math.min(windowIndex, Math.max(0, windows.length - 1))
    onQueryChanged: appIndex = 0

    function iconFor(entry) {
        var icon = String(entry.icon || "");
        if (!icon.length) return "";
        if (icon.charAt(0) === "/") return "file://" + icon;
        return Quickshell.iconPath(icon, true);
    }
    function appGlyph(app) {
        var name = String(app || "").toLowerCase();
        if (/firefox|zen/.test(name)) return "󰈹";
        if (/chrom|brave|browser/.test(name)) return "󰊯";
        if (/foot|kitty|alacritty|ghostty|terminal/.test(name)) return "󰆍";
        if (/code|cursor|zed|jetbrains|nvim/.test(name)) return "󰨞";
        if (/discord|slack|signal|telegram/.test(name)) return "󰭹";
        if (/spotify|music|vlc|mpv/.test(name)) return "󰎆";
        if (/obsidian/.test(name)) return "󱓧";
        return "󰣆";
    }

    function launchAt(index) {
        var entry = apps[index];
        if (!entry) return false;
        Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", String(entry.id) + ".desktop"]);
        launched(String(entry.name));
        return true;
    }
    // Names of the best matches, for command-line completion.
    function matchNames(text, limit) {
        var q = String(text || "").trim().toLowerCase();
        var values = DesktopEntries.applications.values || [];
        var ranked = [];
        for (var i = 0; i < values.length; i++) {
            if (!values[i] || values[i].noDisplay) continue;
            var s = score(values[i], q);
            if (s >= 0) ranked.push({ name: String(values[i].name), score: s });
        }
        ranked.sort(function(a, b) { return a.score - b.score || a.name.localeCompare(b.name); });
        return ranked.slice(0, limit || 8).map(function(r) { return r.name; });
    }
    // Used by the command line: launch the best match for a query.
    function launchQuery(text) {
        query = String(text || "");
        return launchAt(0);
    }
    function focusAt(index) {
        var w = windows[index];
        if (!w || !radar.focusWindow(w.address)) return false;
        windowFocused(w.title);
        return true;
    }
    function closeAt(index) {
        var w = windows[index];
        if (!w || !radar.closeWindow(w.address)) return false;
        windowClosed(w.title);
        return true;
    }

    Keys.onEscapePressed: root.dismissRequested()

    Column {
        id: layout
        width: parent.width
        spacing: 18

        PanelHeader {
            theme: root.theme
            eyebrow: "HANGAR"
            title: "LAUNCH CONTROL"
            subtitle: "Type to search " + (DesktopEntries.applications.values || []).length + " installed applications. Tab switches to running windows."
            status: root.windows.length + " IN FLIGHT"
        }

        // Search field
        Rectangle {
            width: parent.width
            height: 58
            color: Util.alpha(root.theme.accentColor, 0.06)
            border.color: search.activeFocus ? root.theme.accentColor : root.theme.borderColor
            Text {
                id: searchPrompt
                x: 18
                anchors.verticalCenter: parent.verticalCenter
                text: "LAUNCH ❯"
                color: root.theme.secondaryAccentColor
                font.family: Style.font.menuFamily
                font.pixelSize: 18
                font.bold: true
                font.letterSpacing: 2
            }
            TextInput {
                id: search
                anchors.left: searchPrompt.right
                anchors.leftMargin: 14
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: root.query
                onTextChanged: root.query = text
                color: root.theme.foregroundColor
                selectionColor: Util.alpha(root.theme.accentColor, 0.4)
                font.family: Style.font.menuFamily
                font.pixelSize: 22
                clip: true
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !search.text.length
                    text: "app name…"
                    color: root.theme.faintTextColor
                    font: search.font
                }
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Down) {
                        root.appIndex = Math.min(root.apps.length - 1, root.appIndex + 1); event.accepted = true;
                    } else if (event.key === Qt.Key_Up) {
                        root.appIndex = Math.max(0, root.appIndex - 1); event.accepted = true;
                    } else if (event.key === Qt.Key_Tab) {
                        if (root.windows.length) { root.runningFocus = true; runningList.forceActiveFocus(); }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        root.launchAt(root.appIndex); event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        if (search.text.length) search.text = ""; else root.dismissRequested();
                        event.accepted = true;
                    }
                }
            }
        }

        Row {
            width: parent.width
            spacing: 18
            readonly property real listHeight: Math.max(280, root.availableHeight - 190)

            Column {
                width: (parent.width - 18) * 0.6
                spacing: 8
                Text {
                    text: "APPLICATIONS  //  " + root.apps.length
                    color: root.runningFocus ? root.theme.dimmedTextColor : root.theme.accentColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: root.theme.fontMicro
                    font.bold: true
                    font.letterSpacing: 1.8
                }
                ListView {
                    id: appList
                    width: parent.width
                    height: parent.parent.listHeight
                    clip: true
                    spacing: 3
                    model: root.apps
                    currentIndex: root.appIndex
                    highlightFollowsCurrentItem: false
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: HudRow {
                        required property var modelData
                        required property int index
                        width: appList.width
                        theme: root.theme
                        selected: !root.runningFocus && index === root.appIndex
                        icon: root.iconFor(modelData)
                        glyph: "󰣆"
                        title: String(modelData.name || modelData.id)
                        detail: String(modelData.genericName || modelData.comment || "")
                        trailing: selected ? "ENTER ❯ LAUNCH" : ""
                        onPicked: { root.appIndex = index; root.runningFocus = false; search.forceActiveFocus(); }
                        onActivated: root.launchAt(index)
                    }
                }
            }

            Column {
                width: (parent.width - 18) * 0.4
                spacing: 8
                Text {
                    text: "RUNNING NOW  //  " + root.windows.length
                    color: root.runningFocus ? root.theme.accentColor : root.theme.dimmedTextColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: root.theme.fontMicro
                    font.bold: true
                    font.letterSpacing: 1.8
                }
                ListView {
                    id: runningList
                    width: parent.width
                    height: parent.parent.listHeight
                    clip: true
                    spacing: 3
                    model: root.windows
                    boundsBehavior: Flickable.StopAtBounds
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Down) {
                            root.windowIndex = Math.min(root.windows.length - 1, root.windowIndex + 1);
                        } else if (event.key === Qt.Key_Up) {
                            root.windowIndex = Math.max(0, root.windowIndex - 1);
                        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                            root.focusControls();
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.focusAt(root.windowIndex);
                        } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                            root.closeAt(root.windowIndex);
                        } else if (event.key === Qt.Key_Escape) {
                            root.focusControls();
                        } else {
                            return;
                        }
                        event.accepted = true;
                        positionViewAtIndex(root.windowIndex, ListView.Contain);
                    }
                    delegate: HudRow {
                        required property var modelData
                        required property int index
                        width: runningList.width
                        theme: root.theme
                        selected: root.runningFocus && index === root.windowIndex
                        tone: modelData.urgent ? root.theme.urgentColor : root.theme.secondaryAccentColor
                        glyph: root.appGlyph(modelData.app)
                        title: modelData.title
                        detail: String(modelData.app).toUpperCase() + "  ·  WS " + modelData.workspace
                        trailing: selected ? "ENTER FOCUS · ⇧DEL CLOSE" : ""
                        onPicked: { root.windowIndex = index; root.runningFocus = true; runningList.forceActiveFocus(); }
                        onActivated: root.focusAt(index)
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !root.windows.length
                        text: "NO WINDOWS IN FLIGHT"
                        color: root.theme.faintTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: root.theme.fontSmall
                        font.letterSpacing: 2
                    }
                }
            }
        }
    }
}
