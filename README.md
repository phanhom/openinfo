# openinfo

A minimal macOS menu bar + floating desktop widget that shows NBA live scores — always visible, never in the way.

---

## What it does

- **Menu bar** — live score ticker for the current game, updates in real time. Multiple games? Use ▲▼ to flip between them.
- **Floating window** — always-on-top overlay showing all today's games at a glance. Stays visible across all Spaces and even over full-screen apps.

---

## Preview

```
┌─────────────────────────────┐
│  openinfo                 ↻ │
├─────────────────────────────┤
│                             │
│  [LAL]   108 – 102   [GSW]  │
│  Lakers  ● Q4 2:34  Warriors│
│                             │
├─────────────────────────────┤
│  [BOS]   95  –  88   [MIA]  │
│  Celtics    FINAL    Heat   │
└─────────────────────────────┘
```

---

## Tech stack

| | |
|---|---|
| Language | Swift 6 |
| UI | SwiftUI (macOS 15+) |
| Data | [ESPN public API](https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard) — no API key required |
| Architecture | `@Observable` ViewModel + `actor` service layer |

---

## Requirements

- macOS 15 or later
- Xcode 16.3+ / Swift 6.3+

---

## Getting started

```bash
git clone https://github.com/phanhom/openinfo.git
cd openinfo
swift build
swift run
```

The app lives in the menu bar — no Dock icon. The floating window appears in the top-right corner of your screen.

---

## Project structure

```
Sources/openinfo/
├── OpeninfoApp.swift               # @main entry point + AppDelegate
├── AppDelegate.swift               # Floating window level & collection behavior
├── Models/
│   ├── ESPNResponse.swift          # Codable mirror of ESPN JSON
│   └── NBAGame.swift               # Internal model + mapper
├── Services/
│   ├── NBAService.swift            # async actor — fetches & decodes scores
│   └── ImageCache.swift            # Two-level logo cache (memory + disk)
├── ViewModels/
│   └── GamesViewModel.swift        # @Observable state, polling logic
├── Views/
│   ├── MenuBar/
│   │   └── MenuBarPopoverView.swift
│   ├── FloatingWindow/
│   │   ├── FloatingWindowView.swift
│   │   └── FloatingGameCard.swift
│   └── Shared/
│       ├── GameCardView.swift       # Compact + full layout modes
│       ├── TeamLogoView.swift       # Cached async image
│       └── StatusIndicatorView.swift
└── Utils/
    └── ColorExtension.swift        # Color(hex:)
```

---

## Refresh policy

| State | Interval |
|---|---|
| Game in progress | every 15 seconds |
| No live games | every 5 minutes |

---

## Logo caching

Team logos are cached to `~/Library/Caches/openinfo/logos/` on first load and served from memory on subsequent views. Cold-start logo flicker is eliminated after the first run.

---

## License

MIT
