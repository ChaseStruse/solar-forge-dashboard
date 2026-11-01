import QtQuick
import qs.Commons

// Comms array: Wi-Fi, Bluetooth, and audio output in three columns.
FocusScope {
    id: root
    required property DashboardTheme theme
    required property ScriptSource source
    property bool selected: false
    property real availableHeight: 640
    property int column: 0
    property var cursor: [0, 0, 0]
    signal dismissRequested()
    implicitHeight: layout.implicitHeight

    onSelectedChanged: if (selected) Qt.callLater(focusControls)
    function focusControls() {
        forceActiveFocus();
    }

    readonly property var comms: source.data || ({ wifiRadio: false, networks: [], bluetoothPowered: false, devices: [], sinks: [] })
    readonly property var lists: [comms.networks || [], comms.devices || [], comms.sinks || []]
    readonly property var activeNetwork: (comms.networks || []).filter(function(n) { return n.active; })[0] || null
    readonly property var defaultSink: (comms.sinks || []).filter(function(s) { return s.isDefault; })[0] || null

    function move(delta) {
        var next = cursor.slice();
        next[column] = Math.max(0, Math.min(lists[column].length - 1, next[column] + delta));
        cursor = next;
    }
    function activate(col, index) {
        var item = lists[col][index];
        if (!item) return;
        if (col === 0) {
            if (item.active) return;
            if (!item.known && item.secure) {
                // Unknown secured networks need a password; hand off to nmtui.
                source.run(["omarchy", "launch", "tui", "nmtui", "connect", item.ssid], "open " + item.ssid + " in nmtui");
                return;
            }
            source.run(["nmcli", "device", "wifi", "connect", item.ssid], "join " + item.ssid);
        } else if (col === 1) {
            source.run(["omarchy", "bluetooth", "device", item.connected ? "disconnect" : "connect", item.mac],
                       (item.connected ? "disconnect " : "connect ") + item.name);
        } else if (col === 2 && !item.isDefault) {
            source.run(["omarchy", "audio", "output", "set", "default", String(item.nodeId), item.name], "route audio → " + item.description);
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_H) column = (column + 2) % 3;
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_L || event.key === Qt.Key_Tab) column = (column + 1) % 3;
        else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) move(-1);
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) move(1);
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) activate(column, cursor[column]);
        else if (event.key === Qt.Key_F5) source.refresh();
        else if (event.key === Qt.Key_Escape) root.dismissRequested();
        else return;
        event.accepted = true;
    }

    Column {
        id: layout
        width: parent.width
        spacing: 22

        PanelHeader {
            theme: root.theme
            eyebrow: "COMMS ARRAY"
            title: root.activeNetwork ? "UPLINK // " + root.activeNetwork.ssid.toUpperCase() : "UPLINK OFFLINE"
            subtitle: "Arrows move · Enter joins, pairs, or routes · F5 rescans. Unsaved secured networks open in nmtui."
            status: root.source.acting ? root.source.pendingLabel.toUpperCase() : root.source.error || "LINKS NOMINAL"
            warning: !root.activeNetwork || root.source.error.length > 0
            busy: root.source.loading || root.source.acting
        }

        Row {
            width: parent.width
            spacing: 10
            StatTile { width: (parent.width - 30) / 4; theme: root.theme; label: "SIGNAL"; value: root.activeNetwork ? root.activeNetwork.signal + "%" : "—" }
            StatTile { width: (parent.width - 30) / 4; theme: root.theme; label: "NETWORKS IN RANGE"; value: String((root.comms.networks || []).length) }
            StatTile { width: (parent.width - 30) / 4; theme: root.theme; label: "BT LINKED"; value: String((root.comms.devices || []).filter(function(d) { return d.connected; }).length); tone: root.theme.secondaryAccentColor }
            StatTile { width: (parent.width - 30) / 4; theme: root.theme; label: "OUTPUT VOLUME"; value: root.defaultSink ? (root.defaultSink.mute ? "MUTED" : root.defaultSink.volume + "%") : "—"; tone: root.defaultSink && root.defaultSink.mute ? root.theme.urgentColor : root.theme.accentColor }
        }

        Row {
            width: parent.width
            spacing: 18
            Repeater {
                model: [
                    { title: "WI-FI", toggle: root.comms.wifiRadio ? "RADIO ON" : "RADIO OFF",
                      toggleCmd: ["nmcli", "radio", "wifi", root.comms.wifiRadio ? "off" : "on"] },
                    { title: "BLUETOOTH", toggle: root.comms.bluetoothPowered ? "POWER ON" : "POWER OFF",
                      toggleCmd: ["omarchy", "bluetooth", "power", "toggle"] },
                    { title: "AUDIO OUTPUT", toggle: "", toggleCmd: [] }
                ]
                Column {
                    id: col
                    required property var modelData
                    required property int index
                    width: (parent.width - 36) / 3
                    spacing: 8
                    Item {
                        width: parent.width
                        height: 34
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: col.modelData.title + "  //  " + root.lists[col.index].length
                            color: root.column === col.index ? root.theme.accentColor : root.theme.dimmedTextColor
                            font.family: Style.font.menuFamily
                            font.pixelSize: root.theme.fontMicro
                            font.bold: true
                            font.letterSpacing: 1.8
                        }
                        HudButton {
                            visible: col.modelData.toggle.length > 0
                            anchors.right: parent.right
                            theme: root.theme
                            label: col.modelData.toggle
                            available: !root.source.acting
                            onClicked: root.source.run(col.modelData.toggleCmd, col.modelData.title.toLowerCase() + " " + col.modelData.toggle.toLowerCase())
                        }
                    }
                    Repeater {
                        model: root.lists[col.index]
                        HudRow {
                            required property var modelData
                            required property int index
                            width: col.width
                            theme: root.theme
                            selected: root.column === col.index && root.cursor[col.index] === index
                            readonly property bool live: col.index === 0 ? modelData.active : col.index === 1 ? modelData.connected : modelData.isDefault
                            tone: live ? root.theme.secondaryAccentColor : root.theme.accentColor
                            glyph: col.index === 0 ? (modelData.signal > 66 ? "󰤨" : modelData.signal > 33 ? "󰤢" : "󰤟")
                                 : col.index === 1 ? "󰂯" : "󰓃"
                            title: col.index === 0 ? modelData.ssid : col.index === 1 ? modelData.name : modelData.description
                            detail: col.index === 0 ? modelData.signal + "%" + (modelData.secure ? "  ·  SECURED" : "  ·  OPEN") + (modelData.known ? "  ·  SAVED" : "")
                                  : col.index === 1 ? modelData.mac
                                  : (modelData.mute ? "MUTED" : modelData.volume + "%")
                            trailing: live ? (col.index === 0 ? "LINKED" : col.index === 1 ? "CONNECTED" : "DEFAULT") : ""
                            onPicked: {
                                root.column = col.index;
                                var next = root.cursor.slice(); next[col.index] = index; root.cursor = next;
                                root.forceActiveFocus();
                            }
                            onActivated: root.activate(col.index, index)
                        }
                    }
                    Text {
                        visible: !root.lists[col.index].length
                        text: col.index === 1 && !root.comms.bluetoothPowered ? "RADIO POWERED DOWN" : "NOTHING DETECTED"
                        color: root.theme.faintTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: root.theme.fontSmall
                        topPadding: 8
                    }
                }
            }
        }
    }
}
