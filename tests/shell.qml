import QtQuick
import Quickshell
import qs.Commons

ShellRoot {
    TodoStore {
        id: store
        databaseName: "solar-forge-refactor-test"
    }
    GitHubSource {
        id: github
    }
    Dashboard {
        id: dashboard
    }
    BarWidget {
        id: launcher
    }
    DashboardTheme {
        id: theme
    }
    FlightModesSource {
        id: flightModes
    }
    WorkspaceRadarSource {
        id: workspaceRadar
    }
    FlightModesSection {
        id: flightModesSection
        width: 800
        theme: theme
        source: flightModes
    }
    TodoSection {
        id: taskSection
        width: 600
        theme: theme
        store: store
    }
    ForgeCore {
        id: core
        width: 500
        theme: theme
        onModuleSelected: function(module) { dashboard.toggleModule(module); }
        onModuleNavigated: function(module) { dashboard.selectModule(module); }
        selectedModule: dashboard.activeModule
    }
    function check(condition, message) {
        if (!condition)
            throw new Error(message);
    }
    Timer {
        interval: 300
        running: true
        onTriggered: {
            try {
                check(store.load(), "initial load");
                check(store.model.count === 0, "isolated database");
                check(!store.add("  "), "reject blank task");
                for (var i = 0; i < 50; i++)
                    check(store.add("Task " + i), "add task");
                check(store.remaining === 50, "remaining count");
                var id = store.model.get(0).taskId;
                check(store.setDone(id, true), "complete task");
                check(store.remaining === 49, "updated count");
                check(store.load() && store.model.count === 50, "persisted tasks");
                check(store.model.get(49).taskId === id, "completed tasks sort last");
                var viewport = null;
                for (var child of taskSection.children)
                    if (child.objectName === "todoViewport")
                        viewport = child;
                check(viewport !== null && viewport.height === 130, "three-row viewport with 50 tasks");
                check(viewport.count === 50, "all tasks accessible");
                github.consume("[]");
                check(github.status === "NO REPOSITORIES FOUND", "empty repository list");
                github.consume("not json");
                check(github.status === "GITHUB RESPONSE UNREADABLE", "invalid JSON");
                github.consume("{}");
                check(github.repositories.length === 0, "reject non-array");
                github.consume('[{"name":"example","description":"<b>literal text</b>"}]');
                check(github.repositories.length === 1, "valid repository");
                check(flightModes.modes.length === 4, "four flight modes");
                check(flightModes.modeById("forge").name === "FORGE", "resolve flight mode");
                check(flightModes.modeById("missing") === null, "reject unknown flight mode");
                check(flightModes.scriptForMode("focus").indexOf("allow-idle") >= 0, "build focus mode command");
                check(flightModes.scriptForMode("missing") === "", "reject unknown mode command");
                check(!flightModes.apply("missing"), "unknown flight mode is not applied");
                check(flightModes.consumeStatus('{"stayAwake":true,"doNotDisturb":true,"nightlight":false,"powerProfile":"balanced"}'), "parse flight state");
                check(flightModes.stayAwake && flightModes.doNotDisturb && !flightModes.nightlight, "flight booleans update");
                check(flightModes.powerProfile === "balanced", "power profile updates");
                check(!flightModes.consumeStatus("bad state"), "reject malformed flight state");
                check(workspaceRadar.consume('[{"id":2,"name":"2","windows":2},{"id":1,"name":"dev","windows":1},{"id":-99,"name":"special:scratch"}]', '[{"address":"0xabc","class":"foot","title":"Terminal","workspace":{"id":1},"urgent":false},{"address":"0xdef","class":"firefox","title":"Alert","workspace":{"id":2},"urgent":true}]', '{"id":2}'), "parse workspace topology");
                check(workspaceRadar.workspaces.length === 2, "ignore special workspaces");
                check(workspaceRadar.workspaces[0].id === 1, "sort workspace planets");
                check(workspaceRadar.workspaces[1].windows.length === 1, "attach window moons");
                check(workspaceRadar.workspaces[1].urgent, "propagate urgent distress state");
                check(workspaceRadar.focusedWorkspaceId === 2, "track focused workspace");
                workspaceRadar.handleEvent("urgent>>0xabc");
                check(workspaceRadar.workspaces[0].urgent, "track urgent event signal");
                workspaceRadar.handleEvent("activewindowv2>>0xabc");
                check(!workspaceRadar.workspaces[0].urgent, "clear distress when focused");
                check(!workspaceRadar.focusWorkspace(-1), "reject invalid workspace action");
                check(!workspaceRadar.focusWindow("bad-address"), "reject invalid window action");
                check(!workspaceRadar.consume("bad state", "[]", "{}"), "reject malformed workspace state");
                check(flightModesSection.implicitHeight > 0, "flight mode panel lays out");
                check(theme.accentColor === Color.accent, "core color follows theme accent");
                check(theme.secondaryAccentColor === Color.bar.active, "planet color follows theme secondary accent");
                dashboard.opened = true;
                dashboard.close();
                dashboard.close();
                check(!dashboard.opened, "idempotent close");
                dashboard.opened = true;
                check(dashboard.opened, "reopen");
                dashboard.close();
                dashboard.activeModule = -1;
                core.moduleSelected(0);
                check(dashboard.activeModule === 0, "toggle opens Objectives");
                core.moduleSelected(0);
                check(dashboard.activeModule === -1, "toggle closes Objectives");
                core.moduleNavigated(1);
                core.moduleNavigated(1);
                check(dashboard.activeModule === 1, "navigation selects without toggling closed");
                dashboard.openModule(42);
                check(dashboard.activeModule === 1, "invalid module ignored");
                core.moduleSelected(3);
                check(dashboard.activeModule === 3, "toggle opens Flight Modes");
                core.animating = true;
                lifecycle.start();
            } catch (failure) {
                console.error("SOLAR_FORGE_TESTS_FAILED", failure);
                Qt.quit();
            }
        }
    }
    Timer {
        id: lifecycle
        interval: 500
        repeat: true
        property int step: 0
        property real held: 0
        onTriggered: {
            try {
                if (step === 0) {
                    check(core.corePhase > 0, "orbit advances");
                    core.pointerPaused = true;
                    held = core.corePhase;
                } else if (step === 1) {
                    check(core.corePhase === held, "hover pauses orbit");
                    core.pointerPaused = false;
                } else if (step === 2) {
                    check(core.corePhase > held, "orbit resumes without reset");
                    core.animating = false;
                    held = core.corePhase;
                } else if (step === 3) {
                    check(core.corePhase === held, "hidden orbit is paused");
                    console.log("SOLAR_FORGE_TESTS_PASSED");
                    Qt.quit();
                }
                step++;
            } catch (failure) {
                console.error("SOLAR_FORGE_TESTS_FAILED", failure);
                Qt.quit();
            }
        }
    }
}
