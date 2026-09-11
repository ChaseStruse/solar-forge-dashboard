import QtQuick
import QtQuick.Layouts
import qs.Commons

Column {
    id: root
    required property DashboardTheme theme
    required property string title
    required property string subtitle
    required property var events
    required property bool future
    required property color autonomousColor
    required property color weatherColor
    spacing: 11

    function toneColor(tone) {
        if (tone === "autonomous") return autonomousColor;
        if (tone === "weather") return weatherColor;
        if (tone === "urgent") return theme.urgentColor;
        return theme.accentColor;
    }

    RowLayout {
        width: parent.width
        Text { text: root.title; color: root.theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.1 }
        Item { Layout.fillWidth: true }
        Text { text: root.subtitle; color: root.future ? root.theme.faintTextColor : root.autonomousColor; font.family: Style.font.menuFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1.1 }
    }
    Rectangle { width: parent.width; height: 1; color: root.theme.borderColor }
    Repeater {
        model: root.events
        Item {
            required property var modelData
            width: root.width
            height: 58
            opacity: 0
            NumberAnimation on opacity {
                from: 0; to: 1; duration: 320
                easing.type: Easing.OutCubic
            }
            Text { id: timeText; width: 40; text: modelData.time; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 10; topPadding: 3 }
            Rectangle { x: 45; y: 4; width: 9; height: 9; radius: 5; color: root.future ? root.theme.backgroundColor : root.toneColor(modelData.tone); border.color: root.toneColor(modelData.tone); border.width: 2 }
            Rectangle { x: 49; y: 15; width: 1; height: 43; color: root.theme.borderColor }
            Column {
                x: 66; width: parent.width - x; spacing: 3
                Text { text: modelData.kind; color: root.toneColor(modelData.tone); font.family: Style.font.menuFamily; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1 }
                Text { width: parent.width; text: modelData.title; elide: Text.ElideRight; color: root.theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 11; font.bold: true }
                Text { width: parent.width; text: modelData.detail; elide: Text.ElideRight; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 9 }
            }
        }
    }
}
