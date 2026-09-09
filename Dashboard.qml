import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.LocalStorage
import qs.Commons
import qs.Ui

Item {
  id: root
  property var shell: null
  property var manifest: null
  property bool opened: false
  property bool closingFromHost: false
  property var repositories: []
  property string githubStatus: "Checking local GitHub access…"
  // Omarchy's Color singleton reloads these bindings whenever the desktop
  // theme changes, keeping the dashboard aligned with the active palette.
  readonly property color backgroundColor: Color.popups.background
  readonly property color foregroundColor: Color.popups.text
  readonly property color accentColor: Color.accent
  readonly property color urgentColor: Color.urgent
  readonly property color mutedColor: Color.muted
  readonly property color surfaceColor: Util.alpha(Color.foreground, 0.08)
  readonly property color completedSurfaceColor: Util.alpha(Color.foreground, 0.04)
  readonly property color borderColor: Util.alpha(Color.popups.border, 0.48)
  readonly property color dimmedTextColor: Util.alpha(Color.foreground, 0.62)
  readonly property color faintTextColor: Util.alpha(Color.foreground, 0.45)
  readonly property int remainingTodos: todoModel.count - completedTodoCount()
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "operator"
  readonly property string displayName: userName.charAt(0).toUpperCase() + userName.slice(1)

  function open(payloadJson) {
    root.closingFromHost = false
    root.opened = true
    root.refreshGitHub()
    Qt.callLater(function() { newTodoInput.forceActiveFocus() })
  }
  // Host-initiated close: the host has already cleared its open state, so do
  // not call shell.hide() from here or the lifecycle would re-enter itself.
  function close() {
    root.closingFromHost = true
    root.opened = false
    root.closingFromHost = false
  }
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

  function todoDatabase() {
    return LocalStorage.openDatabaseSync("solar-forge-dashboard", "1.0", "Solar Forge tasks", 1000000)
  }

  function loadTodos() {
    todoModel.clear()
    var database = todoDatabase()
    database.transaction(function(transaction) {
      transaction.executeSql("CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY, title TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)")
      var result = transaction.executeSql("SELECT id, title, done FROM todos ORDER BY done ASC, created_at ASC")
      for (var index = 0; index < result.rows.length; index++) {
        var row = result.rows.item(index)
        todoModel.append({ taskId: row.id, title: row.title, done: row.done === 1 })
      }
    })
  }

  function addTodo() {
    var title = newTodoInput.text.trim()
    if (!title) return
    var database = todoDatabase()
    database.transaction(function(transaction) {
      transaction.executeSql("INSERT INTO todos (title, done, created_at) VALUES (?, ?, ?)", [title, 0, Date.now()])
    })
    newTodoInput.text = ""
    root.loadTodos()
    newTodoInput.forceActiveFocus()
  }

  function toggleTodo(taskId, done) {
    var database = todoDatabase()
    database.transaction(function(transaction) {
      transaction.executeSql("UPDATE todos SET done = ? WHERE id = ?", [done ? 1 : 0, taskId])
    })
    root.loadTodos()
  }

  function completedTodoCount() {
    var count = 0
    for (var index = 0; index < todoModel.count; index++) {
      if (todoModel.get(index).done) count++
    }
    return count
  }

  SystemClock { id: clock; precision: SystemClock.Minutes }
  ListModel { id: todoModel }

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

  FloatingWindow {
    id: window
    visible: root.opened
    title: "Solar Forge Dashboard"
    implicitWidth: 980
    implicitHeight: 820
    minimumSize: Qt.size(620, 520)
    color: root.backgroundColor

    // A FloatingWindow is an ordinary desktop window: Hyprland tiles it by
    // default, and its title bar retains the normal close control. F11 is an
    // opt-in fullscreen view when a distraction-free dashboard is useful.
    onVisibleChanged: {
      if (!visible && !root.closingFromHost) root.dismiss()
    }

    Rectangle { anchors.fill: parent; color: root.backgroundColor }
    Rectangle {
      width: parent.width * 0.78; height: 1
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top; anchors.topMargin: parent.height * 0.18
      color: root.accentColor; opacity: 0.55
    }
    Column {
      width: Math.min(parent.width * 0.78, 960)
      anchors.centerIn: parent; spacing: 16
      Text { text: "SOLAR FORGE // PERSONAL COMMAND CENTER"; color: root.accentColor; font.family: Style.font.menuFamily; font.pixelSize: 14; font.letterSpacing: 2.4 }
      Text { text: "Good " + greetingPeriod() + ", " + root.displayName + "."; color: root.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: Math.min(52, parent.width / 16); font.bold: true }
      Text { text: Qt.formatDateTime(clock.date, "dddd, MMMM d, yyyy  //  HH:mm"); color: root.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 18 }
      Rectangle { width: parent.width; height: 1; color: root.accentColor; opacity: 0.3 }
      Text { text: "SYSTEM ONLINE  ·  AWAITING YOUR NEXT OBJECTIVE"; color: root.urgentColor; font.family: Style.font.menuFamily; font.pixelSize: 14; font.letterSpacing: 1.5 }

      Column {
        width: parent.width
        spacing: 8
        topPadding: 12

        Text { text: "TODAY'S OBJECTIVES // " + root.remainingTodos + " ACTIVE"; color: root.urgentColor; font.family: Style.font.menuFamily; font.pixelSize: 14; font.letterSpacing: 1.4 }

        Rectangle {
          width: parent.width
          height: 42
          color: root.surfaceColor
          border.color: newTodoInput.activeFocus ? root.accentColor : root.borderColor
          border.width: 1

          TextInput {
            id: newTodoInput
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: root.foregroundColor
            font.family: Style.font.menuFamily
            font.pixelSize: 14
            clip: true
            onAccepted: root.addTodo()
            Keys.onEscapePressed: root.dismiss()

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: !newTodoInput.text
              text: "+ add an objective, then press Enter"
              color: root.faintTextColor
              font: newTodoInput.font
            }
          }
        }

        // Keep the command center compact even when the task backlog grows.
        // This viewport is exactly three task rows high; the scrollbar appears
        // only once there are more rows to browse.
        Flickable {
          id: todoViewport
          width: parent.width
          height: 3 * 38 + 2 * 8
          contentWidth: width
          contentHeight: todoColumn.height
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: todoColumn
            width: todoViewport.width - (todoModel.count > 3 ? todoScrollbar.width + 6 : 0)
            spacing: 8

            Repeater {
              model: todoModel
              delegate: Rectangle {
                required property int taskId
                required property string title
                required property bool done
                width: todoColumn.width
                height: 38
                color: done ? root.completedSurfaceColor : root.surfaceColor
                border.color: root.borderColor
                border.width: 1

                Rectangle {
                  id: completionBox
                  width: 16; height: 16
                  anchors.left: parent.left; anchors.leftMargin: 11
                  anchors.verticalCenter: parent.verticalCenter
                  color: done ? root.accentColor : "transparent"
                  border.color: root.accentColor
                  border.width: 1
                  Text { anchors.centerIn: parent; text: done ? "✓" : ""; color: root.backgroundColor; font.bold: true; font.pixelSize: 13 }
                }
                Text {
                  anchors.left: completionBox.right; anchors.leftMargin: 10
                  anchors.right: parent.right; anchors.rightMargin: 10
                  anchors.verticalCenter: parent.verticalCenter
                  text: title
                  color: done ? root.faintTextColor : root.foregroundColor
                  font.family: Style.font.menuFamily
                  font.pixelSize: 14
                  elide: Text.ElideRight
                  font.strikeout: done
                }
                MouseArea { anchors.fill: parent; onClicked: root.toggleTodo(taskId, !done) }
              }
            }
          }

          ScrollBar.vertical: ScrollBar {
            id: todoScrollbar
            policy: todoModel.count > 3 ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
          }
        }

        Text {
          visible: todoModel.count === 0
          text: "No objectives queued. Add the first one above."
          color: root.faintTextColor
          font.family: Style.font.menuFamily
          font.pixelSize: 13
        }
      }

      Column {
        width: parent.width
        spacing: 8
        topPadding: 12

        Text { text: "GITHUB // " + root.githubStatus; color: root.accentColor; font.family: Style.font.menuFamily; font.pixelSize: 14; font.letterSpacing: 1.4 }

        Repeater {
          model: root.repositories
          delegate: Rectangle {
            required property var modelData
            width: parent.width
            height: 46
            color: root.surfaceColor
            border.color: root.borderColor
            border.width: 1

            Column {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: 10
              spacing: 2
              Text { text: modelData.name + (modelData.isPrivate ? "  [PRIVATE]" : ""); color: root.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 14 }
              Text { text: modelData.description || "No description"; color: root.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width }
            }
          }
        }
      }
      Text { text: "[ ESC ] close"; color: root.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 13; anchors.horizontalCenter: parent.horizontalCenter; topPadding: 28 }
    }
    Item {
      id: keyCatcher; anchors.fill: parent; focus: true
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.dismiss()
          event.accepted = true
        }
      }
    }
  }

  Component.onCompleted: {
    root.loadTodos()
    root.refreshGitHub()
  }
}
