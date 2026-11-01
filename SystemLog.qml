import QtQuick
import qs.Commons

// Right rail: a terminal-style event stream. The newest line types itself
// out behind a block cursor; older lines dim as they scroll away.
Item {
    id: root
    required property DashboardTheme theme
    readonly property int capacity: 160

    function stamp() {
        return Qt.formatTime(new Date(), "HH:mm:ss");
    }
    // tone: "info" | "ok" | "warn" | "cmd" | "echo"
    function log(channel, message, tone) {
        lines.append({ time: stamp(), channel: String(channel || "SYS"), message: String(message || ""), tone: tone || "info" });
        while (lines.count > capacity)
            lines.remove(0);
        Qt.callLater(function() { view.positionViewAtEnd(); });
    }
    function clear() {
        lines.clear();
    }
    function toneColor(tone) {
        if (tone === "warn") return theme.urgentColor;
        if (tone === "ok") return theme.secondaryAccentColor;
        if (tone === "cmd") return theme.foregroundColor;
        if (tone === "echo") return theme.dimmedTextColor;
        return theme.accentColor;
    }

    ListModel { id: lines }

    HudFrame {
        anchors.fill: parent
        theme: root.theme
        tag: "SYSLOG // STREAM"
    }

    ListView {
        id: view
        anchors.fill: parent
        anchors.margins: 18
        anchors.topMargin: 26
        clip: true
        spacing: 5
        model: lines
        boundsBehavior: Flickable.StopAtBounds
        onCountChanged: positionViewAtEnd()
        delegate: Item {
            id: line
            required property int index
            required property string time
            required property string channel
            required property string message
            required property string tone
            readonly property bool newest: index === view.count - 1
            readonly property string full: (tone === "cmd" ? "❯ " : "") + message
            property int typed: newest ? 0 : full.length
            width: view.width
            height: body.implicitHeight
            opacity: Math.max(0.35, 1 - (view.count - 1 - index) * 0.035)

            NumberAnimation on typed {
                running: line.newest
                from: 0
                to: line.full.length
                duration: Math.min(900, line.full.length * 14)
            }

            Text {
                id: body
                width: parent.width
                wrapMode: Text.Wrap
                textFormat: Text.StyledText
                font.family: Style.font.menuFamily
                font.pixelSize: root.theme.fontSmall
                lineHeight: 1.15
                color: root.toneColor(line.tone)
                text: "<font color='" + root.theme.faintTextColor + "'>" + line.time + "</font> "
                    + "<b>" + line.channel + "</b>  "
                    + line.full.substring(0, line.typed).replace(/&/g, "&amp;").replace(/</g, "&lt;")
                    + (line.newest ? "<font color='" + root.theme.accentColor + "'>" + (cursorBlink.on ? "█" : " ") + "</font>" : "")
            }
        }
    }

    Timer {
        id: cursorBlink
        property bool on: true
        interval: 530
        repeat: true
        running: root.visible
        onTriggered: on = !on
    }
}
