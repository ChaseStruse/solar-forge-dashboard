import QtQuick
import qs.Commons

// Module heading: eyebrow, decoding title, subtitle, and a status chip.
Item {
    id: root
    required property DashboardTheme theme
    property string eyebrow: ""
    property string title: ""
    property string subtitle: ""
    property string status: ""
    property bool warning: false
    property bool busy: false
    width: parent ? parent.width : 0
    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width - chip.width - 16
        spacing: 4
        Text {
            visible: root.eyebrow.length > 0
            text: root.eyebrow
            color: root.theme.accentColor
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontMicro
            font.bold: true
            font.letterSpacing: 2.4
        }
        DecodeText {
            width: parent.width
            elide: Text.ElideRight
            source: root.title
            color: root.theme.foregroundColor
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontDisplay
            font.bold: true
            font.letterSpacing: 2
        }
        Text {
            visible: root.subtitle.length > 0
            width: parent.width
            wrapMode: Text.Wrap
            text: root.subtitle
            color: root.theme.dimmedTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontSmall
        }
    }

    Rectangle {
        id: chip
        visible: root.status.length > 0
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 4
        width: visible ? chipText.implicitWidth + 34 : 0
        height: 30
        readonly property color tone: root.warning ? root.theme.urgentColor : root.theme.accentColor
        color: Util.alpha(tone, 0.1)
        border.color: Util.alpha(tone, 0.7)
        Rectangle {
            x: 11
            anchors.verticalCenter: parent.verticalCenter
            width: 6; height: 6
            color: chip.tone
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.busy
                onRunningChanged: if (!running) parent.opacity = 1
                NumberAnimation { to: 0.15; duration: 300 }
                NumberAnimation { to: 1; duration: 300 }
            }
        }
        Text {
            id: chipText
            x: 24
            anchors.verticalCenter: parent.verticalCenter
            text: root.status
            color: chip.tone
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontMicro
            font.bold: true
            font.letterSpacing: 1.4
        }
    }
}
