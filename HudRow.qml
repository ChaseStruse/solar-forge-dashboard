import QtQuick
import qs.Commons

// Selectable list row: accent rail when selected, glyph, title/detail, trailing text.
Rectangle {
    id: root
    required property DashboardTheme theme
    property bool selected: false
    property string glyph: ""
    property url icon: ""
    property string title: ""
    property string detail: ""
    property string trailing: ""
    property color tone: theme.accentColor
    property bool dim: false
    signal activated()
    signal picked()
    width: parent ? parent.width : 0
    height: detail.length ? 50 : 38
    color: selected ? Util.alpha(tone, 0.14) : mouse.containsMouse ? root.theme.surfaceColor : "transparent"
    border.color: selected ? Util.alpha(tone, 0.6) : "transparent"
    opacity: dim ? 0.55 : 1

    Rectangle {
        width: 3
        height: parent.height
        color: root.tone
        visible: root.selected
    }
    Item {
        id: lead
        x: 14
        width: 26
        height: parent.height
        Image {
            id: iconImage
            anchors.centerIn: parent
            visible: root.icon.toString().length > 0 && status === Image.Ready
            source: root.icon
            sourceSize: Qt.size(24, 24)
            width: 24
            height: 24
        }
        Text {
            anchors.centerIn: parent
            visible: iconImage.status !== Image.Ready
            text: root.glyph
            color: root.tone
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
        }
    }
    Column {
        anchors.left: lead.right
        anchors.leftMargin: 12
        anchors.right: trailingText.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.title
            color: root.selected ? root.theme.foregroundColor : Util.alpha(root.theme.foregroundColor, 0.86)
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontBody
            font.bold: root.selected
        }
        Text {
            visible: root.detail.length > 0
            width: parent.width
            elide: Text.ElideRight
            text: root.detail
            color: root.theme.faintTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontMicro
        }
    }
    Text {
        id: trailingText
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.trailing
        color: root.tone
        font.family: Style.font.menuFamily
        font.pixelSize: root.theme.fontMicro
        font.bold: true
        font.letterSpacing: 1.2
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked()
        onDoubleClicked: root.activated()
    }
}
