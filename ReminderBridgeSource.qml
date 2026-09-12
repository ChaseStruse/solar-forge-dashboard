import QtQuick
import Quickshell.Io

// Bridges Solar Forge objective ids to Omarchy's systemd-backed reminders.
QtObject {
    id: root
    property var reminders: []
    property string status: "REMINDER LINK IDLE"
    property int pendingTaskId: -1
    property int pendingMinutes: 0
    property double pendingDue: 0
    readonly property bool loading: showProcess.running || scheduleProcess.running || cancelProcess.running
    signal reminderScheduled(int taskId, string unit, double due)
    signal reminderInventoryChanged(var reminders)

    function marker(taskId, title) {
        return "☀ Objective #" + Number(taskId) + " · " + String(title || "Objective");
    }

    function linkedTaskId(message) {
        var match = String(message || "").match(/Objective #(\d+) ·/);
        return match ? Number(match[1]) : -1;
    }

    function displayLabel(message, fallback) {
        return String(message || fallback || "Reminder").replace(/^☀ Objective #\d+ ·\s*/, "");
    }

    function refresh() {
        if (!showProcess.running)
            showProcess.running = true;
    }

    function consume(raw) {
        try {
            var payload = JSON.parse(String(raw || "{}"));
            if (!payload.reminders || !Array.isArray(payload.reminders))
                throw new Error("unexpected reminder response");
            var normalized = [];
            for (var i = 0; i < payload.reminders.length; i++) {
                var item = payload.reminders[i];
                normalized.push({
                    unit: String(item.unit || ""),
                    taskId: linkedTaskId(item.message),
                    label: displayLabel(item.message, item.label),
                    message: String(item.message || ""),
                    at: Number(item.at || 0) * 1000,
                    atTime: String(item.atTime || "—"),
                    remainingSeconds: Number(item.remainingSeconds || 0)
                });
            }
            reminders = normalized;
            status = normalized.length ? normalized.length + " INBOUND TRANSMISSION" + (normalized.length === 1 ? "" : "S") : "NO INBOUND TRANSMISSIONS";
            reminderInventoryChanged(normalized);
            return true;
        } catch (failure) {
            status = "REMINDER TELEMETRY UNREADABLE";
            return false;
        }
    }

    function schedule(taskId, title, minutes) {
        var id = Number(taskId), duration = Number(minutes);
        if (!isFinite(id) || id <= 0 || !isFinite(duration) || duration <= 0 || loading)
            return false;
        pendingTaskId = Math.floor(id);
        pendingMinutes = Math.floor(duration);
        pendingDue = Date.now() + pendingMinutes * 60000;
        status = "UPLINKING " + pendingMinutes + " MINUTE REMINDER…";
        scheduleProcess.command = ["omarchy", "reminder", String(pendingMinutes), marker(pendingTaskId, title)];
        scheduleProcess.running = true;
        return true;
    }

    function cancel(unit) {
        var name = String(unit || "");
        if (!/^omarchy-reminder-[0-9]+m-[0-9]+$/.test(name) || cancelProcess.running)
            return false;
        cancelProcess.command = ["systemctl", "--user", "stop", name + ".timer", name + ".service"];
        cancelProcess.running = true;
        return true;
    }

    property Process showProcess: Process {
        command: ["omarchy", "reminder", "show", "--json"]
        stdout: StdioCollector { id: showOutput; waitForEnd: true }
        onExited: {
            if (exitCode === 0) root.consume(showOutput.text);
            else root.status = "OMARCHY REMINDER LINK UNAVAILABLE";
        }
    }
    property Process scheduleProcess: Process {
        onExited: {
            if (exitCode !== 0) {
                root.status = "REMINDER UPLINK FAILED";
                return;
            }
            root.status = "REMINDER UPLINK CONFIRMED";
            refreshDelay.restart();
        }
    }
    property Process cancelProcess: Process {
        onExited: {
            root.status = exitCode === 0 ? "REMINDER LINK CLOSED" : "REMINDER CANCELLATION FAILED";
            refreshDelay.restart();
        }
    }
    property Timer refreshDelay: Timer {
        interval: 250
        onTriggered: root.refresh()
    }
    onReminderInventoryChanged: function(items) {
        if (pendingTaskId < 0)
            return;
        for (var i = 0; i < items.length; i++) {
            if (items[i].taskId === pendingTaskId) {
                reminderScheduled(pendingTaskId, items[i].unit, items[i].at || pendingDue);
                pendingTaskId = -1;
                pendingMinutes = 0;
                pendingDue = 0;
                return;
            }
        }
    }
}
