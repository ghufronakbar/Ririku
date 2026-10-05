/// Processor time counters from `HOST_CPU_LOAD_INFO`, summed over all cores.
public struct CPUTicks: Equatable, Sendable {
    public var user: UInt32
    public var system: UInt32
    public var idle: UInt32
    public var nice: UInt32

    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

public enum SystemStats {
    /// Share of time the processors were busy between two samples, from 0 to 1; nil when fewer than `minimumTicks`
    /// passed. The kernel adds ticks in bursts about once a second, so a short gap may see none or only a few, which
    /// would give a wrong value. The counters are 32-bit, so the differences use wrapping subtraction.
    public static func cpuUsage(from old: CPUTicks, to new: CPUTicks, minimumTicks: Double = 1) -> Double? {
        let busy = Double(new.user &- old.user) + Double(new.system &- old.system) + Double(new.nice &- old.nice)
        let total = busy + Double(new.idle &- old.idle)
        guard total > 0, total >= minimumTicks else { return nil }
        return min(1, busy / total)
    }

    /// Memory in use the way Activity Monitor counts it: app memory (anonymous pages that are not purgeable),
    /// wired memory, and the compressor's pages.
    public static func memoryUsed(internalPages: UInt64, purgeablePages: UInt64, wiredPages: UInt64,
                                  compressedPages: UInt64, pageSize: UInt64) -> UInt64 {
        (internalPages - min(purgeablePages, internalPages) + wiredPages + compressedPages) * pageSize
    }

    /// `used` as a share of `total`, from 0 to 1.
    public static func fraction(_ used: UInt64, of total: UInt64) -> Double {
        total == 0 ? 0 : min(1, Double(used) / Double(total))
    }
}
