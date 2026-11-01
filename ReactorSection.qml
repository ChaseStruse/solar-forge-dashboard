import QtQuick
import QtQuick.Layouts
import qs.Commons

// Reactor: thermals, fans, GPU, power profile, and flight modes.
FocusScope {
    id: root
    required property DashboardTheme theme
    required property ScriptSource source
    required property FlightModesSource flightModes
    property bool selected: false
    property real availableHeight: 640
    signal dismissRequested()
    implicitHeight: layout.implicitHeight

    onSelectedChanged: if (selected) Qt.callLater(focusControls)
    function focusControls() {
        flightPanel.focusControls();
    }

    readonly property var reactor: source.data || ({ readings: [], gpu: null, profile: "unknown", profiles: [] })
    readonly property var readings: reactor.readings || []
    function reading(chip, label) {
        for (var i = 0; i < readings.length; i++)
            if (readings[i].chip === chip && readings[i].label === label) return readings[i];
        return null;
    }
    function firstOf(kind, pattern) {
        for (var i = 0; i < readings.length; i++)
            if (readings[i].kind === kind && pattern.test(readings[i].chip + " " + readings[i].label)) return readings[i];
        return null;
    }
    readonly property var cpuPackage: reading("coretemp", "Package id 0") || reading("k10temp", "Tctl") || firstOf("temp", /cpu|core|package|tctl/i)
    readonly property var cores: readings.filter(function(r) { return r.kind === "temp" && /^Core \d+$/.test(r.label); })
    readonly property var fans: readings.filter(function(r) { return r.kind === "fan"; })
    readonly property var storage: firstOf("temp", /nvme|composite/i)
    readonly property var gpu: reactor.gpu
    readonly property real hottest: {
        var max = -1;
        for (var i = 0; i < readings.length; i++)
            if (readings[i].kind === "temp") max = Math.max(max, readings[i].value);
        if (gpu && gpu.temp > max) max = gpu.temp;
        return max;
    }
    function tempTone(value) {
        return value >= 85 ? theme.urgentColor : value >= 70 ? theme.mix(theme.accentColor, theme.urgentColor, 0.55) : theme.accentColor;
    }
    function deg(r) {
        return r ? Math.round(r.value) + "°C" : "—";
    }

    Keys.onEscapePressed: root.dismissRequested()

    Column {
        id: layout
        width: parent.width
        spacing: 22

        PanelHeader {
            theme: root.theme
            eyebrow: "REACTOR"
            title: "THERMAL CORE"
            subtitle: "Live heat, airflow, and power for this machine. Profile and flight-mode changes apply immediately."
            status: root.source.error ? root.source.error : root.hottest >= 0 ? "PEAK " + Math.round(root.hottest) + "°C" : "SCANNING"
            warning: root.hottest >= 85 || root.source.error.length > 0
            busy: root.source.loading
        }

        GridLayout {
            width: parent.width
            columns: width < 760 ? 3 : 6
            columnSpacing: 10
            rowSpacing: 10
            StatTile { Layout.fillWidth: true; theme: root.theme; label: "CPU PACKAGE"; value: root.deg(root.cpuPackage); tone: root.tempTone(root.cpuPackage ? root.cpuPackage.value : 0) }
            StatTile { Layout.fillWidth: true; theme: root.theme; label: "GPU CORE"; value: root.gpu && root.gpu.temp >= 0 ? root.gpu.temp + "°C" : "—"; tone: root.tempTone(root.gpu ? root.gpu.temp : 0) }
            StatTile { Layout.fillWidth: true; theme: root.theme; label: "GPU DRAW"; value: root.gpu && root.gpu.power >= 0 ? root.gpu.power.toFixed(1) + "W" : "—" }
            StatTile { Layout.fillWidth: true; theme: root.theme; label: "STORAGE"; value: root.deg(root.storage); tone: root.tempTone(root.storage ? root.storage.value : 0) }
            Repeater {
                model: root.fans.slice(0, 2)
                StatTile {
                    required property var modelData
                    Layout.fillWidth: true
                    theme: root.theme
                    label: String(modelData.label).replace(/_/g, " ").toUpperCase()
                    value: Math.round(modelData.value) + " RPM"
                    tone: modelData.value > 0 ? root.theme.secondaryAccentColor : root.theme.dimmedTextColor
                }
            }
        }

        // Per-core heat columns.
        Column {
            width: parent.width
            spacing: 8
            visible: root.cores.length > 0
            Text {
                text: "CORE HEAT MAP  //  " + root.cores.length + " CORES"
                color: root.theme.accentColor
                font.family: Style.font.menuFamily
                font.pixelSize: root.theme.fontMicro
                font.bold: true
                font.letterSpacing: 1.8
            }
            Row {
                width: parent.width
                height: 120
                spacing: 6
                Repeater {
                    model: root.cores
                    Item {
                        required property var modelData
                        width: (parent.width - (root.cores.length - 1) * 6) / Math.max(1, root.cores.length)
                        height: parent.height
                        readonly property real ratio: Math.min(1, Math.max(0, (modelData.value - 25) / ((modelData.max || 100) - 25)))
                        Rectangle {
                            anchors.bottom: label.top
                            anchors.bottomMargin: 4
                            width: parent.width
                            height: 4
                            color: Util.alpha(root.theme.foregroundColor, 0.06)
                        }
                        Rectangle {
                            anchors.bottom: label.top
                            anchors.bottomMargin: 4
                            width: parent.width
                            height: Math.max(4, (parent.height - label.height - 4) * parent.ratio)
                            Behavior on height { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                            gradient: Gradient {
                                GradientStop { position: 0; color: root.tempTone(modelData.value) }
                                GradientStop { position: 1; color: Util.alpha(root.tempTone(modelData.value), 0.15) }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.top
                                anchors.bottomMargin: 2
                                text: Math.round(modelData.value) + "°"
                                color: root.theme.foregroundColor
                                font.family: Style.font.menuFamily
                                font.pixelSize: root.theme.fontMicro
                            }
                        }
                        Text {
                            id: label
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "C" + String(modelData.label).replace(/\D/g, "")
                            color: root.theme.faintTextColor
                            font.family: Style.font.menuFamily
                            font.pixelSize: root.theme.fontMicro
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 10
            Text {
                text: "POWER PROFILE  //  " + String(root.reactor.profile).toUpperCase()
                color: root.theme.accentColor
                font.family: Style.font.menuFamily
                font.pixelSize: root.theme.fontMicro
                font.bold: true
                font.letterSpacing: 1.8
            }
            Flow {
                width: parent.width
                spacing: 10
                Repeater {
                    model: root.reactor.profiles || []
                    HudButton {
                        required property string modelData
                        theme: root.theme
                        glyph: modelData === "performance" ? "󰓅" : modelData === "power-saver" ? "󰌪" : "󰾅"
                        label: modelData.toUpperCase()
                        active: root.reactor.profile === modelData
                        available: !root.source.acting
                        onClicked: root.source.run(["powerprofilesctl", "set", modelData], "power profile → " + modelData)
                    }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Util.alpha(root.theme.accentColor, 0.2) }

        FlightModesSection {
            id: flightPanel
            width: parent.width
            theme: root.theme
            source: root.flightModes
            onDismissRequested: root.dismissRequested()
        }
    }
}
