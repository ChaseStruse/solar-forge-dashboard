import QtQuick
import qs.Commons

Column {
    id: root
    required property DashboardTheme theme
    required property GitHubSource source
    property bool selected: false

    spacing: 8
    topPadding: 12

    Text {
        width: parent.width
        wrapMode: Text.Wrap
        text: "GITHUB // " + root.source.status
        color: root.selected ? root.theme.accentColor : root.theme.dimmedTextColor
        font.family: root.theme.fontFamily
        font.pixelSize: 14
        font.letterSpacing: 1.4
    }

    Repeater {
        model: root.source.repositories
        delegate: Rectangle {
            required property var modelData
            width: parent.width
            height: 46
            color: root.theme.surfaceColor
            border.color: root.theme.borderColor
            border.width: 1

            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                spacing: 2
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: modelData.name + (modelData.isPrivate ? "  [PRIVATE]" : "")
                    color: root.theme.foregroundColor
                    font.family: root.theme.fontFamily
                    font.pixelSize: 14
                }
                Text {
                    textFormat: Text.PlainText
                    text: modelData.description || "No description"
                    color: root.theme.dimmedTextColor
                    font.family: root.theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    width: parent.width
                }
            }
        }
    }
}
