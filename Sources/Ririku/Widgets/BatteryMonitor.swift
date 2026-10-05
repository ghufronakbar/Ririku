import Foundation
import IOKit.ps

/// The internal battery's charge, read from IOKit power sources. While the Battery widget is on a page, macOS tells
/// it when the power source changes, so the charging notice needs no polling (R-WID-4).
@MainActor
final class BatteryMonitor: ObservableObject {
    struct Reading: Equatable {
        var fraction: Double
        var charging: Bool
        var onPower: Bool
        var charged: Bool
        /// Minutes, while macOS has an estimate.
        var minutesToEmpty: Int?
        var minutesToFull: Int?
    }

    @Published private(set) var reading: Reading?
    /// Called with the previous and the new reading when the power source changes.
    var changed: ((Reading?, Reading?) -> Void)?
    private var source: CFRunLoopSource?

    /// Listens for power source changes while `active`.
    func setActive(_ active: Bool) {
        if active, source == nil {
            let context = Unmanaged.passUnretained(self).toOpaque()
            source = IOPSNotificationCreateRunLoopSource({ context in
                guard let context else { return }
                let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
                // IOKit calls back on the run loop the source was added to, the main one.
                MainActor.assumeIsolated { monitor.refresh() }
            }, context)?.takeRetainedValue()
            if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode) }
            reading = Self.read()
        } else if !active, let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode)
            self.source = nil
        }
    }

    func refresh() {
        let previous = reading
        reading = Self.read()
        if previous != reading { changed?(previous, reading) }
    }

    /// nil on a Mac without an internal battery.
    private static func read() -> Reading? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = max(1, description[kIOPSMaxCapacityKey] as? Int ?? 100)
            // Negative times mean macOS is still calculating.
            let toEmpty = (description[kIOPSTimeToEmptyKey] as? Int).flatMap { $0 > 0 ? $0 : nil }
            let toFull = (description[kIOPSTimeToFullChargeKey] as? Int).flatMap { $0 > 0 ? $0 : nil }
            return Reading(fraction: min(1, Double(current) / Double(maximum)),
                           charging: description[kIOPSIsChargingKey] as? Bool ?? false,
                           onPower: description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                           charged: description[kIOPSIsChargedKey] as? Bool ?? false,
                           minutesToEmpty: toEmpty, minutesToFull: toFull)
        }
        return nil
    }
}
