import Foundation
import IOKit

final class DiskMonitor {
    private var lastRead: UInt64 = 0
    private var lastWrite: UInt64 = 0
    private var lastTime: Date?

    func sample() -> DiskStats {
        var stats = DiskStats()
        let (read, write) = ioCounters()
        stats.totalRead = read
        stats.totalWritten = write
        let now = Date()
        if let last = lastTime {
            let dt = now.timeIntervalSince(last)
            if dt > 0 {
                stats.readRate = read >= lastRead ? Double(read - lastRead) / dt : 0
                stats.writeRate = write >= lastWrite ? Double(write - lastWrite) / dt : 0
            }
        }
        lastRead = read
        lastWrite = write
        lastTime = now
        stats.volumes = volumes()
        return stats
    }

    private func ioCounters() -> (UInt64, UInt64) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else {
            return (0, 0)
        }
        defer { IOObjectRelease(iterator) }
        var read: UInt64 = 0
        var write: UInt64 = 0
        while true {
            let entry = IOIteratorNext(iterator)
            guard entry != 0 else { break }
            defer { IOObjectRelease(entry) }
            guard let raw = IORegistryEntryCreateCFProperty(entry, "Statistics" as CFString, kCFAllocatorDefault, 0),
                  let props = raw.takeRetainedValue() as? [String: Any] else { continue }
            read &+= (props["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            write &+= (props["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
        }
        return (read, write)
    }

    private func volumes() -> [Volume] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey, .volumeIsBrowsableKey]
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return []
        }
        var result: [Volume] = []
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.volumeIsBrowsable ?? true,
                  let total = values.volumeTotalCapacity, total > 0 else { continue }
            let free = values.volumeAvailableCapacityForImportantUsage ?? 0
            result.append(Volume(name: values.volumeName ?? url.lastPathComponent, path: url.path,
                                 total: UInt64(total), free: UInt64(max(free, 0))))
        }
        // Root volume first, then alphabetical.
        return result.sorted { a, b in
            if a.path == "/" { return true }
            if b.path == "/" { return false }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
