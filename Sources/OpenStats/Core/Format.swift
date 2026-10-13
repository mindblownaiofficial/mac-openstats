import Foundation

enum Format {
    private static let units = ["B", "KB", "MB", "GB", "TB", "PB"]

    /// "12.3 GB"
    static func bytes(_ value: UInt64, decimals: Int = 1) -> String {
        scaled(Double(value), decimals: decimals, suffix: "")
    }

    /// "1.2 MB/s"
    static func rate(_ bytesPerSecond: Double, decimals: Int = 1) -> String {
        scaled(bytesPerSecond, decimals: decimals, suffix: "/s")
    }

    /// Compact form for the menu bar: "1.2M/s", "340K/s"
    static func rateShort(_ bytesPerSecond: Double) -> String {
        var v = max(bytesPerSecond, 0)
        var i = 0
        while v >= 1000 && i < units.count - 1 { v /= 1024; i += 1 }
        let letter = i == 0 ? "B" : String(units[i].prefix(1))
        let text = v < 10 && i > 0 ? String(format: "%.1f", v) : String(format: "%.0f", v)
        return "\(text)\(letter)/s"
    }

    /// Compact bytes for the menu bar: "12.3G"
    static func bytesShort(_ value: UInt64) -> String {
        var v = Double(value)
        var i = 0
        while v >= 1000 && i < units.count - 1 { v /= 1024; i += 1 }
        let letter = i == 0 ? "B" : String(units[i].prefix(1))
        let text = v < 10 && i > 0 ? String(format: "%.1f", v) : String(format: "%.0f", v)
        return "\(text)\(letter)"
    }

    static func percent(_ value: Double, decimals: Int = 0) -> String {
        String(format: "%.\(decimals)f%%", value)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let days = s / 86400
        let hours = (s % 86400) / 3600
        let minutes = (s % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    static func minutes(_ m: Int) -> String {
        let h = m / 60, r = m % 60
        return h > 0 ? "\(h)h \(r)m" : "\(r)m"
    }

    private static func scaled(_ value: Double, decimals: Int, suffix: String) -> String {
        var v = max(value, 0)
        var i = 0
        while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
        let text = i == 0 ? String(format: "%.0f", v) : String(format: "%.\(decimals)f", v)
        return "\(text) \(units[i])\(suffix)"
    }
}
