import QtQuick
import qs.Commons

Rectangle {
    id: root
    required property DashboardTheme theme
    required property DailyBriefingSource source
    required property string operatorName
    property bool active: false
    property int hour: 18
    property int messageIndex: 0
    property bool resetting: false
    readonly property string greetingText: "Good " + (hour < 12 ? "morning" : hour < 18 ? "afternoon" : "evening")
        + ", " + operatorName + "."
    implicitHeight: content.implicitHeight + 28
    color: theme.surfaceColor
    border.color: theme.borderColor
    border.width: 1
    onActiveChanged: if (!active) briefingTransition.stop()

    function replay() {
        resetting = true;
        messageIndex = 0;
        messageStack.y = Qt.binding(function() {
            return root.messageIndex === 0 ? 0 : -greeting.height - 8;
        });
        resetting = false;
        briefingTransition.restart();
    }

    Timer {
        id: briefingTransition
        interval: 2600
        onTriggered: root.messageIndex = 1
    }

    Column {
        id: content
        x: 14
        y: 14
        width: parent.width - 28
        spacing: 8
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "DAILY BRIEFING // ENERGY REPORT"
            color: root.theme.accentColor
            font.family: Style.font.menuFamily
            font.pixelSize: 12
            font.letterSpacing: 1.4
        }
        Item {
            width: parent.width
            height: Math.max(greeting.implicitHeight, recommendation.implicitHeight)
            clip: true
            Column {
                id: messageStack
                width: parent.width
                y: root.messageIndex === 0 ? 0 : -greeting.height - 8
                spacing: 8
                Behavior on y {
                    enabled: !root.resetting
                    NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
                }
                Text {
                    id: greeting
                    width: parent.width
                    text: root.greetingText
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: root.theme.foregroundColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: 16
                    opacity: root.messageIndex === 0 ? 1 : 0
                }
                Text {
                    id: recommendation
                    width: parent.width
                    text: root.source.recommendation
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: root.theme.foregroundColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: 14
                    opacity: root.messageIndex === 1 ? 1 : 0
                }
            }
        }
        Flow {
            width: parent.width
            spacing: 18
            Repeater {
                model: ["GENERATION  " + root.source.generation,
                        "SAVED  " + root.source.savings,
                        "FORECAST  " + root.source.forecast]
                Text {
                    required property string modelData
                    width: Math.min(implicitWidth, content.width)
                    text: modelData
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: root.theme.dimmedTextColor
                    font.family: Style.font.menuFamily
                    font.pixelSize: 11
                }
            }
        }
    }
}
