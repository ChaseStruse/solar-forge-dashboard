import QtQuick
import qs.Commons

Rectangle {
    id: root
    required property DashboardTheme theme
    required property DailyBriefingSource source
    required property string operatorName
    property int messageIndex: 0
    implicitHeight: 116
    color: theme.surfaceColor
    border.color: theme.borderColor
    border.width: 1

    function replay() {
        messageIndex = 0;
        briefingTransition.restart();
    }

    Timer {
        id: briefingTransition
        interval: 2600
        repeat: false
        running: true
        onTriggered: root.messageIndex = 1
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8
        Text {
            text: "DAILY BRIEFING // PROACTIVE ENERGY REPORT"
            color: root.theme.accentColor
            font.family: Style.font.menuFamily
            font.pixelSize: 12
            font.letterSpacing: 1.4
        }
        Item {
            id: messageViewport
            width: parent.width
            height: 34
            clip: true
            Column {
                id: messageStack
                width: parent.width
                y: root.messageIndex === 0 ? 0 : -greeting.height - 8
                spacing: 8
                Behavior on y {
                    NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
                }
                Text {
                    id: greeting
                    width: parent.width
                    text: "Good evening, " + root.operatorName + "."
                    color: root.theme.foregroundColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: 16
                }
                Text {
                    width: parent.width
                    text: root.source.recommendation
                    wrapMode: Text.Wrap
                    color: root.theme.foregroundColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: 14
                }
            }
        }
        Row {
            width: parent.width
            spacing: 18
            Text { text: "GENERATION  " + root.source.generation; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 11 }
            Text { text: "SAVED  " + root.source.savings; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 11 }
            Text { text: "FORECAST  " + root.source.forecast; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 11 }
        }
    }
}
