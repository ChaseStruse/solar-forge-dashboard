import QtQuick
import Quickshell.Io
import qs.Ui as Ui

// One window per bar instance; the host routes shortcuts to the focused monitor.
Ui.BarWidget {
    id: root
    moduleName: "io.github.chasestruse.solar-forge-dashboard"
    readonly property bool opened: dashboard.opened
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    function open() {
        dashboard.open();
    }
    function close() {
        dashboard.close();
    }
    function toggleDashboard() {
        if (opened)
            close();
        else
            open();
    }

    function armLauncher() {
        dashboard.armLauncher();
    }
    function toggleLauncher() {
        dashboard.toggleLauncher();
    }

    Dashboard {
        id: dashboard
    }

    // `omarchy-shell solar-forge launcher` (SUPER + ALT + L). The target routes
    // to one instance, so it acts on every monitor's copy: an open deck flips
    // to or out of the launcher in place; otherwise all copies arm and the
    // shortcut script summons the focused one.
    IpcHandler {
        target: "solar-forge"
        function launcher(): string {
            var items = root.bar && typeof root.bar.moduleWidgets === "function"
                ? root.bar.moduleWidgets(root.moduleName) : [root];
            for (var i = 0; i < items.length; i++) {
                if (items[i] && items[i].opened === true && typeof items[i].toggleLauncher === "function") {
                    items[i].toggleLauncher();
                    return "handled";
                }
            }
            root.broadcast("armLauncher");
            return "armed";
        }
    }

    Ui.BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "☀"
        tooltipText: "Solar Forge Dashboard"
        onPressed: function (mouseButton) {
            if (mouseButton === Qt.LeftButton)
                root.toggleDashboard();
        }
    }
}
