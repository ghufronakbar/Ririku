import Darwin
import Foundation
import RirikuCore

/// Measures download and upload speed while a Network widget is visible, and stops when none is (R-WID-4).
@MainActor
final class NetworkMonitor: ObservableObject {
    static let interval: TimeInterval = 2
    static let historyLength = 30

    /// Bytes per second; nil until two samples exist.
    @Published private(set) var received: Double?
    @Published private(set) var sent: Double?
    @Published private(set) var receivedHistory: [Double] = []
    @Published private(set) var sentHistory: [Double] = []

    private var viewers = 0
    private var timer: Timer?
    private var lastCounters: [String: NetworkStats.Counters] = [:]
    private var lastSample: TimeInterval = 0

    func start() {
        viewers += 1
        guard viewers == 1 else { return }
        lastCounters = Self.readCounters()
        lastSample = ProcessInfo.processInfo.systemUptime
        received = nil
        sent = nil
        let timer = Timer(fire: Date(timeIntervalSinceNow: 1), interval: Self.interval, repeats: true) { [weak self] _ in
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
        receivedHistory = []
        sentHistory = []
    }

    private func sample() {
        let counters = Self.readCounters()
        let now = ProcessInfo.processInfo.systemUptime
        if let rates = NetworkStats.rates(from: lastCounters, to: counters, seconds: now - lastSample) {
            received = rates.received
            sent = rates.sent
            receivedHistory = Array((receivedHistory + [rates.received]).suffix(Self.historyLength))
            sentHistory = Array((sentHistory + [rates.sent]).suffix(Self.historyLength))
        }
        lastCounters = counters
        lastSample = now
    }

    /// Byte counters of the Wi-Fi and Ethernet interfaces that are up. Tunnels such as VPNs are left out,
    /// because their traffic also passes through a physical interface and would be counted twice.
    private static func readCounters() -> [String: NetworkStats.Counters] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [:] }
        defer { freeifaddrs(list) }
        var result: [String: NetworkStats.Counters] = [:]
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(entry.pointee.ifa_flags)
            guard let address = entry.pointee.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
                  flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0, let data = entry.pointee.ifa_data else { continue }
            let name = String(cString: entry.pointee.ifa_name)
            guard name.hasPrefix("en") else { continue }
            let stats = data.assumingMemoryBound(to: if_data.self).pointee
            result[name] = NetworkStats.Counters(received: stats.ifi_ibytes, sent: stats.ifi_obytes)
        }
        return result
    }
}
