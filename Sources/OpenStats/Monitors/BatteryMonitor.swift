import Foundation
import IOKit
import IOKit.ps

final class BatteryMonitor {
    static func isPresent() -> Bool {
        BatteryMonitor().sample().present
    }

    func sample() -> BatteryStats {
        var stats = BatteryStats()
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return stats
        }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            stats.present = true
            let current = description[kIOPSCurrentCapacityKey] as? Double ?? 0
            let max = description[kIOPSMaxCapacityKey] as? Double ?? 100
            stats.percent = max > 0 ? current / max * 100 : 0
            stats.isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            stats.isPluggedIn = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            let key = stats.isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
            if let minutes = description[key] as? Int, minutes > 0 { stats.minutesRemaining = minutes }
            break
        }
        guard stats.present else { return stats }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return stats }
        defer { IOObjectRelease(service) }
        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let props = unmanaged?.takeRetainedValue() as? [String: Any] else { return stats }

        stats.cycleCount = (props["CycleCount"] as? NSNumber)?.intValue
        let design = (props["DesignCapacity"] as? NSNumber)?.doubleValue ?? 0
        let maxCapacity = (props["AppleRawMaxCapacity"] as? NSNumber)?.doubleValue
            ?? (props["NominalChargeCapacity"] as? NSNumber)?.doubleValue
            ?? (props["MaxCapacity"] as? NSNumber)?.doubleValue ?? 0
        if design > 0, maxCapacity > 0 { stats.health = min(maxCapacity / design * 100, 100) }
        if let temp = (props["Temperature"] as? NSNumber)?.doubleValue, temp > 0 { stats.temperature = temp / 100 }
        if let voltage = (props["Voltage"] as? NSNumber)?.doubleValue, voltage > 0 {
            stats.voltage = voltage / 1000
            if let amperage = (props["Amperage"] as? NSNumber)?.doubleValue {
                // Amperage is a signed value in mA; negative while discharging.
                stats.watts = abs(amperage) * voltage / 1_000_000
            }
        }
        return stats
    }
}
