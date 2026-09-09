import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root
  property var shell: null
  property var manifest: null
  property bool opened: false
  property var repositories: []
  property string githubStatus: "Checking local GitHub access…"
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "operator"
  readonly property string displayName: userName.charAt(0).toUpperCase() + userName.slice(1)

  function open(payloadJson) {
    root.opened = true
    root.refreshGitHub()
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

  function refreshGitHub() {
    if (!githubProcess.running) {
      githubStatus = "SYNCING PROJECT SIGNAL…"
      githubProcess.running = true
    }
  }

  SystemClock { id: clock; precision: SystemClock.Minutes }

  Process {
    id: githubProcess
    command: ["gh", "repo", "list", "--limit", "4", "--json", "name,description,url,pushedAt,isPrivate"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) return
        try {
          root.repositories = JSON.parse(raw)
          root.githubStatus = root.repositories.length > 0
            ? root.repositories.length + " RECENT REPOSITORIES"
            : "NO REPOSITORIES FOUND"
        } catch (error) {
          root.repositories = []
          root.githubStatus = "GITHUB RESPONSE UNREADABLE"
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.repositories = []
        root.githubStatus = "GITHUB CLI OFFLINE — RUN gh auth login"
      }
    }
  }

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

      Column {
        width: parent.width
        spacing: 8
        topPadding: 12

        Text { text: "GITHUB // " + root.githubStatus; color: "#23f7c4"; font.family: Style.font.menuFamily; font.pixelSize: 14; font.letterSpacing: 1.4 }

        Repeater {
          model: root.repositories
          delegate: Rectangle {
            required property var modelData
            width: parent.width
            height: 46
            color: "#0b1b19"
            border.color: "#21423d"
            border.width: 1

            Column {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 10
              spacing: 2
              Text { text: modelData.name + (modelData.isPrivate ? "  [PRIVATE]" : ""); color: "#e3fff8"; font.family: Style.font.menuFamily; font.pixelSize: 14 }
              Text { text: modelData.description || "No description"; color: "#78958e"; font.family: Style.font.menuFamily; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width }
            }
          }
        }
      }
      Text { text: "[ ESC ] dismiss"; color: "#58736d"; font.family: Style.font.menuFamily; font.pixelSize: 13; anchors.horizontalCenter: parent.horizontalCenter; topPadding: 28 }
    }
    Item {
      id: keyCatcher; anchors.fill: parent; focus: true
      Keys.onPressed: function(event) { if (event.key === Qt.Key_Escape) { root.dismiss(); event.accepted = true } }
    }
  }

  Component.onCompleted: root.refreshGitHub()
}
