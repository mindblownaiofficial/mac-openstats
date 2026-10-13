# Changelog

## 0.4.1 – 2026-10-14

- Fixed: toggling modules in Settings rebuilt the menu bar from the previous state, so enabling a single module (for example only Memory) showed nothing
- A menu bar item always shows at least its icon, even with icon, graph and value all unticked

## 0.4.0 – 2026-10-14

- Dashboard window with all modules side by side, from the right-click menu or the panel footer
- A fallback OpenStats menu bar icon stays visible when every module is turned off, so Settings is always reachable
- Opening the app again while it is running shows the Dashboard

## 0.3.0 – 2026-10-13

- Memory percentage, graph and menu bar value turn yellow at 70%, orange at 80% and red at 90% usage

## 0.2.0 – 2026-10-13

- Quit and Force Quit actions on every row of the Top Processes lists (CPU and Memory panels)

## 0.1.0 – 2026-10-13

First release.

- CPU, memory, network, disk and battery menu bar items with scrolling graphs
- Detail popover per module with history graph, breakdowns and top processes
- Per-module icon/graph/value toggles, refresh interval, launch at login
- `--dump` command-line mode
- `.dmg` and `.pkg` installers built by `Scripts/release.sh`
