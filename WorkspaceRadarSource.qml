import QtQuick
import Quickshell.Io

// Hyprland workspace topology and compositor actions. The view only renders
// normalized workspace/window records and never assembles shell commands.
QtObject {
    id: root

    property var workspaces: []
    property int focusedWorkspaceId: -1
    property string status: "WORKSPACE RADAR NOT YET SCANNED"
    property bool timedOut: false
    property int completedScans: 0
    property bool listening: false
    property var urgentAddresses: ({})
    property string lastWorkspaceRaw: ""
    property string lastClientRaw: ""
    property string lastActiveRaw: ""
    readonly property bool loading: workspaceProcess.running || clientProcess.running || activeProcess.running

    function refresh() {
        if (loading)
            return;
        timedOut = false;
        completedScans = 0;
        status = "SCANNING HYPRLAND ORBITS…";
        workspaceProcess.running = true;
        clientProcess.running = true;
        activeProcess.running = true;
        deadline.restart();
    }

    function startListening() {
        listening = true;
        if (!eventProcess.running)
            eventProcess.running = true;
    }

    function stopListening() {
        listening = false;
        eventRestart.stop();
        eventProcess.running = false;
    }

    function isUrgent(address) {
        return urgentAddresses[String(address || "").toLowerCase()] === true;
    }

    function handleEvent(line) {
        var event = String(line || "").trim();
        var changed = false;
        var next = {};
        for (var address in urgentAddresses)
            next[address] = urgentAddresses[address];
        if (event.indexOf("urgent>>") === 0) {
            var urgentAddress = event.slice(8).toLowerCase();
            if (/^0x[0-9a-f]+$/.test(urgentAddress)) {
                next[urgentAddress] = true;
                changed = true;
            }
        } else if (event.indexOf("activewindowv2>>") === 0) {
            var activeAddress = event.slice(16).toLowerCase();
            if (next[activeAddress]) {
                delete next[activeAddress];
                changed = true;
            }
        }
        if (changed) {
            urgentAddresses = next;
            if (lastWorkspaceRaw && lastClientRaw && lastActiveRaw)
                consume(lastWorkspaceRaw, lastClientRaw, lastActiveRaw);
        }
    }

    function scanFinished() {
        completedScans++;
        if (completedScans !== 3 || timedOut)
            return;
        deadline.stop();
        consume(workspaceOutput.text, clientOutput.text, activeOutput.text);
    }

    function consume(workspaceRaw, clientRaw, activeRaw) {
        try {
            var workspaceData = JSON.parse(String(workspaceRaw || "[]"));
            var clients = JSON.parse(String(clientRaw || "[]"));
            var active = JSON.parse(String(activeRaw || "{}"));
            if (!Array.isArray(workspaceData) || !Array.isArray(clients))
                throw new Error("unexpected Hyprland response");

            var result = [];
            for (var i = 0; i < workspaceData.length; i++) {
                var item = workspaceData[i];
                var id = Number(item.id);
                // Special workspaces use negative ids and live outside the
                // normal numbered orbit.
                if (!isFinite(id) || id <= 0)
                    continue;
                var moons = [];
                var hasUrgent = false;
                for (var j = 0; j < clients.length; j++) {
                    var client = clients[j];
                    if (client.workspace && Number(client.workspace.id) === id) {
                        if (client.urgent === true || isUrgent(client.address))
                            hasUrgent = true;
                        moons.push({
                            address: String(client.address || ""),
                            title: String(client.title || "Untitled window"),
                            app: String(client.class || client.initialClass || "application"),
                            urgent: client.urgent === true || isUrgent(client.address)
                        });
                    }
                }
                result.push({ id: id, name: String(item.name || id), windows: moons, urgent: hasUrgent });
            }
            result.sort(function(a, b) { return a.id - b.id; });
            lastWorkspaceRaw = String(workspaceRaw);
            lastClientRaw = String(clientRaw);
            lastActiveRaw = String(activeRaw);
            workspaces = result;
            focusedWorkspaceId = Number(active.id || -1);
            status = result.length ? result.length + " ACTIVE ORBITS  ·  " + clients.length + " SIGNALS" : "NO ACTIVE WORKSPACES DETECTED";
            return true;
        } catch (failure) {
            status = "HYPRLAND RADAR RESPONSE UNREADABLE";
            return false;
        }
    }

    function focusWorkspace(workspaceId) {
        if (!isFinite(Number(workspaceId)) || Number(workspaceId) <= 0)
            return false;
        workspaceAction.command = ["hyprctl", "dispatch", "workspace", String(workspaceId)];
        workspaceAction.running = true;
        return true;
    }

    function focusWindow(address) {
        var target = String(address || "");
        if (!/^0x[0-9a-fA-F]+$/.test(target))
            return false;
        windowAction.command = ["hyprctl", "dispatch", "focuswindow", "address:" + target];
        windowAction.running = true;
        return true;
    }

    readonly property Timer deadline: Timer {
        interval: 5000
        onTriggered: {
            root.timedOut = true;
            workspaceProcess.running = false;
            clientProcess.running = false;
            activeProcess.running = false;
            root.status = "HYPRLAND RADAR SCAN TIMED OUT";
        }
    }
    readonly property Process workspaceProcess: Process {
        command: ["hyprctl", "-j", "workspaces"]
        stdout: StdioCollector { id: workspaceOutput; waitForEnd: true }
        onExited: root.scanFinished()
    }
    readonly property Process clientProcess: Process {
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector { id: clientOutput; waitForEnd: true }
        onExited: root.scanFinished()
    }
    readonly property Process activeProcess: Process {
        command: ["hyprctl", "-j", "activeworkspace"]
        stdout: StdioCollector { id: activeOutput; waitForEnd: true }
        onExited: root.scanFinished()
    }
    readonly property Process workspaceAction: Process {
        onExited: {
            root.status = exitCode === 0 ? "WORKSPACE VECTOR LOCKED" : "WORKSPACE TRANSFER FAILED";
            if (exitCode === 0) refreshDelay.restart();
        }
    }
    readonly property Process windowAction: Process {
        onExited: {
            root.status = exitCode === 0 ? "APPLICATION SIGNAL ACQUIRED" : "APPLICATION FOCUS FAILED";
            if (exitCode === 0) refreshDelay.restart();
        }
    }
    readonly property Process eventProcess: Process {
        command: ["bash", "-lc", "exec socat -U - UNIX-CONNECT:\"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock\""]
        stdout: SplitParser { onRead: function(line) { root.handleEvent(line); } }
        onExited: if (root.listening) eventRestart.restart()
    }
    readonly property Timer eventRestart: Timer {
        interval: 1500
        onTriggered: if (root.listening && !eventProcess.running) eventProcess.running = true
    }
    readonly property Timer refreshDelay: Timer {
        interval: 180
        onTriggered: root.refresh()
    }
}
