import SwiftUI

struct PlayerView: View {
    @ObservedObject var model: AppModel
    var hoverChanged: (Bool) -> Void
    @State private var scrubbing = false
    @State private var seekPosition = 0.0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if model.current != nil { artwork(size: 24) }
                Spacer(minLength: model.notchWidth)
                if model.current != nil {
                    Image(systemName: model.current?.snapshot.state == "playing" ? "waveform" : "pause.fill")
                        .foregroundStyle(model.accent).frame(width: 24)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: model.topHeight)
            if model.expanded {
                expandedContent.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 20)
            } else if model.showLyrics && model.current != nil {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    Text(model.lyricStatus).font(.system(size: 13, weight: .medium))
                        .foregroundStyle(model.accent).lineLimit(1).padding(.horizontal, 18).frame(height: 34)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .background(.black)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: model.expanded ? 26 : 16, bottomTrailingRadius: model.expanded ? 26 : 16))
        .contentShape(Rectangle())
        .onHover(perform: hoverChanged)
        .onTapGesture { model.expanded = true }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notch Box, pemutar musik")
    }

    private var expandedContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                artwork(size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.current?.snapshot.title ?? "Notch Box").font(.headline).lineLimit(1)
                    Text(model.current?.snapshot.artist ?? "Menunggu pemutar Chrome").font(.caption).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                    Text(model.current?.snapshot.sourceLabel ?? "Belum terhubung").font(.caption2).foregroundStyle(model.accent).lineLimit(1)
                }
                Spacer(minLength: 0)
                Button { model.openSetup?() } label: { Image(systemName: "gearshape").padding(8) }
                    .buttonStyle(.plain).help("Buka Setup").accessibilityLabel("Buka jendela Setup")
            }
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                VStack(spacing: 12) {
                    lyricBlock.frame(height: 74)
                    VStack(spacing: 2) {
                        Slider(value: Binding(get: { scrubbing ? seekPosition : model.position() }, set: { seekPosition = $0 }),
                               in: 0...max(1, model.current?.snapshot.duration ?? 1), onEditingChanged: { editing in
                            scrubbing = editing
                            if !editing { model.command("seek", position: seekPosition) }
                        })
                        .tint(model.accent)
                        .disabled(!model.canControl || model.current?.snapshot.capabilities.seek != true)
                        .accessibilityLabel("Posisi pemutaran")
                        HStack {
                            Text(time(scrubbing ? seekPosition : model.position()))
                            Spacer()
                            Text(model.current?.snapshot.duration.map(time) ?? "LIVE")
                        }.font(.caption2).monospacedDigit().foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            HStack(spacing: 28) {
                transport("backward.end.fill", label: "Lagu sebelumnya", action: "previous", enabled: model.current?.snapshot.capabilities.previous == true)
                transport(model.current?.snapshot.state == "playing" ? "pause.fill" : "play.fill", label: "Putar atau jeda", action: "toggle", enabled: model.current?.snapshot.capabilities.playPause == true)
                transport("forward.end.fill", label: "Lagu berikutnya", action: "next", enabled: model.current?.snapshot.capabilities.next == true)
            }
            if let error = model.commandError {
                Text(error).font(.caption2).foregroundStyle(.orange).lineLimit(2)
            }
        }
    }

    private var lyricBlock: some View {
        VStack(spacing: 6) {
            if model.usesVideoCaption {
                Text("Caption video").font(.caption2).foregroundStyle(.white.opacity(0.45))
                Text(model.lyricStatus).foregroundStyle(model.accent).lineLimit(2)
            } else if let index = model.lyricIndex(), !model.currentLines.isEmpty {
                Text(index > 0 ? model.currentLines[index - 1].text : " ").foregroundStyle(.white.opacity(0.45))
                Text(model.lyricStatus).foregroundStyle(model.accent).fontWeight(.medium)
                Text(index + 1 < model.currentLines.count ? model.currentLines[index + 1].text : " ").foregroundStyle(.white.opacity(0.45))
            } else if let plain = model.currentPlainLyrics {
                Text("Lirik teks · tanpa timing").font(.caption2).foregroundStyle(model.accent)
                ScrollView { Text(plain).lineLimit(nil).foregroundStyle(.white.opacity(0.85)).frame(maxWidth: .infinity) }
            } else { Text(model.lyricStatus).foregroundStyle(.white.opacity(0.65)) }
        }.font(.system(size: 13)).lineLimit(1).frame(maxWidth: .infinity)
    }

    private func transport(_ icon: String, label: String, action: String, enabled: Bool) -> some View {
        Button { model.command(action) } label: {
            Image(systemName: icon).font(.system(size: 18)).frame(width: 40, height: 36)
        }.buttonStyle(.plain).disabled(!model.canControl || !enabled).accessibilityLabel(label)
    }

    private func artwork(size: CGFloat) -> some View {
        Group {
            if let image = model.artwork {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: size / 5)
                    .fill(LinearGradient(colors: [model.accent.opacity(0.9), Color(red: 0.18, green: 0.25, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Image(systemName: "music.note").font(.system(size: size * 0.4)).foregroundStyle(.white))
            }
        }.frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size / 5)).accessibilityHidden(true)
    }

    private func time(_ value: Double) -> String {
        let seconds = max(0, Int(value))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
