import Foundation

final class MemoryMonitor {
    func sample() -> MemoryStats {
        var stats = MemoryStats()
        stats.total = ProcessInfo.processInfo.physicalMemory

        var vm = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vm) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return stats }

        let page = UInt64(vm_kernel_page_size)
        let internalPages = UInt64(vm.internal_page_count)
        let purgeable = UInt64(vm.purgeable_count)
        stats.app = (internalPages > purgeable ? internalPages - purgeable : 0) * page
        stats.wired = UInt64(vm.wire_count) * page
        stats.compressed = UInt64(vm.compressor_page_count) * page
        stats.cached = (UInt64(vm.external_page_count) + purgeable) * page
        stats.free = UInt64(vm.free_count) * page
        stats.used = stats.app + stats.wired + stats.compressed

        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 {
            stats.swapUsed = swap.xsu_used
            stats.swapTotal = swap.xsu_total
        }
        return stats
    }
}
