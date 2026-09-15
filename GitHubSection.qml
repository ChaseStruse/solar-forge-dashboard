import QtQuick
import QtQuick.Controls
import qs.Commons

Column {
    id: root
    required property DashboardTheme theme
    required property GitHubSource source
    property bool selected: false
    property int selectedIndex: 0
    signal dismissRequested

    spacing: 8
    topPadding: 12
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
        if (event.key === Qt.Key_Down || event.key === Qt.Key_J || event.key === Qt.Key_Tab) {
            moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K || event.key === Qt.Key_Backtab) {
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

    Row {
        width: parent.width
        spacing: 8
        Text {
            width: parent.width - syncLabel.width - parent.spacing
            wrapMode: Text.Wrap
            text: "GITHUB // " + root.source.status
            color: root.selected ? root.theme.accentColor : root.theme.dimmedTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: 14
            font.letterSpacing: 1.2
        }
        Text {
            id: syncLabel
            text: root.source.loading ? "SYNC" : root.source.refreshedAt || "—"
            color: root.theme.faintTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: 11
        }
    }

    Repeater {
        model: root.source.visibleItems
        delegate: Rectangle {
            required property int index
            required property var modelData
            width: root.width
            height: 68
            color: index === root.selectedIndex && root.activeFocus
                ? Util.alpha(root.itemColor(modelData), 0.13) : root.theme.surfaceColor
            border.color: index === root.selectedIndex && root.activeFocus
                ? root.itemColor(modelData) : root.theme.borderColor
            border.width: 1

            Column {
                anchors.fill: parent
                anchors.margins: 9
                spacing: 3
                Row {
                    width: parent.width
                    spacing: 6
                    Text {
                        width: parent.width - age.width - parent.spacing
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: modelData.kind + "  //  " + modelData.repository
                        color: root.itemColor(modelData)
                        font.family: Style.font.menuFamily
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 0.7
                    }
                    Text {
                        id: age
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

    Column {
        width: parent.width
        spacing: 6
        visible: !root.source.loading && root.source.actionableCount === 0
        Text {
            width: parent.width
            wrapMode: Text.Wrap
            text: "✓ NOTHING REQUIRES ACTION\nRecent launch points"
            color: root.theme.secondaryAccentColor
            font.family: Style.font.menuFamily
            font.pixelSize: 12
        }
        Repeater {
            model: root.source.repositories
            delegate: Rectangle {
                required property var modelData
                width: root.width
                height: 48
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
                        text: modelData.nameWithOwner || modelData.name
                        color: root.theme.foregroundColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 12
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: modelData.description || "No description"
                        color: root.theme.dimmedTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: 10
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
        text: root.source.actionableCount ? "[ ↑↓ ] SELECT  ·  [ ENTER ] OPEN  ·  [ F5 ] SYNC" : "[ F5 ] SYNC"
        color: root.theme.faintTextColor
        font.family: Style.font.menuFamily
        font.pixelSize: 10
    }
}
