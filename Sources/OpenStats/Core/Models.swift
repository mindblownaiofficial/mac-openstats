import Foundation
import SwiftUI

enum Module: String, CaseIterable, Codable, Identifiable {
    case cpu, memory, network, disk, battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cpu: return "CPU"
        case .memory: return "Memory"
        case .network: return "Network"
        case .disk: return "Disk"
        case .battery: return "Battery"
        }
    }

    var symbol: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .network: return "arrow.up.arrow.down"
        case .disk: return "internaldrive"
        case .battery: return "battery.100"
        }
    }

    var color: Color {
        switch self {
        case .cpu: return .blue
        case .memory: return .green
        case .network: return .purple
        case .disk: return .orange
        case .battery: return .mint
        }
    }
}

struct CPUStats {
    var total: Double = 0
    var user: Double = 0
    var system: Double = 0
    var idle: Double = 100
    var perCore: [Double] = []
    var loadAverage: [Double] = [0, 0, 0]
}

struct MemoryStats {
    var total: UInt64 = 0
    var used: UInt64 = 0
    var app: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var cached: UInt64 = 0
    var free: UInt64 = 0
    var swapUsed: UInt64 = 0
    var swapTotal: UInt64 = 0

    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct NetworkInterface: Identifiable {
    let name: String
    let address: String
    var id: String { name }
}

struct NetworkStats {
    var downloadRate: Double = 0
    var uploadRate: Double = 0
    var totalReceived: UInt64 = 0
    var totalSent: UInt64 = 0
    var interfaces: [NetworkInterface] = []
}

struct Volume: Identifiable {
    let name: String
    let path: String
    let total: UInt64
    let free: UInt64
    var id: String { path }
    var used: UInt64 { total > free ? total - free : 0 }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

struct DiskStats {
    var readRate: Double = 0
    var writeRate: Double = 0
    var totalRead: UInt64 = 0
    var totalWritten: UInt64 = 0
    var volumes: [Volume] = []
}

struct BatteryStats {
    var present = false
    var percent: Double = 0
    var isCharging = false
    var isPluggedIn = false
    var minutesRemaining: Int?
    var cycleCount: Int?
    var health: Double?
    var temperature: Double?
    var watts: Double?
    var voltage: Double?
}

struct ProcessRow: Identifiable {
    let pid: Int32
    let name: String
    let cpu: Double
    let memory: UInt64
    var id: Int32 { pid }
}

struct SystemStats {
    var uptime: TimeInterval = 0
    var cpuBrand = ""
    var osVersion = ""
    var hostName = ""
    var thermalState: ProcessInfo.ThermalState = .nominal
}

struct Snapshot {
    var cpu = CPUStats()
    var memory = MemoryStats()
    var network = NetworkStats()
    var disk = DiskStats()
    var battery = BatteryStats()
    var topByCPU: [ProcessRow] = []
    var topByMemory: [ProcessRow] = []
    var system = SystemStats()
    var timestamp = Date()
}

/// Fixed-size ring of recent values used to draw graphs.
struct History {
    private(set) var values: [Double] = []
    let capacity: Int

    init(capacity: Int) { self.capacity = capacity }

    mutating func append(_ value: Double) {
        values.append(value)
        if values.count > capacity {
            values.removeFirst(values.count - capacity)
        }
    }
}

/// Maps a usage percentage to a warning color: green below 70%, then yellow,
/// orange at 80% and red from 90%.
enum UsageLevel {
    static func color(for percent: Double, normal: Color = .green) -> Color {
        switch percent {
        case ..<70: return normal
        case ..<80: return .yellow
        case ..<90: return .orange
        default: return .red
        }
    }
}
