import SwiftUI

struct DecorativeSpectrum: View {
    let playing: Bool
    let animate: Bool
    let color: Color
    let playingLabel: String
    let pausedLabel: String
    let helpText: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var running: Bool { playing && animate && !reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !running)) { context in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<5) { band in
                    Capsule()
                        .fill(color)
                        .frame(width: 2, height: height(band: band, time: context.date.timeIntervalSinceReferenceDate))
                }
            }
            .frame(width: 24, height: 24)
            .animation(animate && !reduceMotion ? .easeOut(duration: 0.28) : nil, value: running)
        }
        .accessibilityLabel(playing ? playingLabel : pausedLabel)
        .help(helpText)
    }

    private func height(band: Int, time: Double) -> Double {
        guard running else { return 2 }
        let phase = time.truncatingRemainder(dividingBy: 120)
        let wave = (sin(phase * (3 + Double(band) * 0.37) + Double(band) * 1.3) + 1) / 2
        return 4 + wave * (band == 2 ? 18 : 13)
    }
}
