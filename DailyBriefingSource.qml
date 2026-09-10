import QtQuick
import Quickshell

// Briefing values are explicit local inputs; this source never sends location
// or energy data to an external service.
QtObject {
    readonly property real generationKwh: Number(Quickshell.env("SOLAR_FORGE_DAILY_GENERATION_KWH"))
    readonly property real savingsUsd: Number(Quickshell.env("SOLAR_FORGE_DAILY_SAVINGS_USD"))
    readonly property string forecast: Quickshell.env("SOLAR_FORGE_FORECAST") || "FORECAST LINK REQUIRED"
    readonly property string recommendation: Quickshell.env("SOLAR_FORGE_RECOMMENDATION") || "LINK A FORECAST SOURCE TO RECEIVE A DAILY ENERGY RECOMMENDATION."
    readonly property string generation: isFinite(generationKwh) ? generationKwh.toFixed(1) + " kWh" : "ENERGY LINK REQUIRED"
    readonly property string savings: isFinite(savingsUsd) ? "$" + savingsUsd.toFixed(2) : "RATE LINK REQUIRED"

    function refresh() {
        // Environment values are fixed for the active shell session.
    }
}
