import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property var themes: []
    property string currentTheme: "Unknown"
    property string wallpaperPath: ""
    property string wallpaperName: "Unknown"
    property string status: "REACTOR NOT YET SCANNED"
    property string pendingTheme: ""
    property bool timedOut: false
    readonly property bool loading: inventoryProcess.running || actionProcess.running

    function themeByName(name) {
        for (var i = 0; i < themes.length; i++)
            if (themes[i].name === name)
                return themes[i]
        return null
    }

    function consume(raw) {
        try {
            var payload = JSON.parse(String(raw || ""))
            if (!Array.isArray(payload.themes))
                throw new Error("themes missing")
            themes = payload.themes
            currentTheme = String(payload.currentTheme || "Unknown")
            wallpaperPath = String(payload.wallpaperPath || "")
            wallpaperName = String(payload.wallpaperName || "Unknown")
            status = themes.length + " STELLAR STATES ONLINE"
            return true
        } catch (failure) {
            status = "REACTOR TELEMETRY UNREADABLE"
            return false
        }
    }

    function refresh() {
        if (loading)
            return false
        status = "SCANNING STELLAR STATES…"
        timedOut = false
        inventoryProcess.running = true
        deadline.restart()
        return true
    }

    function applyTheme(name) {
        var candidate = themeByName(String(name || ""))
        if (!candidate || loading)
            return false
        pendingTheme = candidate.name
        timedOut = false
        status = "RECONFIGURING REACTOR: " + pendingTheme.toUpperCase() + "…"
        actionProcess.command = ["omarchy", "theme", "set", pendingTheme]
        actionProcess.running = true
        deadline.restart()
        return true
    }

    function nextBackground() {
        if (loading)
            return false
        pendingTheme = ""
        status = "CYCLING REACTOR BACKGROUND…"
        timedOut = false
        actionProcess.command = ["omarchy", "theme", "bg", "next"]
        actionProcess.running = true
        deadline.restart()
        return true
    }

    readonly property Timer deadline: Timer {
        interval: 30000
        onTriggered: {
            root.timedOut = true
            inventoryProcess.running = false
            actionProcess.running = false
            root.pendingTheme = ""
            root.status = "REACTOR REQUEST TIMED OUT"
        }
    }

    readonly property Timer refreshDelay: Timer {
        interval: 350
        onTriggered: root.refresh()
    }

    readonly property Process inventoryProcess: Process {
        command: ["bash", Qt.resolvedUrl("scripts/theme-reactor-state.sh").toString().replace(/^file:\/\//, "")]
        stdout: StdioCollector { id: inventoryOutput; waitForEnd: true }
        onExited: function(code) {
            deadline.stop()
            if (root.timedOut)
                return
            if (code === 0)
                root.consume(inventoryOutput.text)
            else
                root.status = "OMARCHY THEME TELEMETRY UNAVAILABLE"
        }
    }

    readonly property Process actionProcess: Process {
        onExited: function(code) {
            deadline.stop()
            if (root.timedOut)
                return
            if (code !== 0) {
                root.status = root.pendingTheme ? "THEME CHANGE FAILED" : "BACKGROUND CYCLE FAILED"
                root.pendingTheme = ""
                return
            }
            root.status = root.pendingTheme ? root.pendingTheme.toUpperCase() + " REACTOR ONLINE" : "BACKGROUND CYCLE COMPLETE"
            root.pendingTheme = ""
            refreshDelay.restart()
        }
    }
}
