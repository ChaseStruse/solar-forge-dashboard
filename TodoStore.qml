import QtQuick
import QtQuick.LocalStorage

// Owns persistence; views never issue SQL or clear input before a successful save.
QtObject {
    id: root
    property string databaseName: "solar-forge-dashboard"
    property string error: ""
    property int remaining: 0
    readonly property ListModel model: ListModel {}

    function database() {
        return LocalStorage.openDatabaseSync(databaseName, "1.0", "Solar Forge tasks", 1000000);
    }

    function load() {
        var rows = [];
        var active = 0;
        try {
            database().transaction(function (tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS todos (id INTEGER PRIMARY KEY, title TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)");
                var result = tx.executeSql("SELECT id, title, done FROM todos ORDER BY done ASC, created_at ASC, id ASC");
                for (var i = 0; i < result.rows.length; i++) {
                    var row = result.rows.item(i);
                    rows.push({
                        taskId: row.id,
                        title: row.title,
                        done: row.done === 1
                    });
                    if (row.done !== 1)
                        active++;
                }
            });
        } catch (failure) {
            error = "Could not load tasks. Check local storage and reopen the dashboard.";
            console.warn("Solar Forge: task load failed:", failure);
            return false;
        }
        // Preserve the last successful view if reading storage fails.
        model.clear();
        for (var j = 0; j < rows.length; j++)
            model.append(rows[j]);
        remaining = active;
        error = "";
        return true;
    }

    function write(sql, values) {
        try {
            database().transaction(function (tx) {
                tx.executeSql(sql, values);
            });
        } catch (failure) {
            error = "Could not save task. Check local storage and try again.";
            console.warn("Solar Forge: task save failed:", failure);
            return false;
        }
        load();
        return true;
    }

    function add(value) {
        var title = String(value || "").trim();
        if (!title)
            return false;
        return write("INSERT INTO todos (title, done, created_at) VALUES (?, ?, ?)", [title, 0, Date.now()]);
    }

    function setDone(taskId, done) {
        return write("UPDATE todos SET done = ? WHERE id = ?", [done ? 1 : 0, taskId]);
    }
}
