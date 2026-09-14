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

    Component.onCompleted: keybindingInstaller.running = true

    Process {
        id: keybindingInstaller
        command: ["bash", Qt.resolvedUrl("scripts/install-keybinding.sh").toString().replace(/^file:\/\//, "")]
        stdout: StdioCollector { id: keybindingOutput; waitForEnd: true }
        onExited: function(code) {
            var result = String(keybindingOutput.text || "").trim()
            if (code !== 0)
                console.warn("Solar Forge: keybinding setup failed" + (result ? ": " + result : ""))
            else if (result)
                console.info("Solar Forge: " + result)
        }
    }

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

    Dashboard {
        id: dashboard
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
