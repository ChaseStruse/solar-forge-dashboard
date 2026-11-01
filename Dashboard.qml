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
    property string hostName: "omarchy"
    property string hostLine: ""
    property real glitch: 0
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
        fullscreenDelay.restart();
        if (!hostProcess.running && !hostLine)
            hostProcess.running = true;
        if (!briefingShown) {
            briefingShown = true;
            systemSource.refresh();
            core.ignition = 0;
            Qt.callLater(function() { bootSequence.play(); });
        } else {
            core.ignite();
        }
        syslog.log("SYS", "command center online  ·  press : for commands", "ok");
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
        precision: SystemClock.Seconds
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
    // Fast cadence while open keeps the sun and sparklines alive.
    Timer {
        interval: 3000
        repeat: true
        running: root.opened
        onTriggered: readiness.refresh()
    }
    Timer {
        interval: 12000
        repeat: true
        running: root.opened
        onTriggered: syslog.log("CORE", "flux " + Math.max(0, readiness.cpuPercent) + "%  ·  lattice "
            + Math.max(0, readiness.memoryPercent) + "%  ·  heat " + Math.round(core.heat * 100) + "%", "echo")
    }

    // Hyprland fullscreen once the window is mapped.
    Timer {
        id: fullscreenDelay
        interval: 180
        onTriggered: if (!fullscreenProcess.running) fullscreenProcess.running = true
    }
    Process {
        id: fullscreenProcess
        command: ["hyprctl", "dispatch", 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set", window = "title:^Solar Forge Dashboard$" })']
    }
    Process {
        id: hostProcess
        command: ["uname", "-nr"]
        stdout: StdioCollector { id: hostOutput; waitForEnd: true }
        onExited: function(code) {
            var parts = String(hostOutput.text || "").trim().split(/\s+/);
            if (code === 0 && parts[0]) {
                root.hostName = parts[0];
                root.hostLine = parts.join("  ·  ");
            }
        }
    }

    SequentialAnimation {
        id: glitchAnim
        NumberAnimation { target: root; property: "glitch"; to: 1; duration: 40 }
        NumberAnimation { target: root; property: "glitch"; to: 0.3; duration: 60 }
        NumberAnimation { target: root; property: "glitch"; to: 0.9; duration: 40 }
        NumberAnimation { target: root; property: "glitch"; to: 0; duration: 180 }
    }
    function pulseGlitch() {
        glitchAnim.restart();
    }

    readonly property var moduleAliases: ({
        "t": 0, "tasks": 0, "todo": 0, "objectives": 0, "obj": 0,
        "g": 1, "github": 1, "gh": 1, "git": 1,
        "m": 2, "mission": 2, "timeline": 2, "log": 2,
        "f": 3, "flight": 3, "modes": 3,
        "w": 4, "radar": 4, "workspace": 4, "workspaces": 4,
        "r": 5, "reactor": 5
    })

    function runCommand(raw) {
        var text = String(raw || "").trim();
        var words = text.split(/\s+/);
        var verb = words[0].toLowerCase();
        var rest = text.substring(words[0].length).trim();
        syslog.log("CMD", text, "cmd");
        if (verb === "help" || verb === "?") {
            [
                "open <module> · t g m f w r     jump to a module",
                "close                           return to the core",
                "todo <text>                     queue an objective",
                "theme <name>  ·  themes         engage / list themes",
                "mode <focus|forge|drift|broadcast>  set flight mode",
                "status · refresh · boot          telemetry, resync, replay ignition",
                "shortcut                        toggle SUPER + ALT + D",
                "clear · exit                    wipe log, close the forge"
            ].forEach(function(line) { syslog.log("HELP", line, "echo"); });
        } else if (verb === "open" || moduleAliases[verb] !== undefined && !rest) {
            var key = verb === "open" ? rest.toLowerCase() : verb;
            if (moduleAliases[key] === undefined)
                return syslog.log("ERR", "unknown module '" + key + "'", "warn");
            openModule(moduleAliases[key]);
            commandLine.focusInput();
        } else if (verb === "close" || verb === "core") {
            activeModule = -1;
        } else if (verb === "todo" || verb === "add") {
            if (!rest)
                return syslog.log("ERR", "usage: todo <text>", "warn");
            syslog.log("OBJ", todos.add(rest) ? "queued: " + rest : "could not queue objective", todos.error ? "warn" : "ok");
        } else if (verb === "themes") {
            syslog.log("REACT", themeReactor.themes.map(function(t) { return t.name; }).join("  ·  ") || "no themes scanned", "echo");
        } else if (verb === "theme") {
            var needle = rest.toLowerCase();
            var match = themeReactor.themes.filter(function(t) { return String(t.name).toLowerCase() === needle; })[0]
                || themeReactor.themes.filter(function(t) { return String(t.name).toLowerCase().indexOf(needle) >= 0; })[0];
            if (!needle || !match)
                return syslog.log("ERR", needle ? "no theme matches '" + rest + "'" : "usage: theme <name>", "warn");
            syslog.log("REACT", themeReactor.applyTheme(match.name) ? "engaging " + match.name + "…" : "reactor busy", "info");
        } else if (verb === "mode") {
            var mode = flightModes.modeById(rest.toLowerCase());
            if (!mode)
                return syslog.log("ERR", "modes: " + flightModes.modes.map(function(m) { return m.id; }).join(" · "), "warn");
            syslog.log("FLIGHT", flightModes.apply(mode.id) ? "engaging " + mode.name + " mode…" : "flight controller busy", "info");
        } else if (verb === "status") {
            readiness.metrics.forEach(function(m) {
                syslog.log("STAT", m.label + "  " + m.value, m.warning ? "warn" : "echo");
            });
            syslog.log("STAT", "forge " + core.forgeState + "  ·  heat " + Math.round(core.heat * 100) + "%", "info");
        } else if (verb === "refresh" || verb === "sync") {
            github.refresh(); missionSource.refresh(); readiness.refresh(); reminders.refresh();
            themeReactor.refresh(); flightModes.refresh(); workspaceRadarSource.refresh();
            syslog.log("SYS", "resync requested across all satellites", "info");
        } else if (verb === "boot" || verb === "brief") {
            systemSource.refresh();
            core.ignition = 0;
            bootSequence.play();
        } else if (verb === "shortcut") {
            toggleShortcut();
            syslog.log("SYS", root.shortcutStatus, "info");
        } else if (verb === "clear" || verb === "cls") {
            syslog.clear();
        } else if (verb === "exit" || verb === "quit") {
            close();
        } else {
            syslog.log("ERR", "unknown command '" + verb + "' — type help", "warn");
        }
    }

    Connections {
        target: readiness
        function onWarningCountChanged() {
            syslog.log("ALERT", readiness.warningCount
                ? readiness.warningCount + " subsystem warning" + (readiness.warningCount > 1 ? "s" : "") + " active"
                : "all subsystems nominal", readiness.warningCount ? "warn" : "ok");
        }
    }
    Connections {
        target: core
        function onForgeStateChanged() {
            syslog.log("CORE", "forge " + core.forgeState.toLowerCase() + "  ·  heat " + Math.round(core.heat * 100) + "%",
                       core.forgeState === "STABLE" ? "ok" : "warn");
        }
    }
    Connections {
        target: github
        function onRefreshedAtChanged() {
            if (github.refreshedAt)
                syslog.log("GH", github.actionableCount + " actionable  ·  " + github.repositories.length + " repositories", github.actionableCount ? "warn" : "ok");
        }
    }
    Connections {
        target: themeReactor
        function onCurrentThemeChanged() {
            syslog.log("REACT", "stellar identity → " + themeReactor.currentTheme, "ok");
            root.pulseGlitch();
        }
    }
    Connections {
        target: flightModes
        function onActiveModeChanged() {
            if (flightModes.activeMode)
                syslog.log("FLIGHT", flightModes.activeMode + " mode engaged", "ok");
        }
    }
    Connections {
        target: todos
        function onRemainingChanged() {
            syslog.log("OBJ", todos.remaining + " objective" + (todos.remaining === 1 ? "" : "s") + " in queue", "echo");
        }
    }
    onActiveModuleChanged: {
        if (activeModule >= 0) {
            syslog.log("NAV", "SF-0" + (activeModule + 1) + " " + core.modules[activeModule].name.toLowerCase() + " online", "info");
            pulseGlitch();
        }
    }

    Process {
        id: shortcutStatusProcess
        command: ["bash", root.shortcutScript, "--status"]
        stdout: StdioCollector { id: shortcutStatusOutput; waitForEnd: true }
        onExited: function(code) {
            root.shortcutConfigured = code === 0 && String(shortcutStatusOutput.text || "").trim() === "configured";
            root.shortcutStatus = root.shortcutConfigured ? "SUPER + ALT + D ENABLED" : "OPTIONAL SHORTCUT DISABLED";
            syslog.log("KEYS", root.shortcutStatus.toLowerCase(), "echo");
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
        implicitWidth: 1600
        implicitHeight: 1000
        minimumSize: Qt.size(720, 560)
        color: dashboardTheme.backgroundColor
        onVisibleChanged: if (!visible && root.opened)
            root.close()

        FocusScope {
            id: screen
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.releaseFocus()
            Keys.onPressed: function(event) {
                if (event.text === ":" || event.text === "/") {
                    commandLine.focusInput();
                    event.accepted = true;
                }
            }

            Shortcut {
                sequence: "Ctrl+Space"
                onActivated: core.focusPicker()
            }

            Starfield {
                anchors.fill: parent
                theme: dashboardTheme
                running: root.opened
            }

            // Top bar ------------------------------------------------------
            Item {
                id: topBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                height: 64

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "☀"
                        color: core.sunColor
                        font.pixelSize: 34
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.opened
                            NumberAnimation { to: 0.55; duration: 1400; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 1400; easing.type: Easing.InOutSine }
                        }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Item {
                            width: brand.implicitWidth
                            height: brand.implicitHeight
                            Text { x: 3 * titleGlitch.amount; text: brand.text; font: brand.font; color: dashboardTheme.urgentColor; opacity: titleGlitch.amount * 0.8 }
                            Text { x: -3 * titleGlitch.amount; text: brand.text; font: brand.font; color: dashboardTheme.accentColor; opacity: titleGlitch.amount * 0.8 }
                            Text {
                                id: brand
                                text: "SOLAR FORGE"
                                color: dashboardTheme.foregroundColor
                                font.family: Style.font.menuFamily
                                font.pixelSize: 26
                                font.bold: true
                                font.letterSpacing: 6
                            }
                            // Occasional chromatic stutter on the wordmark.
                            QtObject {
                                id: titleGlitch
                                property real amount: Math.max(root.glitch, ambientGlitch)
                                property real ambientGlitch: 0
                            }
                            SequentialAnimation {
                                running: root.opened
                                loops: Animation.Infinite
                                PauseAnimation { duration: 6800 }
                                NumberAnimation { target: titleGlitch; property: "ambientGlitch"; to: 1; duration: 50 }
                                NumberAnimation { target: titleGlitch; property: "ambientGlitch"; to: 0.2; duration: 70 }
                                NumberAnimation { target: titleGlitch; property: "ambientGlitch"; to: 0.8; duration: 40 }
                                NumberAnimation { target: titleGlitch; property: "ambientGlitch"; to: 0; duration: 120 }
                            }
                        }
                        Text {
                            text: "PERSONAL COMMAND CENTER  //  " + (root.hostLine || "OMARCHY").toUpperCase()
                            color: dashboardTheme.accentColor
                            font.family: Style.font.menuFamily
                            font.pixelSize: dashboardTheme.fontMicro
                            font.letterSpacing: 2.4
                        }
                    }
                }

                // Forge state chip
                Rectangle {
                    anchors.centerIn: parent
                    width: stateRow.implicitWidth + 32
                    height: 34
                    color: Util.alpha(core.forgeState === "STABLE" ? dashboardTheme.accentColor : dashboardTheme.urgentColor, 0.1)
                    border.color: core.forgeState === "STABLE" ? dashboardTheme.accentColor : dashboardTheme.urgentColor
                    Row {
                        id: stateRow
                        anchors.centerIn: parent
                        spacing: 10
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8; height: 8
                            color: core.forgeState === "STABLE" ? dashboardTheme.accentColor : dashboardTheme.urgentColor
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: root.opened
                                NumberAnimation { to: 0.2; duration: 600 }
                                NumberAnimation { to: 1; duration: 600 }
                            }
                        }
                        DecodeText {
                            anchors.verticalCenter: parent.verticalCenter
                            source: "FORGE " + core.forgeState + "  ·  HEAT " + Math.round(core.heat * 100) + "%"
                            color: core.forgeState === "STABLE" ? dashboardTheme.accentColor : dashboardTheme.urgentColor
                            font.family: Style.font.menuFamily
                            font.pixelSize: dashboardTheme.fontSmall
                            font.bold: true
                            font.letterSpacing: 2
                        }
                    }
                }

                Column {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0
                    Text {
                        anchors.right: parent.right
                        text: Qt.formatTime(clock.date, "HH:mm") + "<font color='" + dashboardTheme.accentColor + "'>:" + Qt.formatTime(clock.date, "ss") + "</font>"
                        textFormat: Text.StyledText
                        color: dashboardTheme.foregroundColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 30
                        font.bold: true
                        font.letterSpacing: 2
                    }
                    Text {
                        anchors.right: parent.right
                        text: Qt.formatDate(clock.date, "dddd · d MMMM yyyy").toUpperCase()
                        color: dashboardTheme.dimmedTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: dashboardTheme.fontMicro
                        font.letterSpacing: 2
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -10
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.5; color: Util.alpha(dashboardTheme.accentColor, 0.7) }
                        GradientStop { position: 1; color: "transparent" }
                    }
                }
            }

            // Body ---------------------------------------------------------
            Item {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: topBar.bottom
                anchors.bottom: commandLine.top
                anchors.margins: 20
                anchors.topMargin: 28
                // Brief horizontal shudder on glitches.
                transform: Translate { x: root.glitch * (Math.random() * 10 - 5) }

                readonly property bool wide: width >= 1240
                readonly property real railWidth: wide ? Math.max(260, Math.min(340, width * 0.17)) : 0
                readonly property real gap: 28
                readonly property real stageX: wide ? railWidth + gap : 0
                readonly property real stageWidth: width - stageX - (wide ? railWidth + gap : 0)
                readonly property bool docked: root.activeModule >= 0 && width >= 780
                readonly property real dockWidth: wide ? railWidth : Math.min(300, width * 0.28)
                readonly property var activePanel: root.activeModule === 0 ? tasks
                    : root.activeModule === 1 ? projects
                    : root.activeModule === 2 ? missionLog
                    : root.activeModule === 3 ? flightModePanel
                    : root.activeModule === 4 ? workspaceRadar
                    : root.activeModule === 5 ? themeReactorPanel : null

                TelemetryRail {
                    x: body.docked ? -width - body.gap : 0
                    width: body.railWidth
                    height: body.height
                    visible: body.wide
                    opacity: body.docked ? 0 : 1
                    Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    theme: dashboardTheme
                    source: readiness
                    briefing: systemSource
                    hostLine: root.hostLine
                }

                SystemLog {
                    id: syslog
                    x: body.width - width
                    width: body.railWidth
                    height: body.height
                    visible: body.wide
                    theme: dashboardTheme
                }

                ForgeCore {
                    id: core
                    width: body.docked ? body.dockWidth : body.stageWidth
                    height: implicitHeight
                    x: body.docked ? 0 : body.stageX
                    y: body.docked ? 0 : Math.max(0, (body.height - height) / 2)
                    maxChamber: Math.max(320, Math.min(body.stageWidth, (body.height - 70) / 0.6))
                    Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                    Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                    theme: dashboardTheme
                    readinessSource: readiness
                    githubSource: github
                    selectedModule: root.activeModule
                    docked: body.docked
                    animating: root.opened && visible
                    visible: root.activeModule < 0 || body.docked
                    onModuleSelected: function(module) { root.toggleModule(module); }
                    onModuleNavigated: function(module) { root.selectModule(module); }
                    onModuleOpened: function(module) { root.openModule(module); }
                }

                // Energy conduit routed from the selected planet into the
                // open module, with a pulse travelling along it.
                Shape {
                    id: conduit
                    anchors.fill: parent
                    visible: body.docked && panelHost.width > 0
                    preferredRendererType: Shape.CurveRenderer
                    readonly property point start: Qt.point(core.x + core.selectedPoint.x, core.y + core.selectedPoint.y)
                    readonly property real midX: core.x + core.width + body.gap / 2
                    readonly property real endY: panelHost.y + 44
                    readonly property color ink: dashboardTheme.accentColor
                    property real travel: 0
                    NumberAnimation on travel {
                        from: 0; to: 1; duration: 1400
                        loops: Animation.Infinite
                        running: conduit.visible && root.opened
                    }
                    function pointAt(t) {
                        var a = Math.abs(midX - start.x), b = Math.abs(endY - start.y), c = Math.max(0, panelHost.x - midX);
                        var d = t * (a + b + c);
                        if (d <= a) return Qt.point(start.x + Math.sign(midX - start.x) * d, start.y);
                        d -= a;
                        if (d <= b) return Qt.point(midX, start.y + Math.sign(endY - start.y) * d);
                        return Qt.point(midX + d - b, endY);
                    }
                    ShapePath {
                        strokeColor: Util.alpha(conduit.ink, 0.18)
                        strokeWidth: 6
                        fillColor: "transparent"
                        joinStyle: ShapePath.MiterJoin
                        startX: conduit.start.x; startY: conduit.start.y
                        PathLine { x: conduit.midX; y: conduit.start.y }
                        PathLine { x: conduit.midX; y: conduit.endY }
                        PathLine { x: panelHost.x; y: conduit.endY }
                    }
                    ShapePath {
                        strokeColor: Util.alpha(conduit.ink, 0.8)
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
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            readonly property point at: conduit.pointAt((conduit.travel + index / 3) % 1)
                            width: 8; height: 8; radius: 4
                            x: at.x - width / 2; y: at.y - height / 2
                            color: Qt.lighter(conduit.ink, 1.5)
                            border.color: Util.alpha(conduit.ink, 0.4)
                            border.width: 3
                        }
                    }
                }

                Item {
                    id: panelHost
                    readonly property int pad: 22
                    visible: body.activePanel !== null
                    x: body.docked ? body.dockWidth + body.gap : 0
                    width: (body.wide ? body.width - body.railWidth - body.gap : body.width) - x
                    height: body.height
                    transformOrigin: Item.Top

                    // CRT power-on: collapse to a scanline, then expand.
                    Connections {
                        target: root
                        function onActiveModuleChanged() {
                            if (root.activeModule >= 0)
                                powerOn.restart();
                        }
                    }
                    SequentialAnimation {
                        id: powerOn
                        ScriptAction { script: { panelHost.scale = 1; panelContent.opacity = 0; panelHost.yScale = 0.01; } }
                        NumberAnimation { target: panelHost; property: "yScale"; to: 1; duration: 280; easing.type: Easing.OutCubic }
                        NumberAnimation { target: panelContent; property: "opacity"; to: 1; duration: 60 }
                        NumberAnimation { target: panelContent; property: "opacity"; to: 0.25; duration: 50 }
                        NumberAnimation { target: panelContent; property: "opacity"; to: 1; duration: 120 }
                    }
                    property real yScale: 1
                    transform: Scale { origin.y: 0; yScale: panelHost.yScale }

                    HudFrame {
                        anchors.fill: parent
                        theme: dashboardTheme
                        active: root.opened
                        tag: body.activePanel ? "SF-0" + (root.activeModule + 1) + "  //  " + core.modules[root.activeModule].name : ""
                    }

                    Flickable {
                        id: panelContent
                        anchors.fill: parent
                        anchors.margins: panelHost.pad
                        anchors.topMargin: panelHost.pad + 8
                        clip: true
                        contentWidth: width
                        contentHeight: body.activePanel ? body.activePanel.implicitHeight : 0
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        TodoSection {
                            id: tasks
                            width: panelContent.width
                            theme: dashboardTheme
                            store: todos
                            reminderSource: reminders
                            selected: root.activeModule === 0
                            visible: root.activeModule === 0
                            onDismissRequested: root.releaseFocus()
                        }
                        GitHubSection {
                            id: projects
                            width: panelContent.width
                            theme: dashboardTheme
                            source: github
                            selected: root.activeModule === 1
                            visible: root.activeModule === 1
                            onDismissRequested: root.releaseFocus()
                        }
                        MissionTimeline {
                            id: missionLog
                            width: panelContent.width
                            theme: dashboardTheme
                            source: missionSource
                            taskStore: todos
                            reminderSource: reminders
                            selected: root.activeModule === 2
                            visible: root.activeModule === 2
                            onDismissRequested: root.releaseFocus()
                            onReplayBriefing: {
                                systemSource.refresh();
                                core.ignition = 0;
                                bootSequence.play();
                            }
                        }
                        FlightModesSection {
                            id: flightModePanel
                            width: panelContent.width
                            theme: dashboardTheme
                            source: flightModes
                            selected: root.activeModule === 3
                            visible: root.activeModule === 3
                            onDismissRequested: root.releaseFocus()
                        }
                        WorkspaceRadar {
                            id: workspaceRadar
                            width: panelContent.width
                            theme: dashboardTheme
                            source: workspaceRadarSource
                            selected: root.activeModule === 4
                            visible: root.activeModule === 4
                            onDismissRequested: root.releaseFocus()
                        }
                        ThemeReactorSection {
                            id: themeReactorPanel
                            width: panelContent.width
                            theme: dashboardTheme
                            source: themeReactor
                            selected: root.activeModule === 5
                            visible: root.activeModule === 5
                            onDismissRequested: root.releaseFocus()
                        }
                    }
                }
            }

            CommandLine {
                id: commandLine
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 20
                theme: dashboardTheme
                prompt: "forge@" + root.hostName
                hint: "[:] COMMAND   [ESC] CORE   [T G M F W R] MODULES   " + root.shortcutStatus
                onSubmitted: function(command) { root.runCommand(command); }
                onDismissed: core.focusPicker()
            }

            // Glitch slices: brief tinted bands across the screen.
            Repeater {
                model: 5
                Rectangle {
                    required property int index
                    visible: root.glitch > 0.05
                    width: parent.width
                    height: 6 + (index * 37) % 28
                    y: ((index * 211 + Math.floor(root.glitch * 97) * 53) % 997) / 997 * parent.height
                    color: index % 2 ? dashboardTheme.accentColor : dashboardTheme.urgentColor
                    opacity: root.glitch * 0.12
                    z: 20
                }
            }

            AmbientLayer {
                anchors.fill: parent
                theme: dashboardTheme
                visible: root.opened
                z: 10
            }
            BootSequence {
                id: bootSequence
                anchors.fill: parent
                theme: dashboardTheme
                source: systemSource
                missionSource: missionSource
                readiness: readiness
                objectiveCount: todos.remaining
                hostLine: root.hostLine
                onFinished: {
                    core.ignite();
                    root.pulseGlitch();
                    Qt.callLater(function() { core.focusPicker(); });
                }
            }
        }
    }
}
