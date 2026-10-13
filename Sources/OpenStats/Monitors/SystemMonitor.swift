import Foundation

final class SystemMonitor {
    private lazy var cpuBrand: String = sysctlString("machdep.cpu.brand_string")
    private lazy var osVersion: String = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }()

    func sample() -> SystemStats {
        var stats = SystemStats()
        stats.uptime = ProcessInfo.processInfo.systemUptime
        stats.cpuBrand = cpuBrand
        stats.osVersion = osVersion
        stats.hostName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        stats.thermalState = ProcessInfo.processInfo.thermalState
        return stats
    }

    private func sysctlString(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return "" }
        return String(cString: buffer)
    }
}
