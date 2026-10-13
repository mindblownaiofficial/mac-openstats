import Foundation

final class NetworkMonitor {
    private var lastIn: UInt64 = 0
    private var lastOut: UInt64 = 0
    private var lastTime: Date?

    /// Interfaces that carry traffic already counted on a physical interface (VPN tunnels,
    /// bridges, AirDrop side-channels) or that never leave the machine.
    private static let ignoredPrefixes = ["lo", "gif", "stf", "awdl", "llw", "utun", "ipsec", "bridge", "ap", "vmnet", "anpi", "pktap"]

    func sample() -> NetworkStats {
        var stats = NetworkStats()
        let (bytesIn, bytesOut) = counters()
        stats.totalReceived = bytesIn
        stats.totalSent = bytesOut

        let now = Date()
        if let last = lastTime {
            let dt = now.timeIntervalSince(last)
            if dt > 0 {
                stats.downloadRate = bytesIn >= lastIn ? Double(bytesIn - lastIn) / dt : 0
                stats.uploadRate = bytesOut >= lastOut ? Double(bytesOut - lastOut) / dt : 0
            }
        }
        lastIn = bytesIn
        lastOut = bytesOut
        lastTime = now
        stats.interfaces = addresses()
        return stats
    }

    /// 64-bit interface byte counters via the routing socket (same source `netstat -ib` uses).
    private func counters() -> (UInt64, UInt64) {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return (0, 0) }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, UInt32(mib.count), &buffer, &length, nil, 0) == 0 else { return (0, 0) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        buffer.withUnsafeBytes { raw in
            var offset = 0
            let headerSize = MemoryLayout<if_msghdr>.size
            while offset + headerSize <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                let messageLength = Int(header.ifm_msglen)
                guard messageLength > 0 else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= length {
                    let msg = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    let flags = Int32(bitPattern: UInt32(truncatingIfNeeded: msg.ifm_flags))
                    var nameBuffer = [CChar](repeating: 0, count: Int(IF_NAMESIZE) + 1)
                    let name = if_indextoname(UInt32(msg.ifm_index), &nameBuffer).map { String(cString: $0) } ?? ""
                    if flags & IFF_LOOPBACK == 0, flags & IFF_UP != 0, !Self.isIgnored(name) {
                        totalIn &+= msg.ifm_data.ifi_ibytes
                        totalOut &+= msg.ifm_data.ifi_obytes
                    }
                }
                offset += messageLength
            }
        }
        return (totalIn, totalOut)
    }

    private func addresses() -> [NetworkInterface] {
        var result: [NetworkInterface] = []
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0 else { return result }
        defer { freeifaddrs(first) }
        var cursor = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let ifa = entry.pointee
            guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            let name = String(cString: ifa.ifa_name)
            let flags = Int32(bitPattern: ifa.ifa_flags)
            guard flags & IFF_LOOPBACK == 0, flags & IFF_UP != 0, flags & IFF_RUNNING != 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                result.append(NetworkInterface(name: name, address: String(cString: host)))
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    private static func isIgnored(_ name: String) -> Bool {
        ignoredPrefixes.contains { prefix in
            name.hasPrefix(prefix) && name.dropFirst(prefix.count).allSatisfy(\.isNumber)
        }
    }
}
