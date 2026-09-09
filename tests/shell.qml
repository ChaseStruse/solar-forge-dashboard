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
                console.log("SOLAR_FORGE_TESTS_PASSED");
            } catch (failure) {
                console.error("SOLAR_FORGE_TESTS_FAILED", failure);
            }
            Qt.quit();
        }
    }
}
