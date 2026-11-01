import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.Commons

// Window and composition only. Sections own presentation; sources own data.
Item {
    id: root
    property bool opened: false
    property int activeModule: -1
    property bool briefingShown: false
    property bool shortcutConfigured: false
    property string shortcutStatus: "SHORTCUT STATUS UNKNOWN"

    function open() {
        todos.load();
        opened = true;
        activeModule = -1;
        github.refresh();
        missionSource.refresh();
        flightModes.refresh();
        workspaceRadarSource.refresh();
        workspaceRadarSource.startListening();
        reminders.refresh();
        if (!shortcutStatusProcess.running)
            shortcutStatusProcess.running = true;
        themeReactor.refresh();
        readiness.refresh();
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
        if (module >= 0 && module <= 5)
            activeModule = module;
    }

    function toggleModule(module) {
        if (module >= 0 && module <= 5)
            activeModule = activeModule === module ? -1 : module;
    }

    function openModule(module) {
        if (module < 0 || module > 5)
            return;
        selectModule(module);
        if (module === 0)
            tasks.focusInput();
        else if (module === 1)
            projects.forceActiveFocus();
        else if (module === 3)
            flightModePanel.focusControls();
        else if (module === 4)
            workspaceRadar.forceActiveFocus();
        else if (module === 5)
            themeReactorPanel.focusControls();
    }

    // The bar derives its open state from this property. Closing never calls
    // back into shell.hide(), so all close paths are idempotent.
    function close() {
        opened = false;
        workspaceRadarSource.stopListening();
    }

    function releaseFocus() {
        activeModule = -1;
        core.focusPicker();
    }

    function toggleShortcut() {
        if (shortcutManager.running)
            return;
        shortcutStatus = shortcutConfigured ? "REMOVING SHORTCUT…" : "INSTALLING SHORTCUT…";
        shortcutManager.command = ["bash", shortcutScript, shortcutConfigured ? "--remove" : "--install"];
        shortcutManager.running = true;
    }

    readonly property string shortcutScript: Qt.resolvedUrl("scripts/install-keybinding.sh").toString().replace(/^file:\/\//, "")

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
        githubSource: github
    }
    FlightModesSource {
        id: flightModes
    }
    WorkspaceRadarSource {
        id: workspaceRadarSource
    }
    ReminderBridgeSource {
        id: reminders
        onReminderScheduled: function(taskId, unit, due) { todos.setReminder(taskId, unit, due); }
        onReminderInventoryChanged: function(items) { todos.reconcileReminders(items, Date.now()); }
    }
    ThemeReactorSource {
        id: themeReactor
    }
    SystemReadinessSource {
        id: readiness
    }
    SystemBriefingSource {
        id: systemSource
    }
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    Timer {
        interval: 2500
        repeat: true
        running: root.opened
        onTriggered: workspaceRadarSource.refresh()
    }
    Timer {
        interval: 10000
        repeat: true
        running: root.opened
        onTriggered: reminders.refresh()
    }
    Timer {
        interval: 15000
        repeat: true
        running: root.opened
        onTriggered: readiness.refresh()
    }
    Process {
        id: shortcutStatusProcess
        command: ["bash", root.shortcutScript, "--status"]
        stdout: StdioCollector { id: shortcutStatusOutput; waitForEnd: true }
        onExited: function(code) {
            root.shortcutConfigured = code === 0 && String(shortcutStatusOutput.text || "").trim() === "configured";
            root.shortcutStatus = root.shortcutConfigured ? "SUPER + ALT + D ENABLED" : "OPTIONAL SHORTCUT DISABLED";
        }
    }
    Process {
        id: shortcutManager
        stdout: StdioCollector { id: shortcutManagerOutput; waitForEnd: true }
        onExited: function(code) {
            var result = String(shortcutManagerOutput.text || "").trim();
            root.shortcutStatus = code === 0 ? result.toUpperCase() : "SHORTCUT CHANGE FAILED";
            shortcutRefreshDelay.restart();
        }
    }
    Timer {
        id: shortcutRefreshDelay
        interval: 250
        onTriggered: if (!shortcutStatusProcess.running) shortcutStatusProcess.running = true
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
                        // Wide windows keep the forge docked beside the open
                        // module; narrow ones swap it out entirely.
                        readonly property bool docked: !compact && root.activeModule >= 0
                        readonly property real dockWidth: Math.min(300, width * 0.28)
                        readonly property real dockGap: 36
                        readonly property var activePanel: root.activeModule === 0 ? tasks
                            : root.activeModule === 1 ? projects
                            : root.activeModule === 2 ? missionLog
                            : root.activeModule === 3 ? flightModePanel
                            : root.activeModule === 4 ? workspaceRadar
                            : root.activeModule === 5 ? themeReactorPanel : null
                        height: activePanel
                            ? Math.max(panelHost.y + panelHost.height, docked ? core.height : 0)
                            : core.height

                        ForgeCore {
                            id: core
                            width: commandDeck.docked
                                ? commandDeck.dockWidth
                                : commandDeck.compact
                                    ? Math.min(620, commandDeck.width)
                                    : Math.min(860, commandDeck.width * 0.82)
                            height: implicitHeight
                            x: commandDeck.docked ? 0 : (commandDeck.width - width) / 2
                            y: 0
                            Behavior on width { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                            Behavior on x { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                            theme: dashboardTheme
                            readinessSource: readiness
                            githubSource: github
                            selectedModule: root.activeModule
                            docked: commandDeck.docked
                            animating: root.opened && visible
                            visible: root.activeModule < 0 || commandDeck.docked
                            onModuleSelected: function(module) { root.toggleModule(module); }
                            onModuleNavigated: function(module) { root.selectModule(module); }
                            onModuleOpened: function(module) { root.openModule(module); }
                        }

                        // Energy conduit routed from the selected planet into
                        // the open module, with a pulse travelling along it.
                        Shape {
                            id: conduit
                            anchors.fill: parent
                            visible: commandDeck.docked
                            preferredRendererType: Shape.CurveRenderer
                            readonly property point start: Qt.point(core.x + core.selectedPoint.x, core.y + core.selectedPoint.y)
                            readonly property real midX: commandDeck.dockWidth + commandDeck.dockGap / 2
                            readonly property real endY: 56
                            readonly property color ink: dashboardTheme.accentColor
                            property real travel: 0
                            NumberAnimation on travel {
                                from: 0; to: 1; duration: 1600
                                loops: Animation.Infinite
                                running: conduit.visible && root.opened
                            }
                            function pointAt(t) {
                                var a = Math.abs(midX - start.x), b = Math.abs(endY - start.y), c = panelHost.x - midX;
                                var d = t * (a + b + c);
                                if (d <= a) return Qt.point(start.x + Math.sign(midX - start.x) * d, start.y);
                                d -= a;
                                if (d <= b) return Qt.point(midX, start.y + Math.sign(endY - start.y) * d);
                                return Qt.point(midX + d - b, endY);
                            }
                            ShapePath {
                                strokeColor: Util.alpha(conduit.ink, 0.18)
                                strokeWidth: 5
                                fillColor: "transparent"
                                joinStyle: ShapePath.MiterJoin
                                startX: conduit.start.x; startY: conduit.start.y
                                PathLine { x: conduit.midX; y: conduit.start.y }
                                PathLine { x: conduit.midX; y: conduit.endY }
                                PathLine { x: panelHost.x; y: conduit.endY }
                            }
                            ShapePath {
                                strokeColor: Util.alpha(conduit.ink, 0.75)
                                strokeWidth: 1
                                strokeStyle: ShapePath.DashLine
                                dashPattern: [4, 3]
                                fillColor: "transparent"
                                joinStyle: ShapePath.MiterJoin
                                startX: conduit.start.x; startY: conduit.start.y
                                PathLine { x: conduit.midX; y: conduit.start.y }
                                PathLine { x: conduit.midX; y: conduit.endY }
                                PathLine { x: panelHost.x; y: conduit.endY }
                            }
                            Rectangle {
                                readonly property point at: conduit.pointAt(conduit.travel)
                                width: 7; height: 7; radius: 3.5
                                x: at.x - width / 2; y: at.y - height / 2
                                color: Qt.lighter(conduit.ink, 1.5)
                                border.color: Util.alpha(conduit.ink, 0.4)
                                border.width: 3
                            }
                        }

                        Item {
                            id: panelHost
                            readonly property int pad: 20
                            readonly property real innerWidth: width - pad * 2
                            visible: commandDeck.activePanel !== null
                            x: commandDeck.docked ? commandDeck.dockWidth + commandDeck.dockGap : 0
                            y: 10
                            width: commandDeck.width - x
                            height: commandDeck.activePanel ? commandDeck.activePanel.implicitHeight + pad * 2 : 0
                            opacity: visible ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 240 } }

                            HudFrame {
                                anchors.fill: parent
                                theme: dashboardTheme
                                active: root.opened
                                tag: commandDeck.activePanel
                                    ? "SF-0" + (root.activeModule + 1) + "  //  " + core.modules[root.activeModule].name
                                    : ""
                            }

                            TodoSection {
                                id: tasks
                                z: 2
                                width: panelHost.innerWidth
                                x: panelHost.pad
                                y: panelHost.pad
                                theme: dashboardTheme
                                store: todos
                                reminderSource: reminders
                                selected: root.activeModule === 0
                                visible: root.activeModule === 0
                                onDismissRequested: root.releaseFocus()
                            }
                            GitHubSection {
                                id: projects
                                z: 2
                                width: panelHost.innerWidth
                                x: panelHost.pad
                                y: panelHost.pad
                                theme: dashboardTheme
                                source: github
                                selected: root.activeModule === 1
                                visible: root.activeModule === 1
                                onDismissRequested: root.releaseFocus()
                            }
                            MissionTimeline {
                                id: missionLog
                                width: panelHost.innerWidth
                                x: panelHost.pad
                                y: panelHost.pad
                                theme: dashboardTheme
                                source: missionSource
                                taskStore: todos
                                reminderSource: reminders
                                selected: root.activeModule === 2
                                visible: root.activeModule === 2
                                onDismissRequested: root.releaseFocus()
                                onReplayBriefing: {
                                    systemSource.refresh();
                                    systemBriefing.play();
                                }
                            }
                            FlightModesSection {
                                id: flightModePanel
                                width: panelHost.innerWidth
                                x: panelHost.pad
                                y: panelHost.pad
                                theme: dashboardTheme
                                source: flightModes
                                selected: root.activeModule === 3
                                visible: root.activeModule === 3
                                onDismissRequested: root.releaseFocus()
                            }
                            WorkspaceRadar {
                                id: workspaceRadar
                                width: panelHost.innerWidth
                                x: panelHost.pad
                                y: panelHost.pad
                                theme: dashboardTheme
                                source: workspaceRadarSource
                                selected: root.activeModule === 4
                                visible: root.activeModule === 4
                                onDismissRequested: root.releaseFocus()
                            }
                            ThemeReactorSection {
                                id: themeReactorPanel
                                width: panelHost.innerWidth
                                x: panelHost.pad
                                y: panelHost.pad
                                theme: dashboardTheme
                                source: themeReactor
                                selected: root.activeModule === 5
                                visible: root.activeModule === 5
                                onDismissRequested: root.releaseFocus()
                            }
                        }
                    }
                    Rectangle {
                        width: parent.width
                        height: 42
                        color: Util.alpha(dashboardTheme.accentColor, 0.05)
                        border.color: dashboardTheme.borderColor
                        border.width: 1
                        Row {
                            anchors.centerIn: parent
                            spacing: 14
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.shortcutStatus
                                color: dashboardTheme.dimmedTextColor
                                font.family: Style.font.menuFamily
                                font.pixelSize: 11
                                font.bold: true
                                font.letterSpacing: 0.7
                            }
                            Rectangle {
                                width: shortcutAction.implicitWidth + 20
                                height: 28
                                radius: 2
                                color: shortcutMouse.containsMouse ? dashboardTheme.accentColor : "transparent"
                                border.color: dashboardTheme.accentColor
                                Text {
                                    id: shortcutAction
                                    anchors.centerIn: parent
                                    text: root.shortcutConfigured ? "DISABLE SHORTCUT" : "ENABLE SUPER + ALT + D"
                                    color: shortcutMouse.containsMouse ? dashboardTheme.backgroundColor : dashboardTheme.accentColor
                                    font.family: Style.font.menuFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                                MouseArea {
                                    id: shortcutMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !shortcutManager.running
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleShortcut()
                                }
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
            AmbientLayer {
                anchors.fill: parent
                theme: dashboardTheme
                visible: root.opened
                z: 10
            }
            SystemBriefing {
                id: systemBriefing
                anchors.fill: parent
                theme: dashboardTheme
                source: systemSource
                missionSource: missionSource
                objectiveCount: todos.remaining
                onBriefingDismissed: Qt.callLater(function() { core.focusPicker(); })
            }
        }
    }
}
