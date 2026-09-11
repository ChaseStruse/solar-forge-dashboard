import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property var repositories: []
    property string githubStatus: "GitHub not loaded"
    property string weatherStatus: "Weather not loaded"
    property string weatherCondition: "—"
    property string weatherValue: "—"
    property string weatherLocation: "LOCAL"
    property string refreshedAt: ""
    readonly property bool loading: githubProcess.running || locationProcess.running || conditionsProcess.running
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
    readonly property var weatherEvents: weatherCondition === "—" ? [] : [{
        time: "NOW", kind: "OMARCHY WEATHER", title: weatherCondition,
        detail: weatherLocation + " · " + weatherValue, tone: "weather"
    }]

    function refresh() {
        if (!githubProcess.running) githubProcess.running = true
        if (!locationProcess.running) locationProcess.running = true
    }

    property Process githubProcess: Process {
        command: ["gh", "repo", "list", "--limit", "3", "--json", "nameWithOwner,pushedAt,isPrivate,stargazerCount,forkCount,url"]
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
    property Process locationProcess: Process {
        command: ["omarchy-weather-location"]
        stdout: StdioCollector { id: locationOutput; waitForEnd: true }
        onExited: function(code) {
            var location = String(locationOutput.text || "").trim()
            if (code !== 0 || !location) {
                root.weatherCondition = "—"
                root.weatherValue = "—"
                root.weatherStatus = "Omarchy weather location unavailable"
                return
            }
            root.weatherLocation = location
            conditionsProcess.command = ["curl", "-fsS", "--max-time", "6",
                "https://wttr.in/" + encodeURIComponent(location) + "?format=%C|%t|%w"]
            conditionsProcess.running = true
        }
    }
    property Process conditionsProcess: Process {
        stdout: StdioCollector { id: conditionsOutput; waitForEnd: true }
        onExited: function(code) {
            var raw = String(conditionsOutput.text || "").trim()
            var parts = raw.split("|")
            if (code !== 0 || parts.length < 3) {
                root.weatherCondition = "—"
                root.weatherValue = "—"
                root.weatherStatus = "Omarchy weather unavailable"
                return
            }
            root.weatherCondition = parts[0].trim()
            root.weatherValue = "Temp " + parts[1].trim().replace(/^\+/, "") + " · Wind " + parts[2].trim()
            root.weatherStatus = "Omarchy weather synced"
            root.refreshedAt = Qt.formatTime(new Date(), "HH:mm")
        }
    }
}
