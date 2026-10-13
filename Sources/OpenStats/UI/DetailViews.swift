import SwiftUI
import AppKit

final class PopoverState: ObservableObject {
    @Published var module: Module = .cpu
}

/// Root of the popover shown when a menu bar item is clicked.
struct PopoverView: View {
    @EnvironmentObject var store: StatsStore
    @EnvironmentObject var settings: Settings
    @EnvironmentObject var state: PopoverState
    var openSettings: () -> Void
    var quit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            modulePicker
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Divider()
            Group {
                switch state.module {
                case .cpu: CPUDetail()
                case .memory: MemoryDetail()
                case .network: NetworkDetail()
                case .disk: DiskDetail()
                case .battery: BatteryDetail()
                }
            }
            .padding(12)
            Divider()
            footer
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: 340)
    }

    private var modulePicker: some View {
        HStack(spacing: 6) {
            ForEach(settings.enabledModules.filter { $0 != .battery || store.hasBattery }) { module in
                Button {
                    state.module = module
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: module.symbol)
                        if state.module == module { Text(module.title) }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(state.module == module ? module.color.opacity(0.25) : Color.primary.opacity(0.06))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            Text(store.snapshot.system.hostName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button(action: openSettings) { Image(systemName: "gearshape") }
                .buttonStyle(.plain)
                .help("Settings")
            Button(action: quit) { Image(systemName: "power") }
                .buttonStyle(.plain)
                .help("Quit OpenStats")
        }
        .font(.system(size: 13))
    }
}

// MARK: - Shared pieces

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 6)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var color: Color? = nil

    var body: some View {
        HStack {
            if let color {
                Circle().fill(color).frame(width: 8, height: 8)
            }
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.system(size: 12))
    }
}

struct BigValue: View {
    let value: String
    let caption: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct DetailGraph: View {
    var series: [GraphSeries]
    var maxValue: Double? = nil
    var legend: [(String, Color)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LineGraph(series: series, capacity: StatsStore.historyLength, maxValue: maxValue)
                .frame(height: 70)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.1)))
            if !legend.isEmpty {
                HStack(spacing: 10) {
                    ForEach(Array(legend.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 4) {
                            Circle().fill(item.1).frame(width: 7, height: 7)
                            Text(item.0)
                        }
                    }
                    Spacer()
                    Text("last \(StatsStore.historyLength) samples")
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct ProcessList: View {
    enum Metric { case cpu, memory }
    let rows: [ProcessRow]
    let metric: Metric
    @EnvironmentObject var store: StatsStore

    var body: some View {
        VStack(spacing: 3) {
            ForEach(rows) { row in
                HStack(spacing: 6) {
                    Text(row.name).lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Text(metric == .cpu ? Format.percent(row.cpu, decimals: 1) : Format.bytes(row.memory))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Button {
                        ProcessActionMenu.show(for: row, store: store)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Quit or force quit this process")
                }
                .font(.system(size: 12))
            }
            if rows.isEmpty {
                Text("Collecting…").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - CPU

struct CPUDetail: View {
    @EnvironmentObject var store: StatsStore

    var body: some View {
        let cpu = store.snapshot.cpu
        let sys = store.snapshot.system
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                BigValue(value: Format.percent(cpu.total), caption: "CPU usage", color: Module.cpu.color)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    StatRow(label: "User", value: Format.percent(cpu.user), color: .blue)
                    StatRow(label: "System", value: Format.percent(cpu.system), color: .red)
                    StatRow(label: "Idle", value: Format.percent(cpu.idle), color: .gray)
                }
                .frame(width: 130)
            }
            DetailGraph(series: [GraphSeries(values: store.cpuHistory.values, color: Module.cpu.color)],
                        maxValue: 100, legend: [("Total", Module.cpu.color)])

            if !cpu.perCore.isEmpty {
                SectionTitle("Cores")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(Array(cpu.perCore.enumerated()), id: \.offset) { index, usage in
                        HStack(spacing: 6) {
                            Text("\(index + 1)")
                                .font(.system(size: 10)).monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 16, alignment: .trailing)
                            UsageBar(fraction: usage / 100, color: Module.cpu.color, height: 6)
                            Text(Format.percent(usage))
                                .font(.system(size: 10)).monospacedDigit()
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
            }

            SectionTitle("System")
            StatRow(label: "Load average", value: cpu.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: "  "))
            StatRow(label: "Uptime", value: Format.duration(sys.uptime))
            StatRow(label: "Thermal", value: thermalLabel(sys.thermalState))
            if !sys.cpuBrand.isEmpty { StatRow(label: "Processor", value: sys.cpuBrand) }
            StatRow(label: "Version", value: sys.osVersion)

            SectionTitle("Top processes")
            ProcessList(rows: store.snapshot.topByCPU, metric: .cpu)
        }
    }

    private func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Memory

struct MemoryDetail: View {
    @EnvironmentObject var store: StatsStore

    var body: some View {
        let m = store.snapshot.memory
        let total = Double(max(m.total, 1))
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                BigValue(value: Format.percent(m.usedFraction * 100), caption: "\(Format.bytes(m.used)) of \(Format.bytes(m.total)) used", color: Module.memory.color)
                Spacer()
            }
            DetailGraph(series: [GraphSeries(values: store.memoryHistory.values, color: Module.memory.color)],
                        maxValue: 100, legend: [("Used", Module.memory.color)])

            UsageBar(segments: [
                (Double(m.app) / total, .green),
                (Double(m.wired) / total, .orange),
                (Double(m.compressed) / total, .purple),
                (Double(m.cached) / total, .blue.opacity(0.5)),
            ], height: 10)

            StatRow(label: "App memory", value: Format.bytes(m.app), color: .green)
            StatRow(label: "Wired", value: Format.bytes(m.wired), color: .orange)
            StatRow(label: "Compressed", value: Format.bytes(m.compressed), color: .purple)
            StatRow(label: "Cached files", value: Format.bytes(m.cached), color: .blue.opacity(0.5))
            StatRow(label: "Free", value: Format.bytes(m.free), color: .gray)
            StatRow(label: "Swap", value: m.swapTotal > 0 ? "\(Format.bytes(m.swapUsed)) of \(Format.bytes(m.swapTotal))" : "None")

            SectionTitle("Top processes")
            ProcessList(rows: store.snapshot.topByMemory, metric: .memory)
        }
    }
}

// MARK: - Network

struct NetworkDetail: View {
    @EnvironmentObject var store: StatsStore

    var body: some View {
        let n = store.snapshot.network
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                BigValue(value: Format.rate(n.downloadRate), caption: "↓ Download", color: .blue)
                Spacer()
                BigValue(value: Format.rate(n.uploadRate), caption: "↑ Upload", color: .orange)
            }
            DetailGraph(series: [GraphSeries(values: store.downloadHistory.values, color: .blue),
                                 GraphSeries(values: store.uploadHistory.values, color: .orange)],
                        legend: [("Download", .blue), ("Upload", .orange)])

            SectionTitle("Since boot")
            StatRow(label: "Received", value: Format.bytes(n.totalReceived, decimals: 2))
            StatRow(label: "Sent", value: Format.bytes(n.totalSent, decimals: 2))

            SectionTitle("Interfaces")
            if n.interfaces.isEmpty {
                Text("No active interfaces").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(n.interfaces) { iface in
                StatRow(label: iface.name, value: iface.address)
            }
        }
    }
}

// MARK: - Disk

struct DiskDetail: View {
    @EnvironmentObject var store: StatsStore

    var body: some View {
        let d = store.snapshot.disk
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                BigValue(value: Format.rate(d.readRate), caption: "Read", color: .blue)
                Spacer()
                BigValue(value: Format.rate(d.writeRate), caption: "Write", color: .orange)
            }
            DetailGraph(series: [GraphSeries(values: store.readHistory.values, color: .blue),
                                 GraphSeries(values: store.writeHistory.values, color: .orange)],
                        legend: [("Read", .blue), ("Write", .orange)])

            SectionTitle("Since boot")
            StatRow(label: "Read", value: Format.bytes(d.totalRead, decimals: 2))
            StatRow(label: "Written", value: Format.bytes(d.totalWritten, decimals: 2))

            SectionTitle("Volumes")
            ForEach(d.volumes) { volume in
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(volume.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Spacer()
                        Text("\(Format.bytes(volume.free)) free of \(Format.bytes(volume.total))")
                            .font(.system(size: 11)).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    UsageBar(fraction: volume.usedFraction,
                             color: volume.usedFraction > 0.9 ? .red : Module.disk.color, height: 6)
                }
                .padding(.bottom, 2)
            }
        }
    }
}

