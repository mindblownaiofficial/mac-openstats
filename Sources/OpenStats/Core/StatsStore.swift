import Foundation
import Combine

@MainActor
final class StatsStore: ObservableObject {
    static let historyLength = 120

    @Published private(set) var snapshot = Snapshot()
    @Published private(set) var cpuHistory = History(capacity: historyLength)
    @Published private(set) var memoryHistory = History(capacity: historyLength)
    @Published private(set) var downloadHistory = History(capacity: historyLength)
    @Published private(set) var uploadHistory = History(capacity: historyLength)
    @Published private(set) var readHistory = History(capacity: historyLength)
    @Published private(set) var writeHistory = History(capacity: historyLength)
    @Published private(set) var batteryHistory = History(capacity: historyLength)

    let hasBattery: Bool

    private let cpu = CPUMonitor()
    private let memory = MemoryMonitor()
    private let network = NetworkMonitor()
    private let disk = DiskMonitor()
    private let battery = BatteryMonitor()
    private let processes = ProcessMonitor()
    private let system = SystemMonitor()
    private let queue = DispatchQueue(label: "openstats.sampler", qos: .utility)
    private var timer: Timer?
    private var ticks = 0
    private var interval: TimeInterval

    init(interval: TimeInterval) {
        self.interval = interval
        hasBattery = BatteryMonitor.isPresent()
    }

    func start() {
        stop()
        tick()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setInterval(_ newInterval: TimeInterval) {
        guard newInterval != interval else { return }
        interval = newInterval
        start()
    }

    private func tick() {
        // Top processes are the most expensive part; refresh them every other tick.
        let wantProcesses = ticks % 2 == 0
        let previousProcesses = (snapshot.topByCPU, snapshot.topByMemory)
        ticks += 1
        queue.async { [self] in
            var snap = Snapshot()
            snap.cpu = cpu.sample()
            snap.memory = memory.sample()
            snap.network = network.sample()
            snap.disk = disk.sample()
            snap.battery = hasBattery ? battery.sample() : BatteryStats()
            snap.system = system.sample()
            if wantProcesses {
                let top = processes.sample()
                snap.topByCPU = top.byCPU
                snap.topByMemory = top.byMemory
            } else {
                snap.topByCPU = previousProcesses.0
                snap.topByMemory = previousProcesses.1
            }
            snap.timestamp = Date()
            DispatchQueue.main.async { self.apply(snap) }
        }
    }

    private func apply(_ snap: Snapshot) {
        snapshot = snap
        cpuHistory.append(snap.cpu.total)
        memoryHistory.append(snap.memory.usedFraction * 100)
        downloadHistory.append(snap.network.downloadRate)
        uploadHistory.append(snap.network.uploadRate)
        readHistory.append(snap.disk.readRate)
        writeHistory.append(snap.disk.writeRate)
        if snap.battery.present { batteryHistory.append(snap.battery.percent) }
    }
}
