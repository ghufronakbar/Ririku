import SwiftUI

/// Rows of the System widget, which fill a widget card.
enum SystemWidgetLayout {
    static let rowHeight: Double = 26
    static let rowSpacing: Double = 10
    static let height = WidgetCardLayout.height
}

/// Processor, memory, and disk use as bars. The wide widget also names the totals.
struct SystemWidgetView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var monitor: SystemMonitor
    let wide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SystemWidgetLayout.rowSpacing) {
            row(model.t("CPU"), fraction: monitor.cpu,
                detail: wide ? model.t("%@ cores", monitor.processorCount.formatted(.number.locale(model.locale))) : nil,
                previous: !monitor.cpuIsCurrent)
            row(model.t("Memory"), fraction: monitor.memoryFraction,
                detail: wide ? model.t("%1$@ of %2$@", gigabytes(monitor.memoryUsed, binary: true), gigabytes(monitor.memoryTotal, binary: true)) : nil)
            row(model.t("Disk"), fraction: monitor.diskTotal == 0 ? nil : monitor.diskFraction,
                detail: wide && monitor.diskTotal > 0 ? model.t("%1$@ of %2$@", gigabytes(monitor.diskUsed, binary: false), gigabytes(monitor.diskTotal, binary: false)) : nil)
        }
        .widgetCard()
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    /// `previous` dims a value from an earlier reading until a new one arrives.
    private func row(_ title: String, fraction: Double?, detail: String?, previous: Bool = false) -> some View {
        let value = fraction.map { $0.formatted(.percent.precision(.fractionLength(0)).locale(model.locale)) } ?? "–"
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title).font(.caption.weight(.semibold))
                if let detail { Text(detail).font(.caption2).foregroundStyle(.white.opacity(0.55)).lineLimit(1) }
                Spacer(minLength: 4)
                Text(value).font(.caption.monospacedDigit()).opacity(previous ? 0.45 : 1)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(model.accent).frame(width: proxy.size.width * (fraction ?? 0)).opacity(previous ? 0.45 : 1)
                }
            }
            .frame(height: 5)
        }
        .frame(height: SystemWidgetLayout.rowHeight)
        .animation(model.canAnimate ? .easeOut(duration: 0.2) : nil, value: previous)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue([value, previous && fraction != nil ? model.t("last reading") : nil, detail].compactMap { $0 }.joined(separator: ", "))
    }

    /// Memory in binary gigabytes and disks in decimal ones, as macOS reports them, to three significant digits.
    private func gigabytes(_ count: UInt64, binary: Bool) -> String {
        let value = Double(count) / (binary ? 1_073_741_824 : 1_000_000_000)
        return model.t("%@ GB", value.formatted(.number.precision(.significantDigits(1...3)).locale(model.locale)))
    }
}
