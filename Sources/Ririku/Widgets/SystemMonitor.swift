import Darwin
import Foundation
import RirikuCore

/// Samples processor, memory, and disk use while at least one System widget is visible, and stops when none is (R-WID-4).
@MainActor
final class SystemMonitor: ObservableObject {
    static let interval: TimeInterval = 2
    /// Disk use changes slowly, so it is read on every 15th sample (30 s).
    private static let diskEvery = 15

    @Published private(set) var cpu: Double?
    @Published private(set) var memoryUsed: UInt64 = 0
    @Published private(set) var diskUsed: UInt64 = 0
    @Published private(set) var diskTotal: UInt64 = 0
    let memoryTotal = ProcessInfo.processInfo.physicalMemory
    let processorCount = ProcessInfo.processInfo.activeProcessorCount

    private let host = mach_host_self()
    private var viewers = 0
    private var timer: Timer?
    private var lastTicks: CPUTicks?
    private var samples = 0

    var memoryFraction: Double { SystemStats.fraction(memoryUsed, of: memoryTotal) }
    var diskFraction: Double { SystemStats.fraction(diskUsed, of: diskTotal) }

    func start() {
        viewers += 1
        guard viewers == 1 else { return }
        // A fresh baseline, so the first value does not average the time nothing was shown.
        lastTicks = readTicks()
        samples = 0
        cpu = nil
        readMemory()
        readDisk()
        let timer = Timer(fire: Date(timeIntervalSinceNow: 0.5), interval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sample() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        samples += 1
        if let ticks = readTicks() {
            if let lastTicks, let usage = SystemStats.cpuUsage(from: lastTicks, to: ticks) { cpu = usage }
            lastTicks = ticks
        }
        readMemory()
        if samples % Self.diskEvery == 0 { readDisk() }
    }

    private func readTicks() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
    }

    private func readMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, HOST_VM_INFO64, $0, &count) }
        }
        var pageSize: vm_size_t = 0
        guard result == KERN_SUCCESS, host_page_size(host, &pageSize) == KERN_SUCCESS else { return }
        memoryUsed = SystemStats.memoryUsed(internalPages: UInt64(stats.internal_page_count), purgeablePages: UInt64(stats.purgeable_count),
                                            wiredPages: UInt64(stats.wire_count), compressedPages: UInt64(stats.compressor_page_count),
                                            pageSize: UInt64(pageSize))
    }

    private func readDisk() {
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacityForImportantUsage else { return }
        diskTotal = UInt64(max(0, total))
        diskUsed = UInt64(max(0, Int64(total) - available))
    }
}
