import QtQuick
import qs.Commons

// Bracketed HUD action: outlined, fills on hover/active.
Item {
    id: root
    required property DashboardTheme theme
    property string label: ""
    property string glyph: ""
    property bool active: false
    property bool danger: false
    property bool available: true
    signal clicked()
    readonly property color tone: danger ? theme.urgentColor : theme.accentColor
    readonly property bool lit: active || mouse.containsMouse
    implicitWidth: row.implicitWidth + 30
    implicitHeight: 34
    opacity: available ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        color: root.lit ? Util.alpha(root.tone, root.active ? 0.85 : 0.18) : "transparent"
        border.color: Util.alpha(root.tone, root.lit ? 1 : 0.55)
        Behavior on color { ColorAnimation { duration: 140 } }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        Text {
            visible: root.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            color: root.active ? root.theme.backgroundColor : root.tone
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.active ? root.theme.backgroundColor : root.tone
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontMicro
            font.bold: true
            font.letterSpacing: 1.4
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.available
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
