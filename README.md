# mac-openstats

**OpenStats** is a free, open-source system monitor for the macOS menu bar. It
shows live CPU, memory, network, disk and battery stats as compact graphs in your
menu bar, with a detail panel one click away.

Built as a free alternative to paid menu bar monitors. No ads, no telemetry, no
subscription. MIT licensed.

## Screenshot
<img width="1078" height="45" alt="image" src="https://github.com/user-attachments/assets/e6f9d65c-b987-4aab-9075-64d6b804dcc9" />


## Install

Download the installer from the
[latest release](https://github.com/woodsjohn16/mac-openstats/releases/latest):

- **OpenStats-x.y.z.pkg**: double-click, it installs to Applications and opens.
- **OpenStats-x.y.z.dmg**: drag OpenStats to Applications.

macOS 13 Ventura or later. Because the app is not notarized, the first launch is
blocked by Gatekeeper: open **System Settings → Privacy & Security** and click
**Open Anyway**. Details, including uninstalling, are in
[docs/INSTALL.md](docs/INSTALL.md).

## Features

- **CPU** – total usage, user/system split, per-core bars, load average, uptime,
  thermal state and the top processes.
- **Memory** – used/free, app, wired, compressed and cached breakdown, swap, and
  the heaviest processes.
- **Network** – live download/upload rates with a dual graph, totals since boot
  and the IP address of each active interface.
- **Disk** – read/write throughput, totals since boot and free space for every
  mounted volume.
- **Battery** – charge, time remaining, health, cycle count, temperature,
  voltage and power draw (hidden automatically on desktop Macs).
- **Quit or force quit** any process straight from the Top Processes list.
- Scrolling history graphs in the menu bar and in the panel.
- Per-module toggles for icon, graph and value; adjustable refresh rate;
  launch at login.
- Native Swift and SwiftUI, no third-party dependencies, under 2% CPU and about
  30 MB of memory.

## Using it

- **Left-click** a menu bar item to open its detail panel. The pills at the top
  of the panel switch between modules.
- **Right-click** any item for Settings, About and Quit.
- The gear in the panel opens Settings, where you choose which modules appear
  and what each one shows.
- In the CPU and Memory panels, click the ⓧ next to a process to **Quit** it
  (the app can save first) or **Force Quit** it (after a confirmation).

## Build from source

Only the Xcode Command Line Tools are needed (`xcode-select --install`).

```bash
git clone https://github.com/woodsjohn16/mac-openstats.git
cd mac-openstats
./Scripts/build-app.sh        # → build/OpenStats.app
./Scripts/release.sh          # app + .dmg + .pkg + checksums
```

During development:

```bash
swift run                     # run the menu bar app
swift run OpenStats --dump    # print one sample of every monitor, no UI
```

## How it reads the numbers

Everything comes from public system APIs, so no helper tool or root access is
needed:

| Module    | Source |
|-----------|--------|
| CPU       | `host_processor_info` tick counters, `getloadavg` |
| Memory    | `host_statistics64` (`vm_statistics64`), `sysctl vm.swapusage` |
| Network   | `sysctl NET_RT_IFLIST2` 64-bit interface counters, `getifaddrs` |
| Disk      | IOKit `IOBlockStorageDriver` statistics, `FileManager` volume capacities |
| Battery   | `IOPSCopyPowerSourcesInfo`, IOKit `AppleSmartBattery` |
| Processes | `/bin/ps` |

More in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Documentation

- [docs/INSTALL.md](docs/INSTALL.md) – installing, Gatekeeper, uninstalling, signing
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) – how the code is organized and why
- [CONTRIBUTING.md](CONTRIBUTING.md) – developing, guidelines, releasing
- [CHANGELOG.md](CHANGELOG.md)

## Roadmap ideas

- Temperature and fan sensors (SMC)
- GPU usage
- Combined single-item mode and custom colors
- Notifications for thresholds (low disk space, high CPU)
- Localization

## License

MIT. See [LICENSE](LICENSE).
