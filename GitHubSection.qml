import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

Column {
    id: root
    required property DashboardTheme theme
    required property GitHubSource source
    property bool selected: false
    property int selectedIndex: 0
    signal dismissRequested

    spacing: 12
    topPadding: 8
    bottomPadding: 4
    focus: true

    function ageLabel(value) {
        var stamp = new Date(value);
        var elapsed = Date.now() - stamp.getTime();
        if (isNaN(elapsed) || elapsed < 0)
            return "NOW";
        var minutes = Math.floor(elapsed / 60000);
        if (minutes < 60)
            return Math.max(1, minutes) + "m";
        var hours = Math.floor(minutes / 60);
        if (hours < 24)
            return hours + "h";
        return Math.floor(hours / 24) + "d";
    }

    function itemColor(item) {
        return item.tone === "urgent" ? root.theme.urgentColor
            : item.tone === "autonomous" ? root.theme.secondaryAccentColor
            : root.theme.accentColor;
    }

    function openUrl(url) {
        var target = String(url || "");
        if (/^https:\/\/github\.com\//.test(target))
            Qt.openUrlExternally(target);
    }

    function moveSelection(delta) {
        if (!root.source.visibleItems.length)
            return;
        selectedIndex = (selectedIndex + delta + root.source.visibleItems.length)
            % root.source.visibleItems.length;
    }

    onVisibleChanged: if (visible) selectedIndex = 0
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Down
                || event.key === Qt.Key_L || event.key === Qt.Key_J || event.key === Qt.Key_Tab) {
            moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up
                || event.key === Qt.Key_H || event.key === Qt.Key_K || event.key === Qt.Key_Backtab) {
            moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (root.source.visibleItems.length)
                openUrl(root.source.visibleItems[selectedIndex].url);
            event.accepted = true;
        } else if (event.key === Qt.Key_F5) {
            root.source.refresh();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.dismissRequested();
            event.accepted = true;
        }
    }

    RowLayout {
        width: parent.width
        Text {
            Layout.fillWidth: true
            text: "GITHUB COMMAND CENTER"
            color: root.theme.accentColor
            font.family: Style.font.menuFamily
            font.pixelSize: 17
            font.bold: true
            font.letterSpacing: 1.7
        }
        Text {
            text: root.source.viewerLogin ? "@" + root.source.viewerLogin : "IDENTITY OFFLINE"
            color: root.theme.secondaryAccentColor
            font.family: Style.font.menuFamily
            font.pixelSize: 12
            font.bold: true
        }
        Text {
            text: root.source.loading ? "SYNCING" : "UPDATED " + (root.source.refreshedAt || "—")
            color: root.theme.faintTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: 11
        }
    }

    GridLayout {
        width: parent.width
        columns: root.width < 720 ? 3 : 6
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: root.source.profileStats
            delegate: Rectangle {
                required property int index
                required property var modelData
                Layout.fillWidth: true
                implicitWidth: 120
                implicitHeight: 64
                color: Util.alpha(index % 2 ? root.theme.secondaryAccentColor : root.theme.accentColor, 0.07)
                border.color: Util.alpha(index % 2 ? root.theme.secondaryAccentColor : root.theme.accentColor, 0.28)
                border.width: 1
                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: String(modelData.value)
                        color: index % 2 ? root.theme.secondaryAccentColor : root.theme.accentColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        color: root.theme.dimmedTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 9
                        font.letterSpacing: 0.7
                    }
                }
            }
        }
    }

    RowLayout {
        width: parent.width
        Text {
            text: "PRIORITY QUEUE"
            color: root.theme.foregroundColor
            font.family: Style.font.menuFamily
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 1.1
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.borderColor }
        Text {
            text: root.source.status
            color: root.source.actionableCount ? root.theme.urgentColor : root.theme.secondaryAccentColor
            font.family: Style.font.menuFamily
            font.pixelSize: 11
            font.bold: true
        }
    }

    Rectangle {
        width: parent.width
        height: 74
        visible: !root.source.loading && root.source.actionableCount === 0
        color: Util.alpha(root.theme.secondaryAccentColor, 0.07)
        border.color: Util.alpha(root.theme.secondaryAccentColor, 0.32)
        Column {
            anchors.centerIn: parent
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "✓ ALL SYSTEMS CLEAR"
                color: root.theme.secondaryAccentColor
                font.family: Style.font.menuFamily
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 1
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No reviews, checks, mentions, or assignments require attention"
                color: root.theme.dimmedTextColor
                font.family: Style.font.menuFamily
                font.pixelSize: 11
            }
        }
    }

    GridLayout {
        width: parent.width
        columns: root.width < 720 ? 1 : 2
        columnSpacing: 10
        rowSpacing: 10
        Repeater {
            model: root.source.visibleItems
            delegate: Rectangle {
                required property int index
                required property var modelData
                Layout.fillWidth: true
                implicitWidth: 300
                implicitHeight: 82
                color: index === root.selectedIndex && root.activeFocus
                    ? Util.alpha(root.itemColor(modelData), 0.13) : root.theme.surfaceColor
                border.color: index === root.selectedIndex && root.activeFocus
                    ? root.itemColor(modelData) : root.theme.borderColor
                border.width: 1

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4
                    RowLayout {
                        width: parent.width
                        Text {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: modelData.kind + "  //  " + modelData.repository
                            color: root.itemColor(modelData)
                            font.family: Style.font.menuFamily
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 0.6
                        }
                        Text {
                            text: root.ageLabel(modelData.updatedAt)
                            color: root.theme.faintTextColor
                            font.family: Style.font.menuFamily
                            font.pixelSize: 10
                        }
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: modelData.title
                        color: root.theme.foregroundColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 13
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: modelData.detail
                        color: root.theme.dimmedTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 10
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = index
                    onClicked: {
                        root.selectedIndex = index;
                        root.openUrl(modelData.url);
                    }
                }
            }
        }
    }

    RowLayout {
        width: parent.width
        Text {
            text: "REPOSITORY PULSE"
            color: root.theme.foregroundColor
            font.family: Style.font.menuFamily
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 1.1
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: root.theme.borderColor }
        Text {
            text: "RECENTLY ACTIVE"
            color: root.theme.faintTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: 10
        }
    }

    GridLayout {
        width: parent.width
        columns: root.width < 720 ? 2 : 4
        columnSpacing: 8
        rowSpacing: 8
        Repeater {
            model: root.source.repositories
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitWidth: 150
                implicitHeight: 54
                color: root.theme.surfaceColor
                border.color: root.theme.borderColor
                border.width: 1
                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: modelData.name
                        color: root.theme.foregroundColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 11
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: String(modelData.stargazerCount || 0) + " ★  ·  pushed " + root.ageLabel(modelData.pushedAt)
                        color: root.theme.dimmedTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 9
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openUrl(modelData.url)
                }
            }
        }
    }

    Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "[ ARROWS / HJKL ] SELECT  ·  [ ENTER ] OPEN  ·  [ F5 ] SYNC  ·  [ ESC ] ORBIT"
        color: root.theme.faintTextColor
        font.family: Style.font.menuFamily
        font.pixelSize: 10
    }
}
