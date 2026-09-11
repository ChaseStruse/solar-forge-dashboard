import QtQuick
import Quickshell.Io

// Native Omarchy operating modes. Views select a preset; this source owns
// status discovery and the subprocess sequence needed to apply it.
QtObject {
    id: root

    readonly property var modes: [
        {
            id: "focus",
            name: "FOCUS",
            glyph: "󰈸",
            description: "Quiet comms and keep the system ready for concentrated work.",
            detail: "DND ON  ·  IDLE ALLOWED  ·  BALANCED POWER  ·  NIGHTLIGHT UNCHANGED"
        },
        {
            id: "forge",
            name: "FORGE",
            glyph: "󰈐",
            description: "Run at full output for builds, renders, and demanding sessions.",
            detail: "DND OFF  ·  STAY AWAKE  ·  PERFORMANCE  ·  NIGHTLIGHT OFF"
        },
        {
            id: "drift",
            name: "DRIFT",
            glyph: "󰖔",
            description: "Cool the reactor for a quieter evening or battery session.",
            detail: "DND OFF  ·  IDLE ALLOWED  ·  POWER SAVER  ·  NIGHTLIGHT ON"
        },
        {
            id: "broadcast",
            name: "BROADCAST",
            glyph: "󰑋",
            description: "Hold interruptions and sleep while sharing or recording.",
            detail: "DND ON  ·  STAY AWAKE  ·  BALANCED POWER  ·  NIGHTLIGHT OFF"
        }
    ]

    property string activeMode: ""
    property string pendingMode: ""
    property string status: "FLIGHT SYSTEMS NOT YET SCANNED"
    property bool stayAwake: false
    property bool doNotDisturb: false
    property bool nightlight: false
    property string powerProfile: "unknown"
    property bool timedOut: false
    readonly property bool loading: statusProcess.running || applyProcess.running

    function modeById(modeId) {
        for (var i = 0; i < modes.length; i++)
            if (modes[i].id === modeId)
                return modes[i];
        return null;
    }

    function refresh() {
        if (loading)
            return;
        timedOut = false;
        status = "SCANNING OMARCHY FLIGHT SYSTEMS…";
        statusProcess.running = true;
        deadline.restart();
    }

    function apply(modeId) {
        var mode = modeById(modeId);
        if (!mode || loading)
            return false;
        timedOut = false;
        pendingMode = modeId;
        status = "ENGAGING " + mode.name + " MODE…";
        applyProcess.command = ["bash", "-lc", applyScripts[modeId]];
        applyProcess.running = true;
        deadline.restart();
        return true;
    }

    function consumeStatus(raw) {
        try {
            var state = JSON.parse(String(raw || ""));
            stayAwake = state.stayAwake === true;
            doNotDisturb = state.doNotDisturb === true;
            nightlight = state.nightlight === true;
            powerProfile = String(state.powerProfile || "unknown");
            status = "FLIGHT SYSTEMS NOMINAL";
            return true;
        } catch (failure) {
            status = "FLIGHT SYSTEM STATUS UNREADABLE";
            return false;
        }
    }

    readonly property string statusScript: [
        "set -euo pipefail",
        "idle=$(omarchy toggle idle status | jq -r '.enabled')",
        "night=$(omarchy toggle nightlight --status | jq -r '.enabled')",
        "dnd=$(omarchy-shell -q notifications dndState)",
        "profile=$(omarchy powerprofiles list --active-state | awk -F '\\t' '$2 == 1 { print $1; exit }')",
        "jq -cn --argjson awake \"$idle\" --argjson night \"$night\" --arg dnd \"$dnd\" --arg profile \"$profile\" "
            + "'{stayAwake:$awake, nightlight:$night, doNotDisturb:($dnd == \"on\"), powerProfile:($profile | select(length > 0) // \"unknown\")}'"
    ].join("\n")

    readonly property var applyScripts: ({
        focus: [
            "set -euo pipefail",
            "omarchy toggle idle allow-idle >/dev/null",
            "omarchy-shell -q notifications setDnd on >/dev/null",
            "omarchy powerprofiles set autodetect balanced >/dev/null"
        ].join("\n"),
        forge: [
            "set -euo pipefail",
            "omarchy toggle idle stay-awake >/dev/null",
            "omarchy-shell -q notifications setDnd off >/dev/null",
            "omarchy powerprofiles set autodetect performance >/dev/null",
            "omarchy toggle nightlight --status | jq -e '.enabled == false' >/dev/null || omarchy toggle nightlight >/dev/null"
        ].join("\n"),
        drift: [
            "set -euo pipefail",
            "omarchy toggle idle allow-idle >/dev/null",
            "omarchy-shell -q notifications setDnd off >/dev/null",
            "omarchy powerprofiles set autodetect power-saver >/dev/null",
            "omarchy toggle nightlight --status | jq -e '.enabled == true' >/dev/null || omarchy toggle nightlight >/dev/null"
        ].join("\n"),
        broadcast: [
            "set -euo pipefail",
            "omarchy toggle idle stay-awake >/dev/null",
            "omarchy-shell -q notifications setDnd on >/dev/null",
            "omarchy powerprofiles set autodetect balanced >/dev/null",
            "omarchy toggle nightlight --status | jq -e '.enabled == false' >/dev/null || omarchy toggle nightlight >/dev/null"
        ].join("\n")
    })

    readonly property Timer deadline: Timer {
        interval: 12000
        onTriggered: {
            root.timedOut = true;
            statusProcess.running = false;
            applyProcess.running = false;
            root.pendingMode = "";
            root.status = "FLIGHT MODE REQUEST TIMED OUT";
        }
    }

    readonly property Process statusProcess: Process {
        command: ["bash", "-lc", root.statusScript]
        stdout: StdioCollector { id: statusOutput; waitForEnd: true }
        onExited: function(exitCode) {
            deadline.stop();
            if (root.timedOut)
                return;
            if (exitCode === 0)
                root.consumeStatus(statusOutput.text);
            else
                root.status = "OMARCHY FLIGHT SYSTEMS UNAVAILABLE";
        }
    }

    readonly property Process applyProcess: Process {
        onExited: function(exitCode) {
            deadline.stop();
            if (root.timedOut)
                return;
            if (exitCode !== 0) {
                root.status = "MODE CHANGE FAILED — SYSTEM STATE MAY BE PARTIAL";
                root.pendingMode = "";
                return;
            }
            root.activeMode = root.pendingMode;
            root.pendingMode = "";
            root.status = root.activeMode.toUpperCase() + " MODE ENGAGED";
            statusProcess.running = true;
            deadline.restart();
        }
    }
}
