import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons

// Window and composition only. Sections own presentation; sources own data.
Item {
    id: root
    property bool opened: false
    readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "operator"
    readonly property string displayName: userName.charAt(0).toUpperCase() + userName.slice(1)

    function open() {
        todos.load();
        opened = true;
        github.refresh();
        Qt.callLater(function () {
            if (root.opened)
                tasks.focusInput();
        });
    }

    // The bar derives its open state from this property. Closing never calls
    // back into shell.hide(), so all close paths are idempotent.
    function close() {
        opened = false;
    }

    function greetingPeriod() {
        var hour = clock.date.getHours();
        return hour < 12 ? "morning" : hour < 18 ? "afternoon" : "evening";
    }

    DashboardTheme {
        id: dashboardTheme
    }
    TodoStore {
        id: todos
    }
    GitHubSource {
        id: github
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    FloatingWindow {
        id: window
        visible: root.opened
        title: "Solar Forge Dashboard"
        implicitWidth: 980
        implicitHeight: 820
        minimumSize: Qt.size(620, 520)
        color: dashboardTheme.backgroundColor
        onVisibleChanged: if (!visible && root.opened)
            root.close()

        FocusScope {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.close()

            ScrollView {
                id: page
                anchors.fill: parent
                anchors.margins: 24
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Column {
                    width: Math.min(page.availableWidth, 960)
                    spacing: 16
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "SOLAR FORGE // PERSONAL COMMAND CENTER"
                        color: dashboardTheme.accentColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 14
                        font.letterSpacing: 2.4
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "Good " + root.greetingPeriod() + ", " + root.displayName + "."
                        color: dashboardTheme.foregroundColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: Math.min(52, parent.width / 16)
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: Qt.formatDateTime(clock.date, "dddd, MMMM d, yyyy  //  HH:mm")
                        color: dashboardTheme.dimmedTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 18
                    }
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: dashboardTheme.accentColor
                        opacity: 0.3
                    }
                    Text {
                        width: parent.width
                        wrapMode: Text.Wrap
                        text: "SYSTEM ONLINE  ·  AWAITING YOUR NEXT OBJECTIVE"
                        color: dashboardTheme.urgentColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 14
                        font.letterSpacing: 1.5
                    }
                    TodoSection {
                        id: tasks
                        width: parent.width
                        theme: dashboardTheme
                        store: todos
                        onDismissRequested: root.close()
                    }
                    GitHubSection {
                        width: parent.width
                        theme: dashboardTheme
                        source: github
                    }
                    Text {
                        text: "[ ESC ] close"
                        color: dashboardTheme.faintTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 13
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }
    }
}
