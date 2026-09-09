# Solar Forge Dashboard

A native Omarchy dashboard with a cyberpunk command-center aesthetic.

## Current features

- Personalized greeting from the local user account
- Live date and time
- Local persistent to-do list: add tasks with `Enter`, click to complete
- Up to four recently updated GitHub repositories
- Fullscreen Omarchy overlay, dismissible with `Escape`

## GitHub setup

Solar Forge reads repository metadata through the locally installed GitHub CLI (`gh`). Authenticate it once with `gh auth login`; the dashboard never stores a GitHub token. If `gh` is unavailable or signed out, the GitHub panel shows an actionable offline status.

## Roadmap

- Today’s tasks and calendar brief
- Recent GitHub projects
- Local `llama.cpp` chat console

## License

MIT
