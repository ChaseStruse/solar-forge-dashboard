# Solar Forge Dashboard

A native Omarchy dashboard with a cyberpunk command-center aesthetic.

## Current features

A fullscreen, terminal-style command deck built around a living solar forge:

- **Forge core:** the sun shifts from accent toward urgent, breathes faster, and spins hotter as CPU/GPU load and warnings rise, firing flare shockwaves for each active warning. Seven module planets orbit it and show their state: progress halos, badges, and red distress pulses.
- **Fullscreen deck:** opens as a Hyprland fullscreen window with a telemetry rail (sparklines, storage and power bars, host readouts), a live syslog stream, weather and a seconds clock in the top bar, and a command line along the bottom.
- **Animation:** a terminal ignition sequence on first open, planets flying out to orbit, CRT power-on for modules, glitch slices on theme changes, a launch beam when an app starts, and a CRT power-off on exit. Optional sound effects use the freedesktop sound theme.
- Colors follow the active Omarchy theme. The optional `SUPER + ALT + D` keybinding is enabled from inside the dashboard.

### Modules

| Key | Module | What it does |
| --- | --- | --- |
| `T` | Objectives | Local task queue with completion telemetry; the bell links an Omarchy reminder to a task |
| `G` | GitHub Intel | Failed checks, review requests, and merge-ready work ranked, plus profile and repository pulse |
| `L` / `Space` | Launch Control | Fuzzy-search installed apps like `SUPER + SPACE`; Tab switches to running windows (Enter focuses, Shift+Delete closes) |
| `R` | Reactor | CPU package and per-core heat map, GPU temperature and draw, fans, power profiles, and Flight Modes |
| `C` | Comms Array | Wi-Fi networks, paired Bluetooth devices, and audio outputs; Enter joins, connects, or routes |
| `D` | Supply Depot | Pending repo and AUR updates, Omarchy release state, and a one-key full update in a floating terminal |
| `K` | Keybind Codex | Every described Hyprland binding, searchable as you type |

## Controls

The dashboard fills the screen and opens on the forge. From the core:

- `T G L R C D K` toggle modules; arrow keys and Tab cycle them; Enter focuses the selected one.
- `Space` opens the launcher directly.
- `:` or `/` drops into the command line; `Escape` returns to the core.
- `Escape` twice at the core powers the deck down.

On wide screens the forge docks beside the open module as a navigator, linked to
it by an energy conduit. Clicking a planet toggles its module; double-clicking
focuses it.

### Commands

| Command | Effect |
| --- | --- |
| `help` | List commands in the syslog |
| `open <module>` or `t g l r c d k` | Jump to a module |
| `run <app>` | Launch the best-matching application |
| `todo <text>` | Queue an objective |
| `focus <minutes>` | Engage Focus mode and arm an Omarchy reminder |
| `keys <search>` | Search keybindings in the Codex |
| `update` | Run a full `omarchy update` in a floating terminal |
| `lock`, `screenshot [region\|windows\|fullscreen]` | Lock the screen or take a screenshot (the deck closes first) |
| `wallpaper next`, `nightlight` | Cycle the background, toggle nightlight |
| `theme <name>` / `themes` | Engage a theme (partial names match) / list themes |
| `mode <focus\|forge\|drift\|broadcast>` | Engage a flight mode |
| `profile <power-saver\|balanced\|performance>` | Set the power profile |
| `wifi <on\|off>`, `bt <on\|off\|toggle>`, `volume <+N\|-N\|mute-toggle>` | Radio and audio control |
| `status`, `refresh`, `boot` | Print telemetry, resync every source, replay ignition |
| `sfx <on\|off>` | Toggle sound effects (remembered between sessions) |
| `shortcut` | Toggle the `SUPER + ALT + D` keybinding |
| `clear`, `exit` | Wipe the syslog, power the deck down |

Tab completes commands and their arguments (including app and theme names);
Up/Down recall history.

### Launching

Enable the plugin and use the sun icon in the center section of the Omarchy bar,
immediately to the right of the weather widget in the standard layout.

The bar icon works without changing your Hyprland configuration. To add the
optional `SUPER + ALT + D` shortcut, open the dashboard and run the `shortcut`
command. Solar Forge first checks the active bindings and will
not replace an existing shortcut. The same command removes only the clearly
marked Solar Forge entry.

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

Restart the shell after installing or updating:

```bash
omarchy restart shell
```

## Requirements and capabilities

The core dashboard uses commands normally provided by Omarchy and its Arch
Linux environment, including Bash, `jq`, `curl`, Hyprland tools, and
`systemctl --user`. The Reactor, Comms, and Depot modules use `sensors`,
`nvidia-smi` (when present), `powerprofilesctl`, `nmcli`, `bluetoothctl`,
`pactl`, `checkupdates`, and `yay`. The GitHub module additionally requires the GitHub
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
- `Dashboard.qml`: fullscreen window, layout, module composition, planet telemetry, and the command interpreter.
- `DashboardTheme.qml`: live Omarchy theme bindings plus type, spacing, and HUD tokens.
- `ForgeCore.qml`: orbital rendering, heat-reactive sun, planet state rings, ignition, and module navigation.
- `ReadinessRing.qml`: value-proportional resource arcs and readouts around the sun.
- HUD kit: `HudFrame.qml`, `PanelHeader.qml`, `StatTile.qml`, `HudButton.qml`, `HudRow.qml`, `DecodeText.qml`.
- Deck chrome: `TelemetryRail.qml`, `SystemLog.qml`, `CommandLine.qml` (with completion), `BootSequence.qml`, `Starfield.qml`, `AmbientLayer.qml`.
- `ScriptSource.qml`: runs a bundled JSON script and follow-up actions; backs Reactor, Comms, Depot, and Codex.
- Objectives: `TodoStore.qml` (SQLite), `TodoSection.qml`, `ReminderBridgeSource.qml`.
- GitHub: `GitHubSource.qml`, `GitHubSection.qml`, `scripts/github-intelligence.sh`.
- Launch Control: `LauncherSection.qml` (Quickshell `DesktopEntries`, launched via `uwsm-app -- gtk-launch`) and `WorkspaceRadarSource.qml` (running windows, focus/close).
- Reactor: `ReactorSection.qml`, `scripts/reactor-state.sh`, `FlightModesSource.qml`, `FlightModesSection.qml`.
- Comms: `CommsSection.qml`, `scripts/comms-state.sh`. Depot: `DepotSection.qml`, `scripts/depot-state.sh`. Codex: `CodexSection.qml`, `scripts/codex-state.sh`.
- Background sources: `SystemReadinessSource.qml`, `SystemBriefingSource.qml`, `MissionControlSource.qml` (weather), `ThemeReactorSource.qml` (themes for the `theme` command).

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
