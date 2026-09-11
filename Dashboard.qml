import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons

// Window and composition only. Sections own presentation; sources own data.
Item {
    id: root
    property bool opened: false
    property int activeModule: -1
    property bool briefingShown: false

    function open() {
        todos.load();
        opened = true;
        activeModule = -1;
        github.refresh();
        missionSource.refresh();
        if (!briefingShown) {
            briefingShown = true;
            systemSource.refresh();
            Qt.callLater(function() { systemBriefing.play(); });
        }
        Qt.callLater(function () {
            if (root.opened)
                core.focusPicker();
        });
    }

    function selectModule(module) {
        if (module >= 0 && module <= 2)
            activeModule = module;
    }

    function toggleModule(module) {
        if (module >= 0 && module <= 2)
            activeModule = activeModule === module ? -1 : module;
    }

    function openModule(module) {
        if (module < 0 || module > 2)
            return;
        selectModule(module);
        if (module === 0)
            tasks.focusInput();
        else if (module === 1)
            projects.forceActiveFocus();
    }

    // The bar derives its open state from this property. Closing never calls
    // back into shell.hide(), so all close paths are idempotent.
    function close() {
        opened = false;
    }

    function releaseFocus() {
        activeModule = -1;
        core.focusPicker();
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
    MissionControlSource {
        id: missionSource
    }
    SystemBriefingSource {
        id: systemSource
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
            Keys.onEscapePressed: root.releaseFocus()

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
                    width: Math.min(page.availableWidth, 1560)
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
                    Item {
                        id: commandDeck
                        width: parent.width
                        readonly property bool compact: width < 780
                        readonly property real branchWidth: compact
                            ? width
                            : Math.min(280, width * 0.29)
                        height: root.activeModule === 2
                            ? missionLog.implicitHeight
                            : compact
                            ? core.height + (root.activeModule === -1 ? 0
                                : (root.activeModule === 0 ? tasks.implicitHeight
                                    : root.activeModule === 1 ? projects.implicitHeight : missionLog.implicitHeight) + 32)
                            : Math.max(core.height, tasks.implicitHeight, projects.implicitHeight)

                        ForgeCore {
                            id: core
                            width: commandDeck.compact
                                ? Math.min(620, commandDeck.width)
                                : Math.min(860, commandDeck.width * 0.82)
                            height: implicitHeight
                            x: (commandDeck.width - width) / 2
                            y: 0
                            theme: dashboardTheme
                            selectedModule: root.activeModule
                            animating: root.opened && visible
                            visible: root.activeModule !== 2
                            onModuleSelected: function(module) { root.toggleModule(module); }
                            onModuleNavigated: function(module) { root.selectModule(module); }
                            onModuleOpened: function(module) { root.openModule(module); }
                        }
                        TodoSection {
                            id: tasks
                            z: 2
                            width: commandDeck.branchWidth
                            y: commandDeck.compact
                                ? core.height + 28
                                : (commandDeck.height - height) / 2
                            theme: dashboardTheme
                            store: todos
                            selected: root.activeModule === 0
                            visible: root.activeModule === 0
                            onDismissRequested: root.releaseFocus()
                        }
                        GitHubSection {
                            id: projects
                            z: 2
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
                        MissionTimeline {
                            id: missionLog
                            width: commandDeck.width
                            x: 0
                            y: 0
                            theme: dashboardTheme
                            source: missionSource
                            selected: root.activeModule === 2
                            visible: root.activeModule === 2
                            onDismissRequested: root.releaseFocus()
                            onReplayBriefing: {
                                systemSource.refresh();
                                systemBriefing.play();
                            }
                        }
                    }
                    Text {
                        text: "[ ESC ] return focus to core"
                        color: dashboardTheme.faintTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 13
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
            SystemBriefing {
                id: systemBriefing
                anchors.fill: parent
                theme: dashboardTheme
                source: systemSource
                missionSource: missionSource
                objectiveCount: todos.remaining
            }
        }
    }
}
