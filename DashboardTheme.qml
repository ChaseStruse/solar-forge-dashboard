import QtQuick
import qs.Commons

QtObject {
    // Omarchy's Color singleton reloads these bindings whenever the desktop
    // theme changes, keeping the dashboard aligned with the active palette.
    readonly property color backgroundColor: Color.popups.background
    readonly property color foregroundColor: Color.popups.text
    readonly property color accentColor: Color.accent
    readonly property color secondaryAccentColor: Color.bar.active
    readonly property color urgentColor: Color.urgent
    readonly property color surfaceColor: Util.alpha(Color.popups.text, 0.08)
    readonly property color completedSurfaceColor: Util.alpha(Color.popups.text, 0.04)
    readonly property color borderColor: Util.alpha(Color.popups.border, 0.48)
    readonly property color dimmedTextColor: Util.alpha(Color.popups.text, 0.62)
    readonly property color faintTextColor: Util.alpha(Color.popups.text, 0.45)

    // Type scale. Nothing renders below fontMicro so telemetry stays legible.
    readonly property int fontMicro: 11
    readonly property int fontSmall: 12
    readonly property int fontBody: 13
    readonly property int fontTitle: 17
    readonly property int fontDisplay: 28

    // Spacing scale.
    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 12
    readonly property int spaceLg: 20
    readonly property int spaceXl: 28

    // HUD geometry: clipped corners instead of rounded ones.
    readonly property int notch: 16
    readonly property int bracket: 22
    readonly property real glowAlpha: 0.22

    function mix(from, to, amount) {
        var t = Math.max(0, Math.min(1, amount));
        return Qt.rgba(from.r + (to.r - from.r) * t,
                       from.g + (to.g - from.g) * t,
                       from.b + (to.b - from.b) * t,
                       from.a + (to.a - from.a) * t);
    }
}
