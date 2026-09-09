import QtQuick
import qs.Ui

// A compact launcher for the normal, tileable dashboard window.
BarWidget {
  id: root
  moduleName: "io.github.chasestruse.solar-forge-dashboard"
  readonly property bool opened: dashboardLoader.item ? dashboardLoader.item.opened === true : false

  function injectDashboard() {
    var dashboard = dashboardLoader.item
    if (!dashboard) return
    dashboard.shell = root.bar ? root.bar.shell : null
    dashboard.manifest = { id: root.moduleName }
  }

  // The bar owns this widget, so these lifecycle methods let its button and
  // shell-level toggle calls open the same ordinary desktop window.
  function open() {
    if (dashboardLoader.item) dashboardLoader.item.open("{}")
  }
  function close() {
    if (dashboardLoader.item) dashboardLoader.item.close()
  }
  function toggleDashboard() {
    if (opened) close()
    else open()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectDashboard()

  Loader {
    id: dashboardLoader
    active: true
    source: Qt.resolvedUrl("Dashboard.qml")
    visible: false
    onLoaded: {
      root.injectDashboard()
      Qt.callLater(root.injectDashboard)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "☀"
    tooltipText: "Solar Forge Dashboard"

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.toggleDashboard()
    }
  }
}
