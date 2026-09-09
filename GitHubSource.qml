import QtQuick
import Quickshell.Io

// Refresh on demand, with one request in flight and a bounded runtime.
QtObject {
    id: root
    property var repositories: []
    property string status: "GITHUB NOT YET LOADED"
    property bool timedOut: false
    readonly property bool loading: process.running

    function refresh() {
        if (loading)
            return;
        timedOut = false;
        status = "SYNCING PROJECT SIGNAL…";
        process.running = true;
        deadline.restart();
    }

    function consume(raw) {
        try {
            var rows = JSON.parse(String(raw || ""));
            if (!Array.isArray(rows))
                throw new Error("Expected repository array");
            repositories = rows.filter(function (row) {
                return row && typeof row.name === "string";
            }).slice(0, 4);
            status = repositories.length ? repositories.length + " REPOSITORIES" : "NO REPOSITORIES FOUND";
        } catch (failure) {
            repositories = [];
            status = "GITHUB RESPONSE UNREADABLE";
        }
    }

    readonly property Timer deadline: Timer {
        interval: 15000
        onTriggered: {
            root.timedOut = true;
            process.running = false;
            root.status = "GITHUB REQUEST TIMED OUT — REOPEN TO RETRY";
        }
    }

    readonly property Process process: Process {
        command: ["gh", "repo", "list", "--limit", "4", "--json", "name,description,url,pushedAt,isPrivate"]
        environment: ({
                GH_PROMPT_DISABLED: "1"
            })
        stdout: StdioCollector {
            id: output
            waitForEnd: true
        }
        onExited: function (exitCode) {
            deadline.stop();
            if (root.timedOut)
                return;
            if (exitCode !== 0) {
                root.repositories = [];
                root.status = "GITHUB CLI UNAVAILABLE — CHECK gh auth status";
            } else
                root.consume(output.text);
        }
    }
}
