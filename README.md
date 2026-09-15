# Solar Forge Dashboard

A native Omarchy dashboard with a cyberpunk command-center aesthetic.

## Current features

- Live date and time
- Local persistent to-do list: add tasks with `Enter`, click to complete; three visible rows with scrolling
- Up to four GitHub repositories returned by `gh repo list`
- Bar-launcher icon placed in the center section immediately after weather on first enable
- Normal desktop window that Hyprland can tile and close with the compositor shortcut or title-bar control
- Colors automatically follow the active Omarchy theme
- Orbiting app picker with shaded planets, hover pause, and keyboard controls
- Mission Control with outstanding tasks, upcoming reminders, recent GitHub activity, and live Omarchy weather
- Automatic `SUPER + ALT + D` dashboard keybinding when that combination is available
- Theme Reactor for live theme selection, palette-star previews, background cycling, and wallpaper telemetry
- Persistent System Readiness Ring for resources, power, updates, and radio state with attention-only warning arcs
- Replayable startup briefing with live CPU, GPU, memory, disk, uptime, weather, GitHub, and objective status
- Native Flight Modes that coordinate Omarchy power, idle, notification, and nightlight state
- Workspace Radar maps active Hyprland workspaces to planets and their windows to draggable moons, with inferred roles, load/fullscreen telemetry, focus glow, urgent distress pulses, and direct focus/move/close operations
- Mission Timer bridges objectives into Omarchy reminders with focus presets, inbound-transmission telemetry, cancellation, and completion synchronization after expiry

## Launching

Enable the plugin and use the sun icon in the center section of the Omarchy bar,
immediately to the right of the weather widget in the standard layout.
The dashboard opens as a regular window, so it participates in your usual
Hyprland tiling layout.

On first load, the plugin checks Hyprland's active bindings. If
`SUPER + ALT + D` is free, it adds a clearly marked Solar Forge entry to
`~/.config/hypr/bindings.lua`; if the shortcut is already in use, it leaves the
configuration unchanged. The installer is idempotent, so shell reloads never
duplicate the entry. Use either the shortcut or the sun icon to toggle the
dashboard.

Theme Reactor takes keyboard focus as soon as it opens. Use Arrow keys or
`H/J/K/L` to navigate stars, Tab/Shift+Tab to step through them, Page Up/Page
Down to jump rows, Home to return to the active theme, End to jump to the last
theme, Enter or Space to apply, `B` to cycle the background, `F5` to rescan,
and `R` or Escape to return to orbit.

The dashboard opens with all panels hidden. While the core has focus, press
`T` for Objectives, `G` for GitHub, `M` for the mission timeline, `F` for Flight Modes, `W` for Workspace Radar, or `R` for Theme Reactor; press the same key to hide the panel.
Arrow keys and Tab cycle modules, Enter focuses the selected panel, and
Ctrl+Space returns to the core. Clicking a planet toggles its panel;
double-clicking focuses it. Escape minimizes the active module and returns
focus to the orbital picker. Planet icons use
Omarchy's JetBrainsMono Nerd Font. Animation pauses on hover and while closed.

## GitHub setup

Solar Forge reads repository metadata through the locally installed GitHub CLI (`gh`). Authenticate it once with `gh auth login`; the dashboard never stores a GitHub token. If `gh` is unavailable or signed out, the GitHub panel shows an actionable offline status.

## Code structure

- `BarWidget.qml`: launcher and the lifecycle methods Omarchy calls.
- `Dashboard.qml`: window, page layout, and section composition.
- `DashboardTheme.qml`: live Omarchy theme bindings shared by all sections.
- `TodoStore.qml`: SQLite access, task model, active count, and storage errors.
- `TodoSection.qml`: task input and the virtualized three-row list.
- `GitHubSource.qml`: CLI requests, timeout, response validation, and status.
- `GitHubSection.qml`: repository presentation.
- `ForgeCore.qml`: orbital rendering, animation lifecycle, and module controls.
- `MissionControlSource.qml`: GitHub activity and Omarchy weather requests.
- `MissionTimeline.qml`: the live GitHub and weather command surface.
- `TimelineLane.qml`: shared timeline presentation for source events.
- `SystemBriefingSource.qml`: local system-health collection and recommendations.
- `SystemBriefing.qml`: the cinematic startup and replay briefing.
- `FlightModesSource.qml`: Omarchy state discovery and coordinated mode commands.
- `FlightModesSection.qml`: mode selection, live state, and keyboard controls.
- `WorkspaceRadarSource.qml`: Hyprland workspace/window discovery and focus actions.
- `WorkspaceRadar.qml`: orbital workspace topology and pointer interactions.
- `ReminderBridgeSource.qml`: Omarchy reminder scheduling, discovery, cancellation, and objective linkage.
- `ThemeReactorSource.qml`: installed-theme discovery and supported Omarchy theme/background actions.
- `ThemeReactorSection.qml`: stellar theme picker and holographic wallpaper preview.
- `SystemReadinessSource.qml`: lightweight persistent resource, power, update, and connectivity telemetry.
- `ReadinessRing.qml`: calm core telemetry with warning arcs only for actionable states.

Sections receive typed data/theme dependencies. Add future features as a source
and a section, composed in Dashboard. Keep SQL and subprocesses out of views.
The bar reads the dashboard's open state; close handlers must not call back into
`shell.hide()`. Theme values stay as bindings, so theme changes propagate.

The SQLite database name/version and existing schema are preserved. Introduce
explicit, tested migrations before changing the schema. Writes use bound SQL
parameters and clear the input only after a successful commit. Failed reads
retain the last loaded model; failed writes show an error.

## Development checks

Run on a machine with Omarchy, Quickshell, and Qt installed:

```bash
omarchy plugin validate .
bash tests/run.sh
git diff --check
```

The offscreen regression harness tests task persistence/counts/sorting, blank
input, a 50-task three-row viewport, malformed GitHub responses, and repeatable
close/reopen state, module selection, and animation pause/resume. It uses a fresh database under /tmp and makes no GitHub
requests. Temporary test output is retained at the path printed by the runner.

For live verification, reload the installed plugin with
`omarchy-shell shell rescanPlugins`, open/close it from the bar, test Escape
while typing returns focus to the core, and check a short tiled window and the scrollbar. The offscreen
checks do not replace compositor or pointer/keyboard interaction checks.

## Recommended next steps

- Add keyboard navigation and accessible names to task controls.
- If supporting multiple monitors, move task state and GitHub caching into a
  shared service so separate bar instances stay synchronized while open.
- Add an explicit archive/delete policy for completed tasks before the database
  becomes large; the list virtualizes rows, but storage still loads all tasks.
- Set up CI with a matching Omarchy/Qt runtime to run the regression harness.

## Roadmap

- Calendar brief
- Local `llama.cpp` chat console

## License

MIT
