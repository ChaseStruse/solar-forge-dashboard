import QtQuick

// Text that "decrypts" into place: whenever `source` changes, unrevealed
// characters cycle through noise glyphs and lock in from left to right.
Text {
    id: root
    property string source: ""
    property int steps: 16
    property int interval: 28
    property int progress: steps
    readonly property string noise: "▓▒░<>/\\|_=+*#01ABCDEF"

    function decode() {
        progress = 0;
        ticker.restart();
    }
    function render() {
        if (progress >= steps)
            return source;
        var reveal = Math.floor(source.length * progress / steps);
        var out = source.substring(0, reveal);
        for (var i = reveal; i < source.length; i++) {
            var ch = source.charAt(i);
            out += ch === " " ? " " : noise.charAt(Math.floor(Math.random() * noise.length));
        }
        return out;
    }

    text: render()
    onSourceChanged: decode()
    Component.onCompleted: decode()

    Timer {
        id: ticker
        interval: root.interval
        repeat: true
        onTriggered: {
            root.progress++;
            root.text = root.render();
            if (root.progress >= root.steps)
                stop();
        }
    }
}
