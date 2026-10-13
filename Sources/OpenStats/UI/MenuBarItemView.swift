import SwiftUI

/// The compact view rendered inside each menu bar status item.
struct MenuBarItemView: View {
    let module: Module
    @EnvironmentObject var store: StatsStore
    @EnvironmentObject var settings: Settings

    private var config: ModuleConfig { settings.config(for: module) }

    var body: some View {
        // Always draw at least the icon so an item can never become invisible.
        let showIcon = config.showIcon || (!config.showGraph && !config.showValue)
        HStack(spacing: 4) {
            if showIcon {
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 14)
            }
            if config.showGraph {
                LineGraph(series: graphSeries, capacity: StatsStore.historyLength, maxValue: graphMax, lineWidth: 1)
                    .frame(width: 30, height: 14)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.primary.opacity(0.25), lineWidth: 0.5))
            }
            if config.showValue {
                valueView
            }
        }
        .padding(.horizontal, 5)
        .frame(height: 22)
        .fixedSize()
    }

    private var iconName: String {
        if module == .battery {
            let b = store.snapshot.battery
            if b.isCharging { return "battery.100.bolt" }
            switch b.percent {
            case ..<15: return "battery.25"
            case ..<40: return "battery.50"
            case ..<70: return "battery.75"
            default: return "battery.100"
            }
        }
        return module.symbol
    }

    @ViewBuilder private var valueView: some View {
        let s = store.snapshot
        switch module {
        case .cpu:
            Text(Format.percent(s.cpu.total)).valueStyle().frame(width: 32, alignment: .trailing)
        case .memory:
            let percent = s.memory.usedFraction * 100
            Text(Format.percent(percent)).valueStyle()
                .foregroundStyle(percent >= 70 ? UsageLevel.color(for: percent) : .primary)
                .frame(width: 32, alignment: .trailing)
        case .network:
            VStack(alignment: .trailing, spacing: 0) {
                Text("↓ " + Format.rateShort(s.network.downloadRate))
                Text("↑ " + Format.rateShort(s.network.uploadRate))
            }
            .font(.system(size: 8.5, weight: .medium)).monospacedDigit()
            .frame(width: 52, alignment: .trailing)
        case .disk:
            VStack(alignment: .trailing, spacing: 0) {
                Text("R " + Format.rateShort(s.disk.readRate))
                Text("W " + Format.rateShort(s.disk.writeRate))
            }
            .font(.system(size: 8.5, weight: .medium)).monospacedDigit()
            .frame(width: 52, alignment: .trailing)
        case .battery:
            Text(Format.percent(s.battery.percent)).valueStyle().frame(width: 32, alignment: .trailing)
        }
    }

    private var graphSeries: [GraphSeries] {
        switch module {
        case .cpu: return [GraphSeries(values: store.cpuHistory.values, color: module.color)]
        case .memory:
            let color = UsageLevel.color(for: store.snapshot.memory.usedFraction * 100, normal: module.color)
            return [GraphSeries(values: store.memoryHistory.values, color: color)]
        case .network: return [GraphSeries(values: store.downloadHistory.values, color: .blue),
                               GraphSeries(values: store.uploadHistory.values, color: .orange)]
        case .disk: return [GraphSeries(values: store.readHistory.values, color: .blue),
                            GraphSeries(values: store.writeHistory.values, color: .orange)]
        case .battery: return [GraphSeries(values: store.batteryHistory.values, color: module.color)]
        }
    }

    private var graphMax: Double? {
        switch module {
        case .cpu, .memory, .battery: return 100
        case .network, .disk: return nil
        }
    }
}

private extension Text {
    func valueStyle() -> some View {
        self.font(.system(size: 11, weight: .medium)).monospacedDigit()
    }
}
