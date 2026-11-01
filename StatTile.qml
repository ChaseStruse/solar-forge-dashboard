import QtQuick
import qs.Commons

// Notched readout tile: big value over a spaced caption, with a corner tick.
Item {
    id: root
    required property DashboardTheme theme
    property string value: "—"
    property string label: ""
    property color tone: theme.accentColor
    implicitWidth: 150
    implicitHeight: 76

    Canvas {
        anchors.fill: parent
        property color ink: root.tone
        onInkChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var c = getContext("2d");
            c.reset();
            var n = 10, w = width - 0.5, h = height - 0.5;
            c.beginPath();
            c.moveTo(0.5, 0.5); c.lineTo(w - n, 0.5); c.lineTo(w, n); c.lineTo(w, h); c.lineTo(0.5, h); c.closePath();
            c.fillStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.07);
            c.fill();
            c.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.4);
            c.lineWidth = 1;
            c.stroke();
            c.fillStyle = Qt.rgba(ink.r, ink.g, ink.b, 0.9);
            c.fillRect(0, 0, 3, height);
        }
    }
    Column {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 24
        spacing: 3
        DecodeText {
            width: parent.width
            elide: Text.ElideRight
            source: root.value
            steps: 10
            color: root.tone
            font.family: Style.font.menuFamily
            font.pixelSize: 24
            font.bold: true
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.label
            color: root.theme.dimmedTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontMicro
            font.bold: true
            font.letterSpacing: 1.6
        }
    }
}
