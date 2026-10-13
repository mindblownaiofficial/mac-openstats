import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: Settings!
    private var store: StatsStore!
    private var statusBar: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        settings = Settings()
        store = StatsStore(interval: settings.refreshInterval)
        statusBar = StatusBarController(store: store, settings: settings)
        store.start()
    }

    /// Opening the app again from Finder or the Dock while it is already running
    /// shows the dashboard, so there is always a way in even with every menu bar item hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        statusBar.showDashboard()
        return false
    }
}

@main
struct OpenStatsApp {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--dump") {
            Dump.run()
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// `OpenStats --dump` prints one sample of every monitor to stdout. Handy for
/// debugging and for scripting without the menu bar UI.
enum Dump {
    static func run() {
        let cpu = CPUMonitor(), memory = MemoryMonitor(), network = NetworkMonitor()
        let disk = DiskMonitor(), battery = BatteryMonitor(), processes = ProcessMonitor(), system = SystemMonitor()
        // Rates need two samples; take the first, wait, then report the second.
        _ = cpu.sample(); _ = network.sample(); _ = disk.sample()
        Thread.sleep(forTimeInterval: 1)
        let c = cpu.sample(), m = memory.sample(), n = network.sample(), d = disk.sample()
        let b = battery.sample(), p = processes.sample(), s = system.sample()

        print("System    \(s.hostName) · \(s.osVersion) · \(s.cpuBrand) · up \(Format.duration(s.uptime))")
        print("CPU       total \(Format.percent(c.total, decimals: 1))  user \(Format.percent(c.user, decimals: 1))  system \(Format.percent(c.system, decimals: 1))  cores \(c.perCore.count)  load \(c.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: " "))")
        print("Memory    used \(Format.bytes(m.used)) of \(Format.bytes(m.total)) (\(Format.percent(m.usedFraction * 100)))  app \(Format.bytes(m.app))  wired \(Format.bytes(m.wired))  compressed \(Format.bytes(m.compressed))  cached \(Format.bytes(m.cached))  swap \(Format.bytes(m.swapUsed))/\(Format.bytes(m.swapTotal))")
        print("Network   ↓ \(Format.rate(n.downloadRate))  ↑ \(Format.rate(n.uploadRate))  total ↓ \(Format.bytes(n.totalReceived)) ↑ \(Format.bytes(n.totalSent))  interfaces \(n.interfaces.map { "\($0.name)=\($0.address)" }.joined(separator: ", "))")
        print("Disk      read \(Format.rate(d.readRate))  write \(Format.rate(d.writeRate))  total read \(Format.bytes(d.totalRead)) written \(Format.bytes(d.totalWritten))")
        for v in d.volumes { print("          \(v.name) (\(v.path)) \(Format.bytes(v.free)) free of \(Format.bytes(v.total))") }
        if b.present {
            print("Battery   \(Format.percent(b.percent))  charging \(b.isCharging)  plugged \(b.isPluggedIn)  remaining \(b.minutesRemaining.map(Format.minutes) ?? "–")  health \(b.health.map { Format.percent($0) } ?? "–")  cycles \(b.cycleCount.map(String.init) ?? "–")  temp \(b.temperature.map { String(format: "%.1f°C", $0) } ?? "–")  power \(b.watts.map { String(format: "%.1f W", $0) } ?? "–")")
        } else {
            print("Battery   none")
        }
        print("Top CPU   " + p.byCPU.map { "\($0.name) \(Format.percent($0.cpu, decimals: 1))" }.joined(separator: ", "))
        print("Top Mem   " + p.byMemory.map { "\($0.name) \(Format.bytes($0.memory))" }.joined(separator: ", "))
    }
}
