import QtQuick

// Full-window parallax starfield. Each layer is a static set of dots (drawn
// twice, stacked) inside a container the scene graph scrolls, so drift costs
// one transform per layer.
Item {
    id: root
    required property DashboardTheme theme
    property bool running: true
    clip: true

    Repeater {
        model: [
            { count: 90, size: 1, alpha: 0.35, duration: 260000, seed: 7 },
            { count: 40, size: 2, alpha: 0.5, duration: 150000, seed: 19 },
            { count: 14, size: 3, alpha: 0.75, duration: 85000, seed: 41 }
        ]
        Item {
            id: starLayer
            required property var modelData
            width: root.width
            height: root.height * 2
            readonly property var stars: {
                if (!modelData)
                    return [];
                var seed = modelData.seed, out = [];
                function rand() {
                    seed = (seed * 16807) % 2147483647;
                    return seed / 2147483647;
                }
                for (var i = 0; i < modelData.count; i++)
                    out.push({ x: rand(), y: rand(), a: 0.4 + rand() * 0.6, tinted: i % 7 === 0 });
                return out;
            }
            Repeater {
                model: starLayer.stars.length * 2
                Rectangle {
                    required property int index
                    // Guards cover the instant before/after the layer's config binds.
                    readonly property var cfg: starLayer.modelData || ({ size: 1, alpha: 0 })
                    readonly property var star: starLayer.stars[index % Math.max(1, starLayer.stars.length)] || ({ x: 0, y: 0, a: 0, tinted: false })
                    width: cfg.size
                    height: width
                    radius: width / 2
                    x: star.x * root.width
                    y: star.y * root.height + (index >= starLayer.stars.length ? root.height : 0)
                    color: star.tinted ? root.theme.accentColor : root.theme.foregroundColor
                    opacity: cfg.alpha * star.a
                }
            }
            NumberAnimation on y {
                id: drift
                from: -root.height
                to: 0
                duration: starLayer.modelData ? starLayer.modelData.duration : 100000
                loops: Animation.Infinite
                running: root.running && root.height > 0
            }
            Connections {
                target: root
                function onHeightChanged() { if (drift.running) drift.restart(); }
            }
        }
    }
}
