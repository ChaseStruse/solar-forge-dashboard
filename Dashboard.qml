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
    // First Escape at the idle core arms shutdown; a second one disengages.
    property bool escArmed: false
    readonly property int moduleCount: core.modules.length

    function open() {
        todos.load();
        opened = true;
        activeModule = -1;
        escArmed = false;
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
        commsSource.refresh();
        reactorSource.refresh();
        // Mirror checks are slower; refresh the depot at most every 15 minutes.
        if (Date.now() - depotSource.refreshedAt > 15 * 60000)
            depotSource.refresh();
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
        syslog.log("SYS", "command center online  ·  press : for commands, space to launch", "ok");
        Qt.callLater(function () {
            if (root.opened)
                core.focusPicker();
        });
    }

    function selectModule(module) {
        if (module >= 0 && module < moduleCount)
            activeModule = module;
    }

    function toggleModule(module) {
        if (module >= 0 && module < moduleCount)
            activeModule = activeModule === module ? -1 : module;
    }

    function openModule(module) {
        if (module < 0 || module >= moduleCount)
            return;
        selectModule(module);
        if (module === 0)
            tasks.focusInput();
        else if (module === 1)
            projects.forceActiveFocus();
        else
            [launcher, reactorPanel, commsPanel, depotPanel, codexPanel][module - 2].focusControls();
    }

    // The bar derives its open state from this property. Closing never calls
    // back into shell.hide(), so all close paths are idempotent.
    function close() {
        opened = false;
        escArmed = false;
        workspaceRadarSource.stopListening();
    }

    function releaseFocus() {
        activeModule = -1;
        core.focusPicker();
    }

    // CRT power-off, then close.
    function shutdown() {
        if (shutdownAnim.running || !opened)
            return;
        sfx("service-logout");
        shutdownAnim.restart();
    }

    function sfx(name) {
        if (settings.sfx)
            Quickshell.execDetached(["canberra-gtk-play", "-i", name]);
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
    ScriptSource {
        id: reactorSource
        script: "reactor-state.sh"
        onActionFinished: function(label, ok, output) { syslog.log("REACTOR", label + (ok ? "  ·  done" : "  ·  failed " + output), ok ? "ok" : "warn"); }
    }
    ScriptSource {
        id: commsSource
        script: "comms-state.sh"
        onActionFinished: function(label, ok, output) {
            syslog.log("COMMS", label + (ok ? "  ·  done" : "  ·  failed " + output), ok ? "ok" : "warn");
            root.sfx(ok ? "network-connectivity-established" : "dialog-warning");
        }
    }
    ScriptSource {
        id: depotSource
        script: "depot-state.sh"
        timeoutMs: 45000
    }
    ScriptSource {
        id: codexSource
        script: "codex-state.sh"
    }
    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Persistent preferences (sound effects) under XDG state.
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/solar-forge"
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", stateDir])
    FileView {
        path: root.stateDir + "/settings.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: settings
            property bool sfx: false
        }
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
    // Module sources poll only while their panel is on screen.
    Timer {
        interval: 5000
        repeat: true
        running: root.opened && (root.activeModule === 3 || root.activeModule === 4)
        onTriggered: root.activeModule === 3 ? reactorSource.refresh() : commsSource.refresh()
    }
    Timer {
        interval: 12000
        repeat: true
        running: root.opened
        onTriggered: syslog.log("CORE", "flux " + Math.max(0, readiness.cpuPercent) + "%  ·  lattice "
            + Math.max(0, readiness.memoryPercent) + "%  ·  heat " + Math.round(core.heat * 100) + "%", "echo")
    }
    Timer {
        id: escDisarm
        interval: 1800
        onTriggered: root.escArmed = false
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
    // One-shot system commands launched from the command line.
    Process {
        id: systemAction
        property string label: ""
        stdout: StdioCollector { id: systemActionOut; waitForEnd: true }
        stderr: StdioCollector { id: systemActionErr; waitForEnd: true }
        onExited: function(code) {
            var detail = String(systemActionOut.text || systemActionErr.text || "").trim().split("\n").pop();
            syslog.log("SYS", label + (code === 0 ? "  ·  done" : "  ·  failed") + (detail ? "  ·  " + detail : ""), code === 0 ? "ok" : "warn");
        }
    }
    function system(argv, label) {
        if (systemAction.running)
            return syslog.log("SYS", "previous command still running", "warn");
        systemAction.label = label;
        systemAction.command = argv;
        systemAction.running = true;
        syslog.log("SYS", label + "…", "info");
    }
    // Commands that need the dashboard out of the way (screenshots, lock).
    Timer {
        id: afterClose
        property var argv: []
        interval: 450
        onTriggered: Quickshell.execDetached(argv)
    }
    function closeThen(argv) {
        afterClose.argv = argv;
        close();
        afterClose.restart();
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

    // Planet telemetry -------------------------------------------------------
    readonly property int depotPending: depotSource.data
        ? (depotSource.data.repo || []).length + (depotSource.data.aur || []).length + (depotSource.data.omarchyReady ? 1 : 0) : 0
    readonly property real hottestTemp: {
        var max = readiness.gpuTemperature;
        var readings = reactorSource.data ? reactorSource.data.readings || [] : [];
        for (var i = 0; i < readings.length; i++)
            if (readings[i].kind === "temp") max = Math.max(max, readings[i].value);
        return max;
    }
    readonly property var activeNetwork: commsSource.data
        ? (commsSource.data.networks || []).filter(function(n) { return n.active; })[0] || null : null
    function badge(count) {
        return count > 99 ? "99+" : count > 0 ? String(count) : "";
    }

    readonly property var moduleAliases: ({
        "t": 0, "tasks": 0, "todo": 0, "objectives": 0, "obj": 0,
        "g": 1, "github": 1, "gh": 1, "git": 1,
        "l": 2, "launch": 2, "launcher": 2, "apps": 2, "hangar": 2,
        "r": 3, "reactor": 3, "thermal": 3, "power": 3,
        "c": 4, "comms": 4, "network": 4, "wifi": 4, "audio": 4,
        "d": 5, "depot": 5, "updates": 5,
        "k": 6, "codex": 6, "keybinds": 6, "bindings": 6
    })
    readonly property var commandSpecs: [
        { name: "help", args: "", hint: "list commands" },
        { name: "open", args: "<module>", hint: "jump to a module" },
        { name: "run", args: "<app>", hint: "launch an application" },
        { name: "close", args: "", hint: "return to the core" },
        { name: "todo", args: "<text>", hint: "queue an objective" },
        { name: "focus", args: "<minutes>", hint: "focus mode + reminder" },
        { name: "keys", args: "<search>", hint: "search keybindings" },
        { name: "update", args: "", hint: "full system update" },
        { name: "lock", args: "", hint: "lock the screen" },
        { name: "screenshot", args: "[region|windows|fullscreen]", hint: "capture the screen" },
        { name: "wallpaper", args: "next", hint: "cycle the background" },
        { name: "nightlight", args: "", hint: "toggle nightlight" },
        { name: "theme", args: "<name>", hint: "engage a theme" },
        { name: "themes", args: "", hint: "list themes" },
        { name: "mode", args: "<flight mode>", hint: "engage a flight mode" },
        { name: "profile", args: "<power profile>", hint: "set power profile" },
        { name: "wifi", args: "<on|off>", hint: "wi-fi radio" },
        { name: "bt", args: "<on|off|toggle>", hint: "bluetooth power" },
        { name: "volume", args: "<+N|-N|mute-toggle>", hint: "output volume" },
        { name: "status", args: "", hint: "print telemetry" },
        { name: "refresh", args: "", hint: "resync every source" },
        { name: "boot", args: "", hint: "replay ignition" },
        { name: "sfx", args: "<on|off>", hint: "sound effects" },
        { name: "shortcut", args: "", hint: "toggle SUPER + ALT + D" },
        { name: "clear", args: "", hint: "wipe the syslog" },
        { name: "exit", args: "", hint: "close the forge" }
    ]

    // Tab-completion candidates for the command line.
    function complete(text) {
        var raw = String(text || "");
        var space = raw.indexOf(" ");
        if (space < 0) {
            var q = raw.toLowerCase();
            return commandSpecs.filter(function(c) { return c.name.indexOf(q) === 0; }).slice(0, 8).map(function(c) {
                return { value: c.name + (c.args ? " " : ""), label: c.name + (c.args ? " " + c.args : ""), hint: c.hint };
            });
        }
        var verb = raw.substring(0, space).toLowerCase();
        var arg = raw.substring(space + 1).toLowerCase();
        var options = [];
        if (verb === "open")
            options = ["objectives", "github", "launcher", "reactor", "comms", "depot", "codex"];
        else if (verb === "run" || verb === "launch")
            options = launcher.matchNames(arg, 8);
        else if (verb === "theme")
            options = themeReactor.themes.map(function(t) { return String(t.name); });
        else if (verb === "mode")
            options = flightModes.modes.map(function(m) { return m.id; });
        else if (verb === "profile")
            options = reactorSource.data ? reactorSource.data.profiles || [] : ["power-saver", "balanced", "performance"];
        else if (verb === "screenshot")
            options = ["region", "windows", "fullscreen", "smart"];
        else if (verb === "wifi" || verb === "sfx")
            options = ["on", "off"];
        else if (verb === "bt")
            options = ["on", "off", "toggle"];
        else if (verb === "volume")
            options = ["+5", "-5", "mute-toggle"];
        else if (verb === "wallpaper")
            options = ["next"];
        else if (verb === "focus")
            options = ["25", "50", "90"];
        return options.filter(function(o) {
            return verb === "run" || verb === "launch" || String(o).toLowerCase().indexOf(arg) === 0;
        }).slice(0, 8).map(function(o) {
            return { value: verb + " " + o, label: verb + " " + o, hint: "" };
        });
    }

    function runCommand(raw) {
        var text = String(raw || "").trim();
        var words = text.split(/\s+/);
        var verb = words[0].toLowerCase();
        var rest = text.substring(words[0].length).trim();
        var arg = rest.toLowerCase();
        syslog.log("CMD", text, "cmd");
        sfx("message");
        if (verb === "help" || verb === "?") {
            commandSpecs.forEach(function(c) {
                syslog.log("HELP", (c.name + (c.args ? " " + c.args : "")) + "  —  " + c.hint, "echo");
            });
            syslog.log("HELP", "tab completes · ↑↓ history · space at the core opens the launcher", "echo");
        } else if (verb === "open" || moduleAliases[verb] !== undefined && !rest) {
            var key = verb === "open" ? arg : verb;
            if (moduleAliases[key] === undefined)
                return syslog.log("ERR", "unknown module '" + key + "'", "warn");
            openModule(moduleAliases[key]);
        } else if (verb === "run" || verb === "launch") {
            if (!rest)
                return openModule(2);
            if (!launcher.launchQuery(rest))
                syslog.log("ERR", "no application matches '" + rest + "'", "warn");
        } else if (verb === "close" || verb === "core") {
            releaseFocus();
        } else if (verb === "todo" || verb === "add") {
            if (!rest)
                return syslog.log("ERR", "usage: todo <text>", "warn");
            syslog.log("OBJ", todos.add(rest) ? "queued: " + rest : "could not queue objective", todos.error ? "warn" : "ok");
        } else if (verb === "focus") {
            var minutes = Math.floor(Number(arg || 25));
            if (!isFinite(minutes) || minutes <= 0 || minutes > 600)
                return syslog.log("ERR", "usage: focus <minutes>", "warn");
            flightModes.apply("focus");
            Quickshell.execDetached(["omarchy", "reminder", String(minutes), "☀ Focus session complete — " + minutes + " minutes logged"]);
            syslog.log("FOCUS", minutes + " minute session started  ·  focus mode engaging  ·  reminder armed", "ok");
        } else if (verb === "keys") {
            openModule(6);
            codexPanel.search(rest);
        } else if (verb === "update") {
            depotPanel.launchUpdate();
        } else if (verb === "lock") {
            closeThen(["omarchy", "system", "lock"]);
        } else if (verb === "screenshot") {
            var shot = ["region", "windows", "fullscreen", "smart"].indexOf(arg) >= 0 ? arg : "region";
            closeThen(["omarchy", "capture", "screenshot", shot]);
        } else if (verb === "wallpaper" || verb === "bg") {
            system(["omarchy", "theme", "bg", "next"], "wallpaper cycle");
        } else if (verb === "nightlight") {
            system(["omarchy", "toggle", "nightlight"], "nightlight toggle");
        } else if (verb === "themes") {
            syslog.log("REACT", themeReactor.themes.map(function(t) { return t.name; }).join("  ·  ") || "no themes scanned", "echo");
        } else if (verb === "theme") {
            var match = themeReactor.themes.filter(function(t) { return String(t.name).toLowerCase() === arg; })[0]
                || themeReactor.themes.filter(function(t) { return String(t.name).toLowerCase().indexOf(arg) >= 0; })[0];
            if (!arg || !match)
                return syslog.log("ERR", arg ? "no theme matches '" + rest + "'" : "usage: theme <name>", "warn");
            syslog.log("REACT", themeReactor.applyTheme(match.name) ? "engaging " + match.name + "…" : "reactor busy", "info");
        } else if (verb === "mode") {
            var mode = flightModes.modeById(arg);
            if (!mode)
                return syslog.log("ERR", "modes: " + flightModes.modes.map(function(m) { return m.id; }).join(" · "), "warn");
            syslog.log("FLIGHT", flightModes.apply(mode.id) ? "engaging " + mode.name + " mode…" : "flight controller busy", "info");
        } else if (verb === "profile") {
            if (!/^(power-saver|balanced|performance)$/.test(arg))
                return syslog.log("ERR", "usage: profile <power-saver|balanced|performance>", "warn");
            reactorSource.run(["powerprofilesctl", "set", arg], "power profile → " + arg);
        } else if (verb === "wifi") {
            if (arg !== "on" && arg !== "off")
                return syslog.log("ERR", "usage: wifi <on|off>", "warn");
            commsSource.run(["nmcli", "radio", "wifi", arg], "wi-fi radio " + arg);
        } else if (verb === "bt" || verb === "bluetooth") {
            if (["on", "off", "toggle"].indexOf(arg) < 0)
                return syslog.log("ERR", "usage: bt <on|off|toggle>", "warn");
            commsSource.run(["omarchy", "bluetooth", "power", arg], "bluetooth " + arg);
        } else if (verb === "volume" || verb === "vol") {
            if (!/^([+-]\d{1,3}|mute-toggle|mute|raise|lower)$/.test(arg))
                return syslog.log("ERR", "usage: volume <+N|-N|mute-toggle>", "warn");
            system(["omarchy", "audio", "output", "volume", arg === "mute" ? "mute-toggle" : arg], "volume " + arg);
        } else if (verb === "status") {
            readiness.metrics.forEach(function(m) {
                syslog.log("STAT", m.label + "  " + m.value, m.warning ? "warn" : "echo");
            });
            syslog.log("STAT", "forge " + core.forgeState + "  ·  heat " + Math.round(core.heat * 100) + "%  ·  peak " + Math.round(hottestTemp) + "°C", "info");
        } else if (verb === "refresh" || verb === "sync") {
            github.refresh(); missionSource.refresh(); readiness.refresh(); reminders.refresh();
            themeReactor.refresh(); flightModes.refresh(); workspaceRadarSource.refresh();
            reactorSource.refresh(); commsSource.refresh(); depotSource.refresh(); codexSource.refresh();
            syslog.log("SYS", "resync requested across all satellites", "info");
        } else if (verb === "boot" || verb === "brief") {
            systemSource.refresh();
            core.ignition = 0;
            bootSequence.play();
        } else if (verb === "sfx") {
            if (arg !== "on" && arg !== "off")
                return syslog.log("SYS", "sound effects are " + (settings.sfx ? "on" : "off") + "  ·  usage: sfx <on|off>", "echo");
            settings.sfx = arg === "on";
            sfx("bell");
            syslog.log("SYS", "sound effects " + arg, "ok");
        } else if (verb === "shortcut") {
            toggleShortcut();
            syslog.log("SYS", root.shortcutStatus, "info");
        } else if (verb === "clear" || verb === "cls") {
            syslog.clear();
        } else if (verb === "exit" || verb === "quit") {
            shutdown();
        } else {
            syslog.log("ERR", "unknown command '" + verb + "' — type help", "warn");
            sfx("dialog-error");
        }
    }

    Connections {
        target: readiness
        function onWarningCountChanged() {
            syslog.log("ALERT", readiness.warningCount
                ? readiness.warningCount + " subsystem warning" + (readiness.warningCount > 1 ? "s" : "") + " active"
                : "all subsystems nominal", readiness.warningCount ? "warn" : "ok");
            if (readiness.warningCount)
                root.sfx("dialog-warning");
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
        target: depotSource
        function onRefreshedAtChanged() {
            syslog.log("DEPOT", root.depotPending ? root.depotPending + " updates waiting  ·  type update" : "all packages current",
                       root.depotPending ? "warn" : "ok");
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
        if (activeModule < 0)
            return;
        syslog.log("NAV", "SF-0" + (activeModule + 1) + " " + core.modules[activeModule].name.toLowerCase() + " online", "info");
        sfx("dialog-information");
        pulseGlitch();
        if (activeModule === 3) reactorSource.refresh();
        else if (activeModule === 4) commsSource.refresh();
        else if (activeModule === 6 && !codexSource.data) codexSource.refresh();
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
            transform: Scale {
                id: crt
                origin.x: screen.width / 2
                origin.y: screen.height / 2
            }
            Keys.onEscapePressed: {
                if (root.activeModule >= 0) {
                    root.releaseFocus();
                } else if (root.escArmed) {
                    root.shutdown();
                } else {
                    root.escArmed = true;
                    escDisarm.restart();
                }
            }
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

                // Forge state chip; doubles as the shutdown confirmation.
                Rectangle {
                    anchors.centerIn: parent
                    readonly property color tone: root.escArmed || core.forgeState !== "STABLE" ? dashboardTheme.urgentColor : dashboardTheme.accentColor
                    width: stateRow.implicitWidth + 32
                    height: 34
                    color: Util.alpha(tone, 0.1)
                    border.color: tone
                    Row {
                        id: stateRow
                        anchors.centerIn: parent
                        spacing: 10
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8; height: 8
                            color: parent.parent.tone
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: root.opened
                                NumberAnimation { to: 0.2; duration: root.escArmed ? 150 : 600 }
                                NumberAnimation { to: 1; duration: root.escArmed ? 150 : 600 }
                            }
                        }
                        DecodeText {
                            anchors.verticalCenter: parent.verticalCenter
                            source: root.escArmed ? "PRESS ESC AGAIN TO DISENGAGE"
                                : "FORGE " + core.forgeState + "  ·  HEAT " + Math.round(core.heat * 100) + "%"
                            color: parent.parent.tone
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
                    spacing: 1
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
                            + (missionSource.weatherCondition !== "—"
                               ? "   //   " + (missionSource.weatherCondition + " · " + missionSource.weatherValue).toUpperCase()
                               : "")
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
                readonly property var panelList: [tasks, projects, launcher, reactorPanel, commsPanel, depotPanel, codexPanel]
                readonly property var activePanel: root.activeModule >= 0 ? panelList[root.activeModule] || null : null

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
                    planetStates: [
                        { badge: root.badge(todos.remaining), alert: false,
                          progress: todos.totalCount ? todos.closedCount / todos.totalCount : -1,
                          detail: todos.remaining + " active · " + todos.closedCount + " closed" },
                        { badge: root.badge(github.actionableCount),
                          alert: github.actionItems.some(function(i) { return i.tone === "urgent"; }),
                          progress: -1, detail: github.actionableCount ? github.actionableCount + " need attention" : "inbox clear" },
                        { badge: "", alert: launcher.windows.some(function(w) { return w.urgent; }),
                          progress: -1, detail: launcher.windows.length + " windows in flight" },
                        { badge: "", alert: root.hottestTemp >= 85, progress: core.heat,
                          detail: root.hottestTemp >= 0 ? "peak " + Math.round(root.hottestTemp) + "°C" : "" },
                        { badge: "", alert: !readiness.networkOnline,
                          progress: root.activeNetwork ? root.activeNetwork.signal / 100 : -1,
                          detail: root.activeNetwork ? root.activeNetwork.ssid + " · " + root.activeNetwork.signal + "%" : "uplink offline" },
                        { badge: root.badge(root.depotPending), alert: false, progress: -1,
                          detail: root.depotPending ? root.depotPending + " updates waiting" : "all current" },
                        { badge: "", alert: false, progress: -1, detail: "searchable keybindings" }
                    ]
                    onModuleSelected: function(module) { root.toggleModule(module); }
                    onModuleNavigated: function(module) { root.selectModule(module); }
                    onModuleOpened: function(module) { root.openModule(module); }
                }

                // Energy conduit routed from the selected planet into the
                // open module, with pulses travelling along it.
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
                        ScriptAction { script: { panelContent.opacity = 0; panelHost.yScale = 0.01; } }
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
                        LauncherSection {
                            id: launcher
                            width: panelContent.width
                            theme: dashboardTheme
                            radar: workspaceRadarSource
                            availableHeight: panelContent.height
                            selected: root.activeModule === 2
                            visible: root.activeModule === 2
                            onDismissRequested: root.releaseFocus()
                            onLaunched: function(name) { launchFx.fire(name); }
                            onWindowFocused: function(title) {
                                syslog.log("HANGAR", "focus → " + title, "ok");
                                root.close();
                            }
                            onWindowClosed: function(title) { syslog.log("HANGAR", "closed " + title, "warn"); }
                        }
                        ReactorSection {
                            id: reactorPanel
                            width: panelContent.width
                            theme: dashboardTheme
                            source: reactorSource
                            flightModes: flightModes
                            availableHeight: panelContent.height
                            selected: root.activeModule === 3
                            visible: root.activeModule === 3
                            onDismissRequested: root.releaseFocus()
                        }
                        CommsSection {
                            id: commsPanel
                            width: panelContent.width
                            theme: dashboardTheme
                            source: commsSource
                            availableHeight: panelContent.height
                            selected: root.activeModule === 4
                            visible: root.activeModule === 4
                            onDismissRequested: root.releaseFocus()
                        }
                        DepotSection {
                            id: depotPanel
                            width: panelContent.width
                            theme: dashboardTheme
                            source: depotSource
                            availableHeight: panelContent.height
                            selected: root.activeModule === 5
                            visible: root.activeModule === 5
                            onDismissRequested: root.releaseFocus()
                            onUpdateLaunched: {
                                syslog.log("DEPOT", "full update launched in a floating terminal", "ok");
                                root.sfx("complete");
                            }
                        }
                        CodexSection {
                            id: codexPanel
                            width: panelContent.width
                            theme: dashboardTheme
                            source: codexSource
                            availableHeight: panelContent.height
                            selected: root.activeModule === 6
                            visible: root.activeModule === 6
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
                hint: "[:] COMMAND   [SPACE] LAUNCH   [ESC ESC] EXIT   [T G L R C D K] MODULES"
                completer: function(text) { return root.complete(text); }
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

            // Launch streak: a beam fires out of the forge, then the deck
            // closes so the new app takes the screen.
            Item {
                id: launchFx
                anchors.fill: parent
                z: 40
                visible: beam.width > 0 || flare.opacity > 0
                property string appName: ""
                function fire(name) {
                    appName = name;
                    syslog.log("HANGAR", "launching " + name, "ok");
                    root.sfx("service-login");
                    root.pulseGlitch();
                    launchAnim.restart();
                }
                Rectangle {
                    id: beam
                    anchors.verticalCenter: parent.verticalCenter
                    x: (parent.width - width) / 2
                    width: 0
                    height: 3
                    color: Qt.lighter(dashboardTheme.accentColor, 1.6)
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: 24
                        opacity: 0.25
                        gradient: Gradient {
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 0.5; color: dashboardTheme.accentColor }
                            GradientStop { position: 1; color: "transparent" }
                        }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: beam.top
                    anchors.bottomMargin: 18
                    opacity: beam.width > 0 ? 1 : 0
                    text: "LAUNCHING  //  " + launchFx.appName.toUpperCase()
                    color: dashboardTheme.foregroundColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: 22
                    font.bold: true
                    font.letterSpacing: 6
                }
                Rectangle {
                    id: flare
                    anchors.fill: parent
                    color: Qt.lighter(dashboardTheme.accentColor, 1.6)
                    opacity: 0
                }
                SequentialAnimation {
                    id: launchAnim
                    NumberAnimation { target: beam; property: "width"; from: 0; to: launchFx.width; duration: 320; easing.type: Easing.OutExpo }
                    PauseAnimation { duration: 220 }
                    NumberAnimation { target: flare; property: "opacity"; to: 0.7; duration: 90 }
                    ScriptAction { script: root.close() }
                    PropertyAction { target: beam; property: "width"; value: 0 }
                    PropertyAction { target: flare; property: "opacity"; value: 0 }
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

            // CRT power-off: squash to a line, pinch to a dot, close.
            SequentialAnimation {
                id: shutdownAnim
                NumberAnimation { target: crt; property: "yScale"; to: 0.004; duration: 220; easing.type: Easing.InQuad }
                PropertyAction { target: offLine; property: "opacity"; value: 1 }
                NumberAnimation { target: crt; property: "xScale"; to: 0; duration: 200; easing.type: Easing.InCubic }
                PauseAnimation { duration: 80 }
                ScriptAction { script: root.close() }
                PropertyAction { target: crt; property: "xScale"; value: 1 }
                PropertyAction { target: crt; property: "yScale"; value: 1 }
                PropertyAction { target: offLine; property: "opacity"; value: 0 }
            }
        }

        // CRT power-off line lives outside the scaled screen so it stays crisp.
        Rectangle {
            id: offLine
            anchors.centerIn: parent
            width: parent.width * crt.xScale
            height: 2
            color: Qt.lighter(dashboardTheme.accentColor, 1.8)
            opacity: 0
        }
    }
}
