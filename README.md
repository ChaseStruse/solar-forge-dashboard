# Solar Forge Dashboard

A native Omarchy dashboard with a cyberpunk command-center aesthetic.

## Current features

- Personalized greeting from the local user account
- Live date and time
- Local persistent to-do list: add tasks with `Enter`, click to complete
- Up to four recently updated GitHub repositories
- Bar-launcher icon for the dashboard
- Normal desktop window that Hyprland can tile, dismissible with `Escape` or its title-bar close button
- Colors automatically follow the active Omarchy theme

## Launching

Enable the plugin and use the sun icon in the left section of the Omarchy bar.
The dashboard opens as a regular window, so it participates in your usual
Hyprland tiling layout.

## GitHub setup

Solar Forge reads repository metadata through the locally installed GitHub CLI (`gh`). Authenticate it once with `gh auth login`; the dashboard never stores a GitHub token. If `gh` is unavailable or signed out, the GitHub panel shows an actionable offline status.

## Roadmap

- Today’s tasks and calendar brief
- Recent GitHub projects
- Local `llama.cpp` chat console

## License

MIT
