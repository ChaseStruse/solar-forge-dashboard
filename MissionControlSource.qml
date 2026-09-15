import QtQuick
import Quickshell.Io

QtObject {
    id: root
    required property GitHubSource githubSource
    readonly property var repositories: githubSource.repositories
    readonly property string githubStatus: githubSource.status
    property string weatherStatus: "Weather not loaded"
    property string weatherCondition: "—"
    property string weatherValue: "—"
    property string weatherLocation: "LOCAL"
    property string weatherRefreshedAt: ""
    readonly property string refreshedAt: githubSource.refreshedAt || weatherRefreshedAt
    readonly property bool loading: githubSource.loading || locationProcess.running || conditionsProcess.running
    readonly property var events: githubSource.actionItems.length
        ? githubSource.actionItems.slice(0, 5).map(function(item) {
            var stamp = new Date(item.updatedAt)
            return {
                time: isNaN(stamp.getTime()) ? "—" : Qt.formatTime(stamp, "HH:mm"),
                kind: item.kind,
                title: item.repository,
                detail: item.title,
                tone: item.tone
            }
        })
        : repositories.map(function(repo) {
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
        if (!locationProcess.running) locationProcess.running = true
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
            root.weatherRefreshedAt = Qt.formatTime(new Date(), "HH:mm")
        }
    }
}
