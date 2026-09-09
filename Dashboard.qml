import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.LocalStorage
import qs.Commons
import qs.Ui

Item {
  id: root
  property var shell: null
  property var manifest: null
  property bool opened: false
  property var repositories: []
  property string githubStatus: "Checking local GitHub access…"
  readonly property int remainingTodos: todoModel.count - completedTodoCount()
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "operator"
  readonly property string displayName: userName.charAt(0).toUpperCase() + userName.slice(1)

  function open(payloadJson) {
    root.opened = true
    root.refreshGitHub()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  // Omarchy calls close() after shell.hide(). Calling shell.hide() again here
  // re-enters close() indefinitely, so this lifecycle handler only updates UI.
  function close() { root.opened = false }
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

        Text { text: "TODAY'S OBJECTIVES // " + root.remainingTodos + " ACTIVE"; color: "#f6b65b"; font.family: Style.font.menuFamily; font.pixelSize: 14; font.letterSpacing: 1.4 }

        Rectangle {
          width: parent.width
          height: 42
          color: "#0b1b19"
          border.color: newTodoInput.activeFocus ? "#f6b65b" : "#21423d"
          border.width: 1

          TextInput {
            id: newTodoInput
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            color: "#e3fff8"
            font.family: Style.font.menuFamily
            font.pixelSize: 14
            clip: true
            onAccepted: root.addTodo()

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: !newTodoInput.text
              text: "+ add an objective, then press Enter"
              color: "#58736d"
              font: newTodoInput.font
            }
          }
        }

        Repeater {
          model: todoModel
          delegate: Rectangle {
            required property int taskId
            required property string title
            required property bool done
            width: parent.width
            height: 38
            color: done ? "#081412" : "#0b1b19"
            border.color: "#21423d"
            border.width: 1

            Rectangle {
              id: completionBox
              width: 16; height: 16
              anchors.left: parent.left; anchors.leftMargin: 11
              anchors.verticalCenter: parent.verticalCenter
              color: done ? "#23f7c4" : "transparent"
              border.color: "#23f7c4"
              border.width: 1
              Text { anchors.centerIn: parent; text: done ? "✓" : ""; color: "#06100f"; font.bold: true; font.pixelSize: 13 }
            }
            Text {
              anchors.left: completionBox.right; anchors.leftMargin: 10
              anchors.right: parent.right; anchors.rightMargin: 10
              anchors.verticalCenter: parent.verticalCenter
              text: title
              color: done ? "#58736d" : "#e3fff8"
              font.family: Style.font.menuFamily
              font.pixelSize: 14
              elide: Text.ElideRight
              font.strikeout: done
            }
            MouseArea { anchors.fill: parent; onClicked: root.toggleTodo(taskId, !done) }
          }
        }

        Text {
          visible: todoModel.count === 0
          text: "No objectives queued. Add the first one above."
          color: "#58736d"
          font.family: Style.font.menuFamily
          font.pixelSize: 13
        }
      }

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

  Component.onCompleted: {
    root.loadTodos()
    root.refreshGitHub()
  }
}
