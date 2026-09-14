import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property int cpuPercent: -1
    property int memoryPercent: -1
    property int gpuPercent: -1
    property int gpuTemperature: -1
    property string gpuName: "GPU"
    property int diskPercent: -1
    property bool batteryPresent: false
    property int batteryPercent: -1
    property string batteryStatus: "Unknown"
    property bool acOnline: true
    property real powerWatts: -1
    property string powerProfile: "unknown"
    property bool updatesAvailable: false
    property bool networkOnline: false
    property string networkName: "Offline"
    property bool bluetoothPowered: false
    property bool bluetoothConnected: false
    property string status: "READINESS TELEMETRY IDLE"
    property bool timedOut: false
    readonly property bool loading: telemetryProcess.running
    readonly property var metrics: [
        { id: "cpu", label: "CPU", value: cpuPercent < 0 ? "—" : cpuPercent + "%", warning: cpuPercent >= 90 },
        { id: "memory", label: "MEM", value: memoryPercent < 0 ? "—" : memoryPercent + "%", warning: memoryPercent >= 90 },
        { id: "gpu", label: "GPU", value: gpuPercent < 0 ? "—" : gpuPercent + "%", warning: gpuPercent >= 95 || gpuTemperature >= 85 },
        { id: "disk", label: "DISK", value: diskPercent < 0 ? "—" : diskPercent + "%", warning: diskPercent >= 90 },
        { id: "battery", label: acOnline ? "AC" : "BAT", value: batteryPresent ? batteryPercent + "%" : "AC", warning: batteryPresent && !acOnline && batteryPercent >= 0 && batteryPercent <= 20 },
        { id: "updates", label: "UPD", value: updatesAvailable ? "READY" : "CLEAR", warning: updatesAvailable },
        { id: "network", label: "NET", value: networkOnline ? "ON" : "OFF", warning: !networkOnline },
        { id: "bluetooth", label: "BT", value: bluetoothConnected ? "LINK" : bluetoothPowered ? "ON" : "OFF", warning: false }
    ]
    readonly property int warningCount: metrics.filter(function(metric) { return metric.warning }).length
    readonly property string powerSummary: (acOnline ? "AC" : "BATTERY")
        + (powerWatts >= 0 ? " · " + powerWatts.toFixed(1) + "W" : "")
        + " · " + powerProfile.toUpperCase()

    function consume(raw) {
        try {
            var state = JSON.parse(String(raw || ""))
            cpuPercent = Number(state.cpuPercent)
            memoryPercent = Number(state.memoryPercent)
            gpuPercent = Number(state.gpuPercent)
            gpuTemperature = Number(state.gpuTemperature)
            gpuName = String(state.gpuName || "GPU")
            diskPercent = Number(state.diskPercent)
            batteryPresent = state.batteryPresent === true
            batteryPercent = Number(state.batteryPercent)
            batteryStatus = String(state.batteryStatus || "Unknown")
            acOnline = state.acOnline !== false
            powerWatts = Number(state.powerWatts)
            powerProfile = String(state.powerProfile || "unknown")
            updatesAvailable = state.updatesAvailable === true
            networkOnline = state.networkOnline === true
            networkName = String(state.networkName || (networkOnline ? "Connected" : "Offline"))
            bluetoothPowered = state.bluetoothPowered === true
            bluetoothConnected = state.bluetoothConnected === true
            status = warningCount ? warningCount + " READINESS WARNING" + (warningCount === 1 ? "" : "S") : "SYSTEM READY"
            return true
        } catch (failure) {
            status = "READINESS TELEMETRY UNREADABLE"
            return false
        }
    }

    function refresh() {
        if (loading)
            return false
        timedOut = false
        telemetryProcess.running = true
        deadline.restart()
        return true
    }

    readonly property Timer deadline: Timer {
        interval: 12000
        onTriggered: {
            root.timedOut = true
            telemetryProcess.running = false
            root.status = "READINESS SCAN TIMED OUT"
        }
    }

    readonly property Process telemetryProcess: Process {
        command: ["bash", Qt.resolvedUrl("scripts/system-readiness-state.sh").toString().replace(/^file:\/\//, "")]
        stdout: StdioCollector { id: telemetryOutput; waitForEnd: true }
        onExited: function(code) {
            deadline.stop()
            if (root.timedOut)
                return
            if (code === 0)
                root.consume(telemetryOutput.text)
            else
                root.status = "READINESS TELEMETRY UNAVAILABLE"
        }
    }
}
