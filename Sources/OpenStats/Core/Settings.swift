import Foundation
import Combine
import ServiceManagement

struct ModuleConfig: Codable, Equatable {
    var enabled = true
    var showIcon = true
    var showGraph = true
    var showValue = true
}

final class Settings: ObservableObject {
    private let defaults = UserDefaults.standard
    private static let intervalKey = "refreshInterval"
    private static let configsKey = "moduleConfigs"

    @Published var refreshInterval: Double {
        didSet { defaults.set(refreshInterval, forKey: Self.intervalKey) }
    }

    @Published var configs: [Module: ModuleConfig] {
        didSet {
            if let data = try? JSONEncoder().encode(configs) {
                defaults.set(data, forKey: Self.configsKey)
            }
        }
    }

    @Published private(set) var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @Published private(set) var launchAtLoginError: String?

    init() {
        let interval = defaults.double(forKey: Self.intervalKey)
        refreshInterval = interval > 0 ? interval : 2
        if let data = defaults.data(forKey: Self.configsKey),
           let decoded = try? JSONDecoder().decode([Module: ModuleConfig].self, from: data) {
            configs = decoded
        } else {
            configs = [:]
        }
    }

    func config(for module: Module) -> ModuleConfig {
        configs[module] ?? ModuleConfig()
    }

    func update(_ module: Module, _ change: (inout ModuleConfig) -> Void) {
        var config = self.config(for: module)
        change(&config)
        configs[module] = config
    }

    var enabledModules: [Module] {
        Module.allCases.filter { config(for: $0).enabled }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
