import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons

// Window and composition only. Sections own presentation; sources own data.
Item {
    id: root
    property bool opened: false
    property int activeModule: -1
    readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "operator"
    readonly property string displayName: userName.charAt(0).toUpperCase() + userName.slice(1)

    function open() {
        todos.load();
        opened = true;
        activeModule = -1;
        github.refresh();
        Qt.callLater(function () {
            if (root.opened)
                core.focusPicker();
        });
    }

    function selectModule(module) {
        activeModule = module;
    }

    function openModule(module) {
        if (module < 0)
            return;
        selectModule(module);
        if (module === 0)
            tasks.focusInput();
        else
            projects.forceActiveFocus();
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

            Shortcut {
                sequence: "Ctrl+Space"
                onActivated: core.focusPicker()
            }

            ScrollView {
                id: page
                anchors.fill: parent
                anchors.margins: 24
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                Column {
                    width: Math.min(page.availableWidth, 1280)
                    x: Math.max(0, (page.availableWidth - width) / 2)
                    y: Math.max(0, (page.availableHeight - implicitHeight) / 2)
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
                    Item {
                        id: commandDeck
                        width: parent.width
                        readonly property bool compact: width < 780
                        readonly property real branchWidth: compact
                            ? (width - 12) / 2
                            : Math.min(300, Math.max(180, (width - core.width) / 2 - 28))
                        height: compact
                            ? core.height + Math.max(tasks.implicitHeight, projects.implicitHeight) + 32
                            : Math.max(core.height, tasks.implicitHeight, projects.implicitHeight)

                        Rectangle {
                            visible: !commandDeck.compact && root.activeModule === 0
                            width: Math.max(0, core.x - (tasks.x + tasks.width) + 32)
                            height: 1
                            x: tasks.x + tasks.width - 16
                            y: commandDeck.height / 2
                            color: dashboardTheme.accentColor
                            opacity: root.activeModule === 0 ? 0.7 : 0.14
                        }
                        Rectangle {
                            visible: !commandDeck.compact && root.activeModule === 1
                            width: Math.max(0, projects.x - (core.x + core.width) + 16)
                            height: 1
                            x: core.x + core.width - 16
                            y: commandDeck.height / 2
                            color: dashboardTheme.accentColor
                            opacity: root.activeModule === 1 ? 0.7 : 0.14
                        }

                        ForgeCore {
                            id: core
                            width: commandDeck.compact
                                ? Math.min(520, commandDeck.width)
                                : Math.min(560, commandDeck.width * 0.52)
                            height: implicitHeight
                            x: (commandDeck.width - width) / 2
                            y: 0
                            theme: dashboardTheme
                            selectedModule: root.activeModule
                            onModuleSelected: root.selectModule(module)
                            onModuleOpened: root.openModule(module)
                        }
                        TodoSection {
                            id: tasks
                            width: commandDeck.branchWidth
                            y: commandDeck.compact
                                ? core.height + 28
                                : (commandDeck.height - height) / 2
                            theme: dashboardTheme
                            store: todos
                            selected: root.activeModule === 0
                            visible: root.activeModule === 0
                            onDismissRequested: root.close()
                        }
                        GitHubSection {
                            id: projects
                            width: commandDeck.branchWidth
                            x: commandDeck.width - width
                            y: commandDeck.compact
                                ? core.height + 28
                                : (commandDeck.height - height) / 2
                            theme: dashboardTheme
                            source: github
                            selected: root.activeModule === 1
                            visible: root.activeModule === 1
                        }
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
