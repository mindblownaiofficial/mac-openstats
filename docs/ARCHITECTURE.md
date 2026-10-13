# Architecture

OpenStats is a single Swift Package Manager executable target with no third-party
dependencies. It is a menu bar only app (`LSUIElement`), built with AppKit for the
status items and popover and SwiftUI for everything drawn inside them.

```
Sources/OpenStats/
├── App.swift                  @main entry, AppDelegate, `--dump` diagnostic mode
├── Core/
│   ├── Models.swift           Module enum, *Stats structs, Snapshot, History ring buffer
│   ├── Settings.swift         ObservableObject persisted to UserDefaults
│   ├── StatsStore.swift       Timer-driven sampler; publishes Snapshot + histories
│   └── Format.swift           Byte/rate/percent/duration formatting
├── Monitors/                  One class per data source, each with `sample()`
│   ├── CPUMonitor.swift       host_processor_info tick deltas, getloadavg
│   ├── MemoryMonitor.swift    host_statistics64, sysctl vm.swapusage
│   ├── NetworkMonitor.swift   sysctl NET_RT_IFLIST2 (64-bit counters), getifaddrs
│   ├── DiskMonitor.swift      IOKit IOBlockStorageDriver stats, mounted volumes
│   ├── BatteryMonitor.swift   IOPowerSources + AppleSmartBattery registry entry
│   ├── ProcessMonitor.swift   /bin/ps for top processes
│   └── SystemMonitor.swift    uptime, CPU brand, OS version, thermal state
└── UI/
    ├── StatusBarController.swift  Creates NSStatusItems, popover, context menu, settings window
    ├── MenuBarItemView.swift      Compact icon + mini graph + value for the menu bar
    ├── DetailViews.swift          Popover root and per-module detail panels
    ├── Graphs.swift               LineGraph and UsageBar
    └── SettingsView.swift         Settings form
```

## Data flow

1. `StatsStore.start()` fires a `Timer` on the main run loop every
   `Settings.refreshInterval` seconds (default 2).
2. Each tick dispatches to a serial utility queue, where every monitor's
   `sample()` runs. Monitors keep their own previous counters so they can turn
   cumulative values into rates. Top processes are refreshed every other tick
   because spawning `ps` is the most expensive step.
3. The finished `Snapshot` is handed back to the main actor, where the store
   publishes it and appends to the `History` ring buffers (120 points each).
4. SwiftUI views observe the store through `@EnvironmentObject` and redraw. Each
   `NSStatusItem` hosts a `MenuBarItemView` inside an `NSHostingView` subclass
   whose `hitTest` returns `nil`, so clicks fall through to the status bar button.
5. `StatusBarController` recomputes each item's `length` from the hosting view's
   fitting size when a snapshot arrives, and rebuilds all items when module
   settings change.

## Why these APIs

Everything is read through public, unprivileged APIs so the app needs no helper
tool, root access or entitlements:

- CPU tick counters wrap at 32 bits, so deltas use wrapping subtraction.
- Network bytes come from `NET_RT_IFLIST2` rather than `getifaddrs`, because the
  latter exposes only 32-bit counters that wrap every 4 GB. Loopback, tunnel and
  bridge interfaces are skipped so VPN traffic is not double counted.
- Memory "used" follows Activity Monitor: app memory (internal minus purgeable) +
  wired + compressed.
- Battery health is `AppleRawMaxCapacity / DesignCapacity`.

## Build constraints

The project builds with only the Command Line Tools. That toolchain lacks the
SwiftUI macro plugin, so the code avoids `@State` and other macro-backed
property wrappers in favor of `@EnvironmentObject` and explicit `Binding`s.
The package is compiled in Swift 5 language mode.

`Scripts/build-app.sh` assembles the `.app` bundle by hand from the SwiftPM
binary, `Resources/Info.plist` and the icon rendered by `Scripts/make-icon.swift`.
