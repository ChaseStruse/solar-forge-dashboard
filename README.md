# Solar Forge Dashboard

A native Omarchy dashboard with a cyberpunk command-center aesthetic.

## Current features

- Live date and time
- Full-width Objectives Command Center with active, closed, reminder, and total telemetry; add tasks with `Enter` and click to complete
- Full-width GitHub Command Center with profile telemetry, prioritized developer actions, and recent repository pulse
- Bar-launcher icon placed in the center section immediately after weather on first enable
- Fullscreen command deck: opens as a Hyprland fullscreen window (still closable with the compositor shortcut) with a telemetry rail, live syslog stream, and command line around the forge
- Colors automatically follow the active Omarchy theme
- Orbiting app picker with shaded planets, hover pause, and keyboard controls
- Mission Control with outstanding tasks, upcoming reminders, recent GitHub activity, and live Omarchy weather
- Optional `SUPER + ALT + D` dashboard keybinding, enabled explicitly from the dashboard
- Theme Reactor for live theme selection, palette-star previews, background cycling, and wallpaper telemetry
- Persistent System Readiness Ring for resources, power, updates, and radio state, with load-proportional arcs and attention-only warning highlights
- Reactive forge core: the sun shifts from accent toward urgent, breathes faster, and spins hotter as CPU/GPU load and warnings rise, firing flare shockwaves for each active warning
- HUD chassis: every module renders inside a clipped-corner frame with corner brackets, ruler ticks, a designation tag, and a slow scan sweep
- Terminal ignition sequence on first open: diagnostics type in and resolve to `[ OK ]`, an ignition bar charges, the wordmark decodes, and the planets fly out to orbit; replay with `boot`
- Live telemetry rail with CPU, memory, and GPU sparklines, segmented storage and power bars, and uplink, profile, update, uptime, and host readouts
- Syslog stream that types out forge events (heat changes, warnings, GitHub sync, theme and flight-mode changes, navigation) plus a periodic core heartbeat
- Glitch, decode, and CRT power-on animations when modules open or the theme changes
- Native Flight Modes that coordinate Omarchy power, idle, notification, and nightlight state
- Workspace Radar maps active Hyprland workspaces to planets and their windows to draggable moons, with inferred roles, load/fullscreen telemetry, focus glow, urgent distress pulses, and direct focus/move/close operations
- Mission Timer bridges objectives into Omarchy reminders with focus presets, inbound-transmission telemetry, cancellation, and completion synchronization after expiry

## Launching

The dashboard fills the screen. Press `:` (or `/`) anywhere outside a text
field to drop into the command line at the bottom; `Escape` returns to the
core. Commands:

| Command | Effect |
| --- | --- |
| `help` | List commands in the syslog |
| `open <module>` or `t` `g` `m` `f` `w` `r` | Jump to a module |
| `close` | Return to the core |
| `todo <text>` | Queue an objective |
| `theme <name>` / `themes` | Engage a theme (partial names match) / list themes |
| `mode <focus\|forge\|drift\|broadcast>` | Engage a flight mode |
| `status`, `refresh`, `boot` | Print telemetry, resync every source, replay ignition |
| `shortcut` | Toggle the `SUPER + ALT + D` keybinding |
| `clear`, `exit` | Wipe the syslog, close the dashboard |

Up/Down recall command history.

Enable the plugin and use the sun icon in the center section of the Omarchy bar,
immediately to the right of the weather widget in the standard layout.
The dashboard opens as a regular window, so it participates in your usual
Hyprland tiling layout.

The bar icon works without changing your Hyprland configuration. To add the
optional `SUPER + ALT + D` shortcut, open the dashboard and run the `shortcut`
command. Solar Forge first checks the active bindings and will
not replace an existing shortcut. The same command removes only the clearly
marked Solar Forge entry. Use either the shortcut or the sun icon to toggle the
dashboard after enabling it.

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
focus to the orbital picker. On wide windows the forge stays docked to the left
of the open module as a miniature navigator, with an energy conduit routed from
the selected planet into the panel; click any planet or index entry to switch
modules. Narrow windows swap the forge out for the panel instead. Planet icons use
Omarchy's JetBrainsMono Nerd Font. Animation pauses on hover and while closed.

## GitHub setup

Solar Forge reads action signals through the locally installed GitHub CLI (`gh`). Authenticate it once with `gh auth login`; the dashboard never stores a GitHub token. It prioritizes failed checks on your pull requests, review requests, merge-ready or blocked pull requests, relevant unread notifications, and assigned issues. The full-width Command Center also shows followers, stars earned across owned repositories, owned repository count, following, yearly contributions, open pull requests, and recently active repositories.

Open the GitHub planet with `G`, use Arrow keys or `H/J/K/L` to select an item,
press Enter or Space to open it on GitHub, and press `F5` to refresh. The planet
badge shows the total number of items needing attention. If `gh` is unavailable
or signed out, the panel shows an actionable authentication status.

## Install

Solar Forge requires Omarchy with the Quattro shell and a working Quickshell
installation. Install and enable the plugin directly from its public repository:

```bash
omarchy plugin add https://github.com/ChaseStruse/solar-forge-dashboard.git --enable
```

Restart the shell if the bar does not refresh immediately:

```bash
omarchy-shell restart
```

## Requirements and capabilities

The core dashboard uses commands normally provided by Omarchy and its Arch
Linux environment, including Bash, `jq`, `curl`, Hyprland tools, and
`systemctl --user`. The GitHub Command Center additionally requires the GitHub
CLI (`gh`) and a locally authenticated account. The keybinding helper uses
`rg`. No command is run with `sudo` or `pkexec`.

Solar Forge reads local system, workspace, theme, reminder, and weather state.
Weather requests use `wttr.in`; GitHub data is requested through your local
`gh` authentication. Tasks are stored locally through Qt's SQLite storage. The
plugin only changes themes, backgrounds, flight-mode settings, reminders,
workspace windows, or the optional shortcut after a corresponding user action.

## Remove

If you enabled the optional shortcut, remove it first with the dashboard's `shortcut`
command or run:

```bash
bash "$HOME/.config/omarchy/plugins/io.github.chasestruse.solar-forge-dashboard/scripts/install-keybinding.sh" --remove
```

Then remove the plugin:

```bash
omarchy plugin remove io.github.chasestruse.solar-forge-dashboard
```

## Code structure

- `BarWidget.qml`: launcher and the lifecycle methods Omarchy calls.
- `Dashboard.qml`: window, page layout, and section composition.
- `DashboardTheme.qml`: live Omarchy theme bindings shared by all sections.
- `TodoStore.qml`: SQLite access, task model, active/closed/total telemetry, and storage errors.
- `TodoSection.qml`: full-width objective queue, telemetry, reminder controls, and inbound transmissions.
- `GitHubSource.qml`: shared action prioritization, timeout, response validation, and status.
- `GitHubSection.qml`: keyboard-accessible action inbox and repository fallback.
- `scripts/github-intelligence.sh`: bounded GitHub GraphQL and notification collection.
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
input, a 50-task six-row viewport, objective telemetry, GitHub action prioritization and malformed responses, and repeatable
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
