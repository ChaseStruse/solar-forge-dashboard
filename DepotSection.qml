import QtQuick
import Quickshell
import qs.Commons

// Supply depot: pending repo/AUR upgrades, Omarchy release state, and a
// one-key full update in a floating terminal.
FocusScope {
    id: root
    required property DashboardTheme theme
    required property ScriptSource source
    property bool selected: false
    property real availableHeight: 640
    property int index: 0
    signal dismissRequested()
    signal updateLaunched()
    implicitHeight: layout.implicitHeight

    onSelectedChanged: if (selected) Qt.callLater(focusControls)
    function focusControls() {
        forceActiveFocus();
    }

    readonly property var depot: source.data || ({ version: "—", omarchyStatus: "", omarchyReady: false, repo: [], aur: [], lastUpgrade: "" })
    readonly property var packages: (depot.repo || []).map(function(p) { p.origin = "REPO"; return p; })
        .concat((depot.aur || []).map(function(p) { p.origin = "AUR"; return p; }))
    readonly property int pending: packages.length + (depot.omarchyReady ? 1 : 0)

    function sinceLast() {
        var stamp = Date.parse(String(depot.lastUpgrade || "").replace(/([+-]\d\d)(\d\d)$/, "$1:$2"));
        if (isNaN(stamp)) return "—";
        var days = Math.floor((Date.now() - stamp) / 86400000);
        return days <= 0 ? "TODAY" : days === 1 ? "1 DAY" : days + " DAYS";
    }
    function launchUpdate() {
        Quickshell.execDetached(["omarchy", "launch", "floating", "terminal", "with", "presentation", "omarchy", "update"]);
        updateLaunched();
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_J) index = Math.min(packages.length - 1, index + 1);
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) index = Math.max(0, index - 1);
        else if (event.key === Qt.Key_U || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) launchUpdate();
        else if (event.key === Qt.Key_F5) source.refresh();
        else if (event.key === Qt.Key_Escape) root.dismissRequested();
        else return;
        event.accepted = true;
        list.positionViewAtIndex(index, ListView.Contain);
    }

    Column {
        id: layout
        width: parent.width
        spacing: 22

        PanelHeader {
            theme: root.theme
            eyebrow: "SUPPLY DEPOT"
            title: root.pending ? root.pending + " SHIPMENTS WAITING" : "DEPOT CURRENT"
            subtitle: "Omarchy " + root.depot.version + "  ·  " + (root.depot.omarchyStatus || "release status unknown")
                + "  ·  U or Enter runs a full update in a floating terminal · F5 rescans"
            status: root.source.loading ? "SCANNING MIRRORS" : root.source.error || (root.pending ? "UPDATE READY" : "ALL CURRENT")
            warning: root.pending > 0 || root.source.error.length > 0
            busy: root.source.loading
        }

        Row {
            width: parent.width
            spacing: 10
            StatTile { width: (parent.width - 30) / 4; theme: root.theme; label: "REPO PACKAGES"; value: String((root.depot.repo || []).length); tone: (root.depot.repo || []).length ? root.theme.urgentColor : root.theme.accentColor }
            StatTile { width: (parent.width - 30) / 4; theme: root.theme; label: "AUR PACKAGES"; value: String((root.depot.aur || []).length); tone: (root.depot.aur || []).length ? root.theme.urgentColor : root.theme.accentColor }
            StatTile { width: (parent.width - 30) / 4; theme: root.theme; label: "OMARCHY"; value: root.depot.omarchyReady ? "NEW" : root.depot.version; tone: root.depot.omarchyReady ? root.theme.urgentColor : root.theme.secondaryAccentColor }
            StatTile { width: (parent.width - 30) / 4; theme: root.theme; label: "SINCE LAST UPGRADE"; value: root.sinceLast() }
        }

        Row {
            spacing: 10
            HudButton {
                theme: root.theme
                glyph: "󰚰"
                label: "RUN FULL UPDATE  [U]"
                active: root.pending > 0
                onClicked: root.launchUpdate()
            }
            HudButton {
                theme: root.theme
                glyph: "󰑐"
                label: "RESCAN  [F5]"
                available: !root.source.loading
                onClicked: root.source.refresh()
            }
        }

        Column {
            width: parent.width
            spacing: 8
            Text {
                text: "MANIFEST  //  " + root.packages.length + " PACKAGES"
                color: root.theme.accentColor
                font.family: Style.font.menuFamily
                font.pixelSize: root.theme.fontMicro
                font.bold: true
                font.letterSpacing: 1.8
            }
            ListView {
                id: list
                width: parent.width
                height: Math.max(200, Math.min(contentHeight, root.availableHeight - 330))
                clip: true
                spacing: 3
                model: root.packages
                boundsBehavior: Flickable.StopAtBounds
                delegate: HudRow {
                    required property var modelData
                    required property int index
                    width: list.width
                    theme: root.theme
                    selected: index === root.index && root.activeFocus
                    glyph: modelData.origin === "AUR" ? "󰣇" : "󰏗"
                    tone: modelData.origin === "AUR" ? root.theme.secondaryAccentColor : root.theme.accentColor
                    title: modelData.name
                    detail: modelData.from + "  →  " + modelData.to
                    trailing: modelData.origin
                    onPicked: { root.index = index; root.forceActiveFocus(); }
                }
                Text {
                    anchors.centerIn: parent
                    visible: !root.packages.length
                    text: root.source.loading ? "QUERYING MIRRORS…" : "NO PENDING SHIPMENTS"
                    color: root.theme.faintTextColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: root.theme.fontSmall
                    font.letterSpacing: 2
                }
            }
        }
    }
}
