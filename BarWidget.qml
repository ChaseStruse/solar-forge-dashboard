import QtQuick
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
