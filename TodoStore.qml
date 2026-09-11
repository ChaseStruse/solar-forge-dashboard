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
                var columns = tx.executeSql("PRAGMA table_info(todos)");
                var hasReminderUnit = false, hasReminderDue = false;
                for (var c = 0; c < columns.rows.length; c++) {
                    hasReminderUnit = hasReminderUnit || columns.rows.item(c).name === "reminder_unit";
                    hasReminderDue = hasReminderDue || columns.rows.item(c).name === "reminder_due";
                }
                if (!hasReminderUnit) tx.executeSql("ALTER TABLE todos ADD COLUMN reminder_unit TEXT");
                if (!hasReminderDue) tx.executeSql("ALTER TABLE todos ADD COLUMN reminder_due INTEGER");
                var result = tx.executeSql("SELECT id, title, done, reminder_unit, reminder_due FROM todos ORDER BY done ASC, created_at ASC, id ASC");
                for (var i = 0; i < result.rows.length; i++) {
                    var row = result.rows.item(i);
                    rows.push({
                        taskId: row.id,
                        title: row.title,
                        done: row.done === 1,
                        reminderUnit: String(row.reminder_unit || ""),
                        reminderDue: Number(row.reminder_due || 0)
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
        return write("UPDATE todos SET done = ?, reminder_unit = CASE WHEN ? = 1 THEN NULL ELSE reminder_unit END, reminder_due = CASE WHEN ? = 1 THEN NULL ELSE reminder_due END WHERE id = ?", [done ? 1 : 0, done ? 1 : 0, done ? 1 : 0, taskId]);
    }

    function setReminder(taskId, unit, due) {
        if (!/^omarchy-reminder-[0-9]+m-[0-9]+$/.test(String(unit || "")) || Number(due) <= 0)
            return false;
        return write("UPDATE todos SET reminder_unit = ?, reminder_due = ? WHERE id = ? AND done = 0", [String(unit), Math.floor(Number(due)), taskId]);
    }

    function reconcileReminders(reminders, now) {
        var active = {};
        for (var i = 0; i < reminders.length; i++)
            if (reminders[i].unit) active[reminders[i].unit] = reminders[i];
        var changed = false;
        try {
            database().transaction(function(tx) {
                var result = tx.executeSql("SELECT id, reminder_unit, reminder_due FROM todos WHERE done = 0 AND reminder_unit IS NOT NULL");
                for (var j = 0; j < result.rows.length; j++) {
                    var row = result.rows.item(j);
                    if (active[row.reminder_unit]) {
                        var live = active[row.reminder_unit];
                        if (live.at && Number(live.at) !== Number(row.reminder_due)) {
                            tx.executeSql("UPDATE todos SET reminder_due = ? WHERE id = ?", [Math.floor(live.at), row.id]);
                            changed = true;
                        }
                    } else if (Number(row.reminder_due) > 0 && Number(row.reminder_due) <= Number(now)) {
                        tx.executeSql("UPDATE todos SET done = 1, reminder_unit = NULL, reminder_due = NULL WHERE id = ?", [row.id]);
                        changed = true;
                    }
                }
            });
        } catch (failure) {
            error = "Could not synchronize reminders with objectives.";
            return false;
        }
        if (changed) load();
        return true;
    }
}
