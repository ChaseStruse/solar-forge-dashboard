import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property var repositories: []
    property string githubStatus: "GitHub not loaded"
    property string weatherStatus: "Weather not loaded"
    property string weatherValue: "—"
    property string weatherLocation: "LOCAL"
    property string refreshedAt: ""
    readonly property bool loading: githubProcess.running || weatherProcess.running
    readonly property var events: repositories.map(function(repo) {
        var stamp = new Date(repo.pushedAt)
        return {
            time: isNaN(stamp.getTime()) ? "—" : Qt.formatTime(stamp, "HH:mm"),
            kind: repo.isPrivate ? "PRIVATE REPOSITORY" : "REPOSITORY",
            title: repo.nameWithOwner,
            detail: "Last pushed " + (isNaN(stamp.getTime()) ? "unknown" : Qt.formatDateTime(stamp, "MMM d · HH:mm")),
            tone: "accent"
        }
    })
    readonly property var weatherEvents: weatherValue === "—" ? [] : [{
        time: "NOW", kind: "OMARCHY WEATHER", title: weatherLocation,
        detail: weatherValue, tone: "weather"
    }]

    function refresh() {
        if (!githubProcess.running) githubProcess.running = true
        if (!weatherProcess.running) weatherProcess.running = true
    }

    property Process githubProcess: Process {
        command: ["gh", "repo", "list", "--limit", "8", "--json", "nameWithOwner,pushedAt,isPrivate,stargazerCount,forkCount,url"]
        environment: ({ GH_PROMPT_DISABLED: "1" })
        stdout: StdioCollector { id: githubOutput; waitForEnd: true }
        onExited: function(code) {
            if (code !== 0) {
                root.repositories = []
                root.githubStatus = "GitHub authentication required · run gh auth login"
                return
            }
            try {
                var parsed = JSON.parse(githubOutput.text || "[]")
                root.repositories = Array.isArray(parsed) ? parsed : []
                root.githubStatus = root.repositories.length + " repositories synced"
                root.refreshedAt = Qt.formatTime(new Date(), "HH:mm")
            } catch (e) {
                root.repositories = []
                root.githubStatus = "GitHub response unreadable"
            }
        }
    }
    property Process weatherProcess: Process {
        command: ["omarchy-weather-status"]
        stdout: StdioCollector { id: weatherOutput; waitForEnd: true }
        onExited: function(code) {
            var raw = String(weatherOutput.text || "").trim()
            if (code !== 0 || !raw || raw === "Weather unavailable") {
                root.weatherValue = "—"
                root.weatherStatus = "Omarchy weather unavailable"
                return
            }
            var parts = raw.split("  ·  ")
            root.weatherLocation = parts.length ? parts[0] : "LOCAL"
            root.weatherValue = parts.slice(1).join(" · ")
            root.weatherStatus = "Omarchy weather synced"
            root.refreshedAt = Qt.formatTime(new Date(), "HH:mm")
        }
    }
}
