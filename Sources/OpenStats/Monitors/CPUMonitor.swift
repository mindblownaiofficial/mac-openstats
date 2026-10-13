import Foundation

final class CPUMonitor {
    private var previous: [[UInt32]] = []

    func sample() -> CPUStats {
        var stats = CPUStats()
        var loads = [Double](repeating: 0, count: 3)
        if getloadavg(&loads, 3) == 3 { stats.loadAverage = loads }

        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else { return stats }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        let states = Int(CPU_STATE_MAX)
        var current: [[UInt32]] = []
        current.reserveCapacity(Int(cpuCount))
        for core in 0..<Int(cpuCount) {
            let base = core * states
            current.append((0..<states).map { UInt32(bitPattern: info[base + $0]) })
        }
        defer { previous = current }
        guard previous.count == current.count else { return stats }

        var sumUser = 0.0, sumSystem = 0.0, sumIdle = 0.0, sumTotal = 0.0
        var perCore: [Double] = []
        for (prev, cur) in zip(previous, current) {
            let user = Double(cur[Int(CPU_STATE_USER)] &- prev[Int(CPU_STATE_USER)])
            let system = Double(cur[Int(CPU_STATE_SYSTEM)] &- prev[Int(CPU_STATE_SYSTEM)])
            let nice = Double(cur[Int(CPU_STATE_NICE)] &- prev[Int(CPU_STATE_NICE)])
            let idle = Double(cur[Int(CPU_STATE_IDLE)] &- prev[Int(CPU_STATE_IDLE)])
            let total = user + system + nice + idle
            perCore.append(total > 0 ? (total - idle) / total * 100 : 0)
            sumUser += user + nice
            sumSystem += system
            sumIdle += idle
            sumTotal += total
        }
        if sumTotal > 0 {
            stats.user = sumUser / sumTotal * 100
            stats.system = sumSystem / sumTotal * 100
            stats.idle = sumIdle / sumTotal * 100
            stats.total = 100 - stats.idle
        }
        stats.perCore = perCore
        return stats
    }
}
