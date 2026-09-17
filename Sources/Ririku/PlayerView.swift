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
                    DecorativeSpectrum(playing: model.current?.snapshot.state == "playing" && model.current?.snapshot.isAdvertisement == false,
                                        animate: model.canAnimate, color: model.accent,
                                        playingLabel: model.t("Music playing · decorative spectrum"),
                                        pausedLabel: model.t("Music paused or stopped"),
                                        helpText: model.t("Decorative spectrum, not audio analysis"))
                }
            }
            .padding(.horizontal, 14)
            .frame(height: model.topHeight)
            .fixedSize(horizontal: false, vertical: true)
            if model.expanded {
                expandedContent.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 20)
            } else if model.islandLyricHeight > 0 && model.current != nil {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    islandLyrics.padding(.horizontal, 18).frame(height: model.islandLyricHeight)
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
        .accessibilityLabel(model.t("Ririku, music player"))
        .environment(\.locale, model.locale)
    }

    private var expandedContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                artwork(size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.current?.snapshot.title ?? "Ririku").font(.headline).lineLimit(1)
                    Text(model.current?.snapshot.artist ?? model.t("Waiting for Chrome player")).font(.caption).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                    Text(model.current.map { model.sourceLabel(for: $0.snapshot) } ?? model.t("Not connected")).font(.caption2).foregroundStyle(model.accent).lineLimit(1)
                }
                Spacer(minLength: 0)
                Button { model.openSetup?() } label: { Image(systemName: "gearshape").padding(8) }
                    .buttonStyle(.plain).help(model.t("Open Setup")).accessibilityLabel(model.t("Open Setup window"))
            }
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                VStack(spacing: 12) {
                    if model.islandLyricHeight > 0 { islandLyrics.frame(height: model.islandLyricHeight) }
                    VStack(spacing: 2) {
                        Slider(value: Binding(get: { scrubbing ? seekPosition : model.position() }, set: { seekPosition = $0 }),
                               in: 0...max(1, model.current?.snapshot.duration ?? 1), onEditingChanged: { editing in
                            scrubbing = editing
                            if !editing { model.command("seek", position: seekPosition) }
                        })
                        .tint(model.accent)
                        .disabled(!model.canControl || model.current?.snapshot.capabilities.seek != true)
                        .accessibilityLabel(model.t("Playback position"))
                        HStack {
                            Text(time(scrubbing ? seekPosition : model.position()))
                            Spacer()
                            Text(model.current?.snapshot.duration.map(time) ?? model.t("LIVE"))
                        }.font(.caption2).monospacedDigit().foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            HStack(spacing: 28) {
                transport("backward.end.fill", label: model.t("Previous track"), action: "previous", enabled: model.current?.snapshot.capabilities.previous == true)
                transport(model.current?.snapshot.state == "playing" ? "pause.fill" : "play.fill", label: model.t("Play or pause"), action: "toggle", enabled: model.current?.snapshot.capabilities.playPause == true)
                transport("forward.end.fill", label: model.t("Next track"), action: "next", enabled: model.current?.snapshot.capabilities.next == true)
            }
            if let error = model.commandError {
                Text(model.t(error)).font(.caption2).foregroundStyle(.orange).lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var islandLyrics: some View {
        if let notice = model.lyricNotice {
            Text(notice).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
        } else if model.hasIslandLyrics { lyricBlock }
    }

    private var lyricBlock: some View {
        VStack(spacing: 4) {
            if model.usesVideoCaption {
                Text(model.lyricStatus).foregroundStyle(model.accent).lineLimit(model.lyricLineCount)
                    .help(model.t("Video captions active; previous and next lines are not available from the player."))
            } else if let index = model.lyricIndex(), !model.currentLines.isEmpty {
                ScrollingLyricRows(lines: model.currentLines, activeIndex: index, lineCount: model.lyricLineCount,
                                   animate: model.canAnimate, accent: model.accent)
                    .id(model.lyricSearchIdentity)
            } else if let plain = model.currentPlainLyrics {
                ScrollView { Text(plain).lineLimit(nil).foregroundStyle(.white.opacity(0.85)).frame(maxWidth: .infinity) }
                    .help(model.t("Text lyrics without timing; there is no active line."))
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
