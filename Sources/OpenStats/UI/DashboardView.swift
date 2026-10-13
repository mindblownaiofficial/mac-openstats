import SwiftUI

/// A resizable window that shows every module's detail panel side by side.
struct DashboardView: View {
    @EnvironmentObject var store: StatsStore
    @EnvironmentObject var settings: Settings
    var openSettings: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 16, alignment: .top),
                           GridItem(.flexible(), spacing: 16, alignment: .top)]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    panel(.cpu) { CPUDetail() }
                    panel(.memory) { MemoryDetail() }
                    panel(.network) { NetworkDetail() }
                    panel(.disk) { DiskDetail() }
                    if store.hasBattery {
                        panel(.battery) { BatteryDetail() }
                    }
                }
                .padding(16)
            }
            Divider()
            HStack {
                Text("\(store.snapshot.system.hostName) · \(store.snapshot.system.osVersion)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Settings…", action: openSettings)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 740, minHeight: 520)
    }

    private func panel<Content: View>(_ module: Module, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: module.symbol).foregroundStyle(module.color)
                Text(module.title).font(.headline)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08)))
    }
}
