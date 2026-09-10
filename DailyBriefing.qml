import QtQuick
import qs.Commons

Rectangle {
    id: root
    required property DashboardTheme theme
    required property DailyBriefingSource source
    required property string operatorName
    implicitHeight: 116
    color: theme.surfaceColor
    border.color: theme.borderColor
    border.width: 1

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
        Text {
            width: parent.width
            text: "Good evening, " + root.operatorName + ". " + root.source.recommendation
            wrapMode: Text.Wrap
            color: root.theme.foregroundColor
            font.family: Style.font.menuFamily
            font.pixelSize: 14
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
