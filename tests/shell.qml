import QtQuick
import Quickshell

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
    TodoSection {
        id: taskSection
        width: 600
        theme: theme
        store: store
    }
    DailyBriefingSource { id: briefingSource }
    DailyBriefing {
        id: briefing
        width: 300
        theme: theme
        source: briefingSource
        operatorName: "<b>Operator</b>"
        active: true
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
                dashboard.opened = true;
                dashboard.close();
                dashboard.close();
                check(!dashboard.opened, "idempotent close");
                dashboard.opened = true;
                check(dashboard.opened, "reopen");
                dashboard.close();
                for (var value of [undefined, null, "", "  ", "bad", "-1", "Infinity"])
                    check(isNaN(briefingSource.parseReading(value)), "invalid reading must be unavailable");
                check(briefingSource.parseReading("0") === 0, "zero is a valid reading");
                check(briefingSource.parseReading(" 18.4 ") === 18.4, "numeric reading");
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
                briefing.hour = 8;
                check(briefing.greetingText.indexOf("Good morning") === 0, "morning greeting");
                briefing.hour = 14;
                check(briefing.greetingText.indexOf("Good afternoon") === 0, "afternoon greeting");
                briefing.messageIndex = 1;
                briefing.replay();
                check(briefing.messageIndex === 0, "briefing replay resets");
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
                } else if (step === 6) {
                    check(briefing.messageIndex === 1, "briefing advances");
                    briefing.replay();
                    check(briefing.messageIndex === 0, "reopen resets greeting");
                    briefing.active = false;
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
