import QtQuick
import qs.Commons

QtObject {
    // Omarchy's Color singleton reloads these bindings whenever the desktop
    // theme changes, keeping the dashboard aligned with the active palette.
    readonly property color backgroundColor: Color.popups.background
    readonly property color foregroundColor: Color.popups.text
    readonly property color accentColor: Color.accent
    readonly property color urgentColor: Color.urgent
    readonly property color surfaceColor: Util.alpha(Color.popups.text, 0.08)
    readonly property color completedSurfaceColor: Util.alpha(Color.popups.text, 0.04)
    readonly property color borderColor: Util.alpha(Color.popups.border, 0.48)
    readonly property color dimmedTextColor: Util.alpha(Color.popups.text, 0.62)
    readonly property color faintTextColor: Util.alpha(Color.popups.text, 0.45)
}
