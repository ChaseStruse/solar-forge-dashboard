import QtQuick
import qs.Commons

// Fullscreen terminal ignition. Diagnostic lines type in and resolve to
// [ OK ], an ignition bar charges, the title decodes, then a flash hands
// over to the forge. Any key or click skips.
Rectangle {
    id: root
    required property DashboardTheme theme
    required property SystemBriefingSource source
    required property MissionControlSource missionSource
    required property SystemReadinessSource readiness
    required property int objectiveCount
    property string hostLine: ""
    signal finished()

    property int revealed: 0
    property real charge: 0
    property bool titled: false
    visible: false
    focus: visible
    color: theme.backgroundColor
    z: 100

    // Lines are resolved when revealed, so late-arriving data still lands.
    function lineAt(i) {
        var hour = new Date().getHours();
        var greet = hour < 12 ? "GOOD MORNING" : hour < 18 ? "GOOD AFTERNOON" : "GOOD EVENING";
        switch (i) {
        case 0: return ["BIOS", "SOLAR FORGE FIRMWARE 3000.0 // " + (hostLine || "OMARCHY")];
        case 1: return ["CORE", "CPU LOAD " + source.cpuLoad + "  ·  FLUX " + (readiness.cpuPercent < 0 ? "—" : readiness.cpuPercent + "%")];
        case 2: return ["MEM", "LATTICE " + source.memory];
        case 3: return ["GPU", source.gpu + (source.gpuDetail ? "  ·  " + source.gpuDetail : "")];
        case 4: return ["DISK", "VAULT " + source.disk];
        case 5: return ["LINK", readiness.networkOnline ? "UPLINK " + readiness.networkName : "UPLINK OFFLINE"];
        case 6: return ["SAT", "6 SATELLITES IN ORBIT  ·  " + missionSource.repositories.length + " REPOSITORIES SYNCED"];
        case 7: return ["OBJ", objectiveCount + " ACTIVE OBJECTIVES IN QUEUE"];
        case 8: return ["WX", missionSource.weatherCondition === "—" ? "ATMOSPHERICS UNAVAILABLE"
                                : (missionSource.weatherCondition + " IN " + missionSource.weatherLocation + "  ·  " + missionSource.weatherValue).toUpperCase()];
        case 9: return ["ADV", source.recommendation.toUpperCase()];
        case 10: return ["SYS", greet + ", PILOT. UPTIME " + String(source.uptime).toUpperCase()];
        }
        return ["", ""];
    }
    readonly property int lineCount: 11

    function play() {
        revealed = 0;
        charge = 0;
        titled = false;
        flash.opacity = 0;
        content.opacity = 1;
        visible = true;
        sequence.restart();
        Qt.callLater(function() { root.forceActiveFocus(); });
    }
    function skip() {
        if (!visible)
            return;
        sequence.stop();
        outro.restart();
    }
    function done() {
        visible = false;
        finished();
    }

    Keys.onPressed: function(event) { root.skip(); event.accepted = true; }
    MouseArea { anchors.fill: parent; onClicked: root.skip() }

    SequentialAnimation {
        id: sequence
        PauseAnimation { duration: 250 }
        NumberAnimation { target: root; property: "revealed"; from: 0; to: root.lineCount; duration: root.lineCount * 190 }
        PauseAnimation { duration: 200 }
        NumberAnimation { target: root; property: "charge"; from: 0; to: 1; duration: 900; easing.type: Easing.InOutQuad }
        ScriptAction { script: root.titled = true }
        PauseAnimation { duration: 900 }
        ScriptAction { script: outro.restart() }
    }
    SequentialAnimation {
        id: outro
        NumberAnimation { target: flash; property: "opacity"; to: 0.85; duration: 90 }
        ScriptAction { script: content.opacity = 0 }
        NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 520; easing.type: Easing.OutCubic }
        ScriptAction { script: root.done() }
    }

    Item {
        id: content
        anchors.fill: parent

        Column {
            id: log
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Math.max(48, parent.width * 0.08)
            anchors.topMargin: Math.max(48, parent.height * 0.1)
            width: Math.min(parent.width * 0.7, 1100)
            spacing: 9
            Repeater {
                model: root.lineCount
                Row {
                    id: bootLine
                    required property int index
                    readonly property var parts: root.lineAt(index)
                    visible: index < root.revealed
                    spacing: 14
                    Text {
                        text: "[" + (bootLine.index < root.revealed - 1 || root.charge > 0 ? "  OK  " : " .... ") + "]"
                        color: bootLine.index < root.revealed - 1 || root.charge > 0 ? root.theme.secondaryAccentColor : root.theme.faintTextColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: root.theme.fontBody + 2
                        font.bold: true
                    }
                    Text {
                        width: 54
                        text: bootLine.parts[0]
                        color: root.theme.accentColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: root.theme.fontBody + 2
                        font.bold: true
                    }
                    DecodeText {
                        source: bootLine.visible ? bootLine.parts[1] : ""
                        steps: 10
                        color: root.theme.foregroundColor
                        font.family: Style.font.menuFamily
                        font.pixelSize: root.theme.fontBody + 2
                    }
                }
            }
        }

        Column {
            anchors.left: log.left
            anchors.top: log.bottom
            anchors.topMargin: 36
            spacing: 10
            visible: root.revealed >= root.lineCount
            Text {
                text: "IGNITION  " + Math.round(root.charge * 100) + "%"
                color: root.theme.accentColor
                font.family: Style.font.menuFamily
                font.pixelSize: root.theme.fontBody + 2
                font.bold: true
                font.letterSpacing: 2
            }
            Row {
                spacing: 3
                Repeater {
                    model: 48
                    Rectangle {
                        required property int index
                        width: 12
                        height: 14
                        color: index < Math.round(root.charge * 48)
                            ? root.theme.mix(root.theme.accentColor, root.theme.urgentColor, index / 60)
                            : Util.alpha(root.theme.foregroundColor, 0.08)
                    }
                }
            }
        }

        // Decoding title with an RGB-split ghost.
        Item {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: Math.max(48, parent.width * 0.06)
            anchors.bottomMargin: Math.max(48, parent.height * 0.08)
            width: title.implicitWidth
            height: title.implicitHeight + subtitle.implicitHeight
            visible: root.titled
            DecodeText {
                x: 3
                source: root.titled ? "SOLAR FORGE" : ""
                color: Util.alpha(root.theme.urgentColor, 0.6)
                font: title.font
            }
            DecodeText {
                x: -3
                source: root.titled ? "SOLAR FORGE" : ""
                color: Util.alpha(root.theme.accentColor, 0.6)
                font: title.font
            }
            DecodeText {
                id: title
                source: root.titled ? "SOLAR FORGE" : ""
                color: root.theme.foregroundColor
                font.family: Style.font.menuFamily
                font.pixelSize: Math.max(56, root.height * 0.08)
                font.bold: true
                font.letterSpacing: 8
            }
            Text {
                id: subtitle
                anchors.top: title.bottom
                anchors.right: title.right
                text: "PERSONAL COMMAND CENTER  //  CORE ONLINE"
                color: root.theme.accentColor
                font.family: Style.font.menuFamily
                font.pixelSize: root.theme.fontBody
                font.letterSpacing: 4
            }
        }

        Text {
            anchors.bottom: parent.bottom
            anchors.left: log.left
            anchors.bottomMargin: 36
            text: "ANY KEY  ·  SKIP"
            color: root.theme.faintTextColor
            font.family: Style.font.menuFamily
            font.pixelSize: root.theme.fontMicro
            font.letterSpacing: 2
        }
    }

    Rectangle {
        id: flash
        anchors.fill: parent
        color: Qt.lighter(root.theme.accentColor, 1.6)
        opacity: 0
    }
}
