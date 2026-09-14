import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons

Item {
    id: root
    required property DashboardTheme theme
    required property ThemeReactorSource source
    property bool selected: false
    property int selectedIndex: 0
    signal dismissRequested()
    implicitHeight: content.implicitHeight + 48
    focus: true

    function focusControls() {
        forceActiveFocus()
        var current = source.themeByName(source.currentTheme)
        if (current)
            for (var i = 0; i < source.themes.length; i++)
                if (source.themes[i].name === current.name) selectedIndex = i
    }

    function moveSelection(delta) {
        if (!source.themes.length)
            return
        selectedIndex = (selectedIndex + delta + source.themes.length) % source.themes.length
        themeGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Left) {
            moveSelection(-1); event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            moveSelection(1); event.accepted = true
        } else if (event.key === Qt.Key_Up) {
            moveSelection(-themeGrid.columns); event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            moveSelection(themeGrid.columns); event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            if (source.themes[selectedIndex]) source.applyTheme(source.themes[selectedIndex].name)
            event.accepted = true
        } else if (event.key === Qt.Key_B) {
            source.nextBackground(); event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            root.dismissRequested(); event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Util.alpha(root.theme.backgroundColor, 0.96)
        border.color: root.theme.borderColor
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 24
        spacing: 18

        RowLayout {
            width: parent.width
            spacing: 14
            Column {
                Layout.fillWidth: true
                spacing: 5
                Text { text: "THEME REACTOR"; color: root.theme.accentColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.6 }
                Text { text: root.source.currentTheme.toUpperCase(); color: root.theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 25; font.bold: true }
                Text { text: "CURRENT STELLAR IDENTITY"; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 11; font.letterSpacing: 1.2 }
            }
            Rectangle {
                implicitWidth: 158
                implicitHeight: 30
                radius: 15
                color: root.theme.surfaceColor
                border.color: root.source.loading ? root.theme.accentColor : root.theme.borderColor
                Text { anchors.centerIn: parent; text: root.source.loading ? "REACTOR SHIFTING" : "REACTOR STABLE"; color: root.source.loading ? root.theme.accentColor : root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 11; font.bold: true }
            }
        }

        GridLayout {
            width: parent.width
            columns: root.width < 760 ? 1 : 2
            columnSpacing: 18
            rowSpacing: 14

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 220
                radius: 8
                clip: true
                color: root.theme.surfaceColor
                border.color: root.theme.accentColor
                Image {
                    anchors.fill: parent
                    source: root.source.wallpaperPath ? "file://" + root.source.wallpaperPath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    visible: status === Image.Ready
                }
                Rectangle { anchors.fill: parent; color: root.theme.accentColor; opacity: 0.10 }
                Repeater {
                    model: 9
                    Rectangle {
                        required property int index
                        x: 0; y: index * parent.height / 9
                        width: parent.width; height: 1
                        color: root.theme.accentColor; opacity: 0.13
                    }
                }
                Column {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 12; spacing: 3
                    Text { text: "HOLOGRAPHIC BACKGROUND FEED"; color: root.theme.accentColor; font.family: Style.font.menuFamily; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                    Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: root.source.wallpaperName; color: root.theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 13; font.bold: true }
                }
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 10
                Text { text: "REACTOR CONTROLS"; color: root.theme.accentColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.2 }
                Text { width: parent.width; wrapMode: Text.Wrap; text: "Selecting a star applies its full Omarchy palette. The Solar Forge interface will transform with the live system theme."; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 12 }
                Rectangle {
                    width: parent.width; height: 42; radius: 6
                    color: backgroundHover.containsMouse ? Util.alpha(root.theme.accentColor, 0.14) : root.theme.surfaceColor
                    border.color: root.theme.borderColor
                    Text { anchors.centerIn: parent; text: "CYCLE BACKGROUND  //  B"; color: root.theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1 }
                    MouseArea { id: backgroundHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.source.nextBackground() }
                }
                Rectangle {
                    width: parent.width; height: 38; radius: 6
                    color: scanHover.containsMouse ? root.theme.surfaceColor : "transparent"
                    border.color: root.theme.borderColor
                    Text { anchors.centerIn: parent; text: "RESCAN INSTALLED THEMES"; color: root.theme.dimmedTextColor; font.family: Style.font.menuFamily; font.pixelSize: 11; font.bold: true }
                    MouseArea { id: scanHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.source.refresh() }
                }
                Text { width: parent.width; wrapMode: Text.Wrap; textFormat: Text.PlainText; text: root.source.status; color: root.source.status.indexOf("FAILED") >= 0 || root.source.status.indexOf("UNREADABLE") >= 0 ? root.theme.urgentColor : root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 11 }
            }
        }

        RowLayout {
            width: parent.width
            Text { text: "INSTALLED STELLAR STATES"; color: root.theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.2 }
            Item { Layout.fillWidth: true }
            Text { text: root.source.themes.length + " THEMES"; color: root.theme.accentColor; font.family: Style.font.menuFamily; font.pixelSize: 11; font.bold: true }
        }

        GridView {
            id: themeGrid
            objectName: "themeGrid"
            readonly property int columns: Math.max(2, Math.floor(width / 145))
            width: parent.width
            height: 250
            cellWidth: width / columns
            cellHeight: 82
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.source.themes
            ScrollBar.vertical: ScrollBar { policy: themeGrid.contentHeight > themeGrid.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
            delegate: Item {
                required property int index
                required property var modelData
                width: themeGrid.cellWidth
                height: themeGrid.cellHeight
                Rectangle {
                    anchors.fill: parent; anchors.margins: 4; radius: 7
                    color: modelData.current ? Util.alpha(modelData.accent, 0.16) : root.theme.surfaceColor
                    border.color: root.selectedIndex === index || modelData.current ? modelData.accent : root.theme.borderColor
                    Row {
                        anchors.fill: parent; anchors.margins: 10; spacing: 9
                        Canvas {
                            width: 30; height: 30; anchors.verticalCenter: parent.verticalCenter
                            property color coreColor: modelData.accent
                            property color edgeColor: modelData.secondary
                            onCoreColorChanged: requestPaint()
                            onEdgeColorChanged: requestPaint()
                            onPaint: {
                                var c = getContext("2d"); c.reset(); var m = width / 2
                                var glow = c.createRadialGradient(m, m, 1, m, m, m)
                                glow.addColorStop(0, Qt.lighter(coreColor, 2.2)); glow.addColorStop(0.35, coreColor); glow.addColorStop(0.72, edgeColor); glow.addColorStop(1, "transparent")
                                c.fillStyle = glow; c.fillRect(0, 0, width, height)
                            }
                        }
                        Column {
                            width: parent.width - 39; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                            Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText; text: modelData.name; color: root.theme.foregroundColor; font.family: Style.font.menuFamily; font.pixelSize: 11; font.bold: true }
                            Text { text: modelData.current ? "ACTIVE" : modelData.backgroundCount + " BACKGROUNDS"; color: modelData.current ? modelData.accent : root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 9; font.bold: true }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = index
                        onClicked: root.source.applyTheme(modelData.name)
                    }
                }
            }
        }

        Text {
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: "[ R ] RETURN TO ORBIT  ·  [ ENTER ] APPLY STAR  ·  [ B ] CYCLE BACKGROUND  ·  [ ESC ] RELEASE FOCUS"
            color: root.theme.faintTextColor; font.family: Style.font.menuFamily; font.pixelSize: 11; font.letterSpacing: 0.9
        }
    }
}