// MARK: - Battery

struct BatteryDetail: View {
    @EnvironmentObject var store: StatsStore

    var body: some View {
        let b = store.snapshot.battery
        VStack(alignment: .leading, spacing: 8) {
            if !b.present {
                Text("No battery found").font(.callout).foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top) {
                    BigValue(value: Format.percent(b.percent), caption: statusText(b), color: Module.battery.color)
                    Spacer()
                    Image(systemName: b.isCharging ? "battery.100.bolt" : "battery.100")
                        .font(.system(size: 30))
                        .foregroundStyle(Module.battery.color)
                }
                UsageBar(fraction: b.percent / 100, color: b.percent < 20 ? .red : Module.battery.color, height: 10)
                DetailGraph(series: [GraphSeries(values: store.batteryHistory.values, color: Module.battery.color)],
                            maxValue: 100, legend: [("Charge", Module.battery.color)])

                SectionTitle("Details")
                if let minutes = b.minutesRemaining {
                    StatRow(label: b.isCharging ? "Time to full" : "Time remaining", value: Format.minutes(minutes))
                }
                StatRow(label: "Power source", value: b.isPluggedIn ? "Power adapter" : "Battery")
                if let health = b.health { StatRow(label: "Health", value: Format.percent(health)) }
                if let cycles = b.cycleCount { StatRow(label: "Cycle count", value: "\(cycles)") }
                if let watts = b.watts { StatRow(label: b.isCharging ? "Charging at" : "Power draw", value: String(format: "%.1f W", watts)) }
                if let voltage = b.voltage { StatRow(label: "Voltage", value: String(format: "%.2f V", voltage)) }
                if let temp = b.temperature { StatRow(label: "Temperature", value: String(format: "%.1f °C", temp)) }
            }
        }
    }

    private func statusText(_ b: BatteryStats) -> String {
        if b.isCharging { return "Charging" }
        if b.isPluggedIn { return b.percent >= 99 ? "Fully charged" : "Plugged in, not charging" }
        return "On battery"
    }
}
