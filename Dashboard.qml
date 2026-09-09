import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property var shell: null
  property var manifest: null
  property bool opened: false
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "operator"
  readonly property string displayName: userName.charAt(0).toUpperCase() + userName.slice(1)

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  function close() { root.dismiss() }
  function toggle() { if (root.opened) root.dismiss(); else root.open("{}") }
  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "io.github.chasestruse.solar-forge-dashboard")
  }
  function greetingPeriod() {
    var hour = clock.date.getHours()
    if (hour < 12) return "morning"
    if (hour < 18) return "afternoon"
    return "evening"
  }

  SystemClock { id: clock; precision: SystemClock.Minutes }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#06100f"
    WlrLayershell.namespace: "solar-forge-dashboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: "#06100f" }
    Rectangle {
      width: parent.width * 0.78; height: 1
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top; anchors.topMargin: parent.height * 0.18
      color: "#23f7c4"; opacity: 0.55
    }
    Column {
      width: Math.min(parent.width * 0.78, 960)
      anchors.centerIn: parent; spacing: 16
      Text { text: "SOLAR FORGE // PERSONAL COMMAND CENTER"; color: "#23f7c4"; font.family: Style.font.menuFamily; font.pixelSize: 14; font.letterSpacing: 2.4 }
      Text { text: "Good " + greetingPeriod() + ", " + root.displayName + "."; color: "#e3fff8"; font.family: Style.font.menuFamily; font.pixelSize: Math.min(52, parent.width / 16); font.bold: true }
      Text { text: Qt.formatDateTime(clock.date, "dddd, MMMM d, yyyy  //  HH:mm"); color: "#90b8ae"; font.family: Style.font.menuFamily; font.pixelSize: 18 }
      Rectangle { width: parent.width; height: 1; color: "#23f7c4"; opacity: 0.3 }
      Text { text: "SYSTEM ONLINE  ·  AWAITING YOUR NEXT OBJECTIVE"; color: "#f6b65b"; font.family: Style.font.menuFamily; font.pixelSize: 14; font.letterSpacing: 1.5 }
      Text { text: "[ ESC ] dismiss"; color: "#58736d"; font.family: Style.font.menuFamily; font.pixelSize: 13; anchors.horizontalCenter: parent.horizontalCenter; topPadding: 28 }
    }
    Item {
      id: keyCatcher; anchors.fill: parent; focus: true
      Keys.onPressed: function(event) { if (event.key === Qt.Key_Escape) { root.dismiss(); event.accepted = true } }
    }
  }
}
