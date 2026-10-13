import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: Settings

    var body: some View {
        Form {
            Section("General") {
                HStack {
                    Text("Refresh every")
                    Slider(value: $settings.refreshInterval, in: 1...10, step: 1)
                    Text("\(Int(settings.refreshInterval))s").monospacedDigit().frame(width: 28)
                }
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                if let error = settings.launchAtLoginError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Menu bar items") {
                ForEach(Module.allCases) { module in
                    ModuleRow(module: module)
                }
            }
            Section {
                Text("OpenStats is free, open-source software released under the MIT license.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 520)
    }
}

private struct ModuleRow: View {
    let module: Module
    @EnvironmentObject var settings: Settings

    var body: some View {
        let config = settings.config(for: module)
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: binding(\.enabled)) {
                Label(module.title, systemImage: module.symbol)
            }
            if config.enabled {
                HStack(spacing: 16) {
                    Toggle("Icon", isOn: binding(\.showIcon))
                    Toggle("Graph", isOn: binding(\.showGraph))
                    Toggle("Value", isOn: binding(\.showValue))
                }
                .toggleStyle(.checkbox)
                .font(.caption)
                .padding(.leading, 24)
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<ModuleConfig, Bool>) -> Binding<Bool> {
        Binding(
            get: { settings.config(for: module)[keyPath: keyPath] },
            set: { value in settings.update(module) { $0[keyPath: keyPath] = value } }
        )
    }
}
