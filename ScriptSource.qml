import QtQuick
import Quickshell.Io

// Runs a bundled script that prints one JSON object, and runs follow-up
// actions (argv arrays) that report back through actionFinished.
QtObject {
    id: root
    required property string script
    property var data: null
    property string error: ""
    property double refreshedAt: 0
    property int timeoutMs: 25000
    readonly property bool loading: probe.running
    readonly property bool acting: action.running
    property string pendingLabel: ""
    signal actionFinished(string label, bool ok, string output)

    readonly property string scriptPath: Qt.resolvedUrl("scripts/" + script).toString().replace(/^file:\/\//, "")

    function refresh() {
        if (probe.running)
            return false;
        probe.running = true;
        deadline.restart();
        return true;
    }
    function run(argv, label) {
        if (action.running || !argv || !argv.length)
            return false;
        pendingLabel = String(label || argv.join(" "));
        action.command = argv;
        action.running = true;
        return true;
    }

    readonly property Timer deadline: Timer {
        interval: root.timeoutMs
        onTriggered: if (probe.running) {
            probe.running = false;
            root.error = "TIMED OUT";
        }
    }
    readonly property Process probe: Process {
        command: ["bash", root.scriptPath]
        stdout: StdioCollector { id: probeOut; waitForEnd: true }
        onExited: function(code) {
            root.deadline.stop();
            try {
                root.data = JSON.parse(String(probeOut.text || ""));
                root.error = "";
                root.refreshedAt = Date.now();
            } catch (e) {
                root.error = code === 0 ? "UNREADABLE RESPONSE" : "PROBE FAILED (" + code + ")";
            }
        }
    }
    readonly property Process action: Process {
        stdout: StdioCollector { id: actionOut; waitForEnd: true }
        stderr: StdioCollector { id: actionErr; waitForEnd: true }
        onExited: function(code) {
            var output = String(actionOut.text || actionErr.text || "").trim().split("\n").pop();
            root.actionFinished(root.pendingLabel, code === 0, output);
            root.refresh();
        }
    }
}
