import SwiftUI
import RirikuCore

struct SetupView: View {
    @ObservedObject var model: AppModel
    @State private var lyricSearchText = ""

    var body: some View {
        Form {
            Section(model.t("Language")) {
                Picker(model.t("Interface language"), selection: $model.interfaceLanguage) {
                    Text(model.t("Follow system (%@)", InterfaceLanguage.nativeName(of: InterfaceLanguage.system.resolvedCode))).tag(InterfaceLanguage.system)
                    ForEach([InterfaceLanguage.en, .id, .ja]) { language in
                        Text(InterfaceLanguage.nativeName(of: language.rawValue)).tag(language)
                    }
                }
                Text(model.t("Changes apply immediately. Song titles, lyrics, captions, and messages from macOS or websites keep their original language."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(model.t("Browser connection")) {
                let _ = model.browserSetupRevision
                let browsers = BrowserSetup.installedBrowsers()
                let hostStatus = registrationStatus(browsers)
                Text(model.t("Ririku follows YouTube and YouTube Music through a companion extension in a Chromium browser: Chrome, Brave, Edge, Vivaldi, Opera, Chromium, or Arc. Complete these steps once."))
                    .font(.caption).foregroundStyle(.secondary)
                if BrowserSetup.isTranslocated {
                    Text(model.t("Move Ririku to the Applications folder and open it again before connecting a browser.")).foregroundStyle(.orange)
                }
                setupStep(1, model.t("Register the browser connection"), detail: registrationText(browsers, hostStatus), done: hostStatus == .registered) {
                    Button(hostStatus == .registered ? model.t("Register Again") : model.t("Register")) { model.connectBrowsers() }
                        .disabled(browsers.isEmpty || hostStatus == .unavailable || hostStatus == .translocated)
                }
                setupStep(2, model.t("Copy the extension folder"), detail: extensionCopyText, done: extensionCopyCurrent) {
                    Button(model.t("Show in Finder")) { model.showExtensionFolder() }.disabled(BrowserSetup.bundledExtensionURL == nil)
                }
                setupStep(3, model.t("Load the extension in your browser"), detail: model.t("Open the extensions page, turn on Developer mode, click Load unpacked, and choose the “Chrome Extension” folder."), done: model.connectedExtensionVersion != nil) {
                    if browsers.count > 1 {
                        Menu(model.t("Copy Address")) {
                            ForEach(browsers) { browser in
                                Button(browser.extensionsPage) { model.copyExtensionsPage(for: browser) }
                            }
                        }.fixedSize()
                    } else {
                        Button(model.t("Copy Address")) { model.copyExtensionsPage(for: browsers.first ?? Browser.all[0]) }
                    }
                }
                setupStep(4, model.t("Check the connection"), detail: connectionText, done: connectionCurrent) { EmptyView() }
                if let message = model.browserSetupMessage {
                    Text(model.t(message)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section(model.t("Startup")) {
                let _ = model.loginItemRevision
                let loginState = LoginItem.state()
                Toggle(model.t("Open Ririku at login"), isOn: Binding(get: { loginState == .on }, set: { model.setLaunchAtLogin($0) }))
                    .disabled(loginState == .unavailable || loginState == .translocated)
                Text(loginItemText(loginState)).font(.caption).foregroundStyle(.secondary)
                if loginState == .needsApproval {
                    Button(model.t("Open Login Items settings")) { model.openLoginItemsSettings() }
                }
                if let message = model.loginItemMessage {
                    Text(model.t(message)).font(.caption).foregroundStyle(.orange)
                }
            }
            Section(model.t("Music source")) {
                Toggle(model.t("Automatically follow the active player"), isOn: $model.automaticSource).disabled(model.demo)
                Picker(model.t("Active player"), selection: $model.selectedSource) {
                    Text(model.t("Choose a player tab")).tag("")
                    if !model.selectedSource.isEmpty && model.sessions[model.selectedSource] == nil {
                        Text(model.t("Waiting for the source to reconnect")).tag(model.selectedSource)
                    }
                    ForEach(model.sessions.values.filter { $0.id != "demo:demo" }.sorted { $0.id < $1.id }, id: \.id) { entry in
                        Text(verbatim: "\(model.sourceLabel(for: entry.snapshot)) · \(entry.snapshot.title)").tag(entry.id)
                    }
                }.disabled(model.demo || model.automaticSource)
                Text(model.t("Automatic mode follows the tab that starts playing and restores the connection. Turn it off to lock one tab manually."))
                    .font(.caption).foregroundStyle(.secondary)
                Text(model.t("Apple Music and Spotify: not implemented yet.")).font(.caption).foregroundStyle(.secondary)
                if let error = model.bridgeError { Text(model.t(error)).foregroundStyle(.red) }
            }
            Section(model.t("Appearance")) {
                HStack {
                    Text(model.t("Compact island width"))
                    Slider(value: $model.compactWidth, in: 280...620, step: 2)
                    Text(verbatim: "\(Int(model.compactWidth)) pt").monospacedDigit().frame(width: 60)
                }
                HStack {
                    Text(model.t("Expanded island width"))
                    Slider(value: $model.panelWidth, in: 360...720, step: 2)
                    Text(verbatim: "\(Int(model.panelWidth)) pt").monospacedDigit().frame(width: 60)
                }
                Text(model.t("Minimum size follows the physical notch. Height adapts to content and line count."))
                    .font(.caption).foregroundStyle(.secondary)
                Button(model.t("Reset size")) { model.compactWidth = 360; model.panelWidth = 442 }
                Picker(model.t("Accent color"), selection: $model.accentName) {
                    Text(model.t("Peach")).tag("Peach")
                    Text(model.t("Lavender")).tag("Lavender")
                    Text(model.t("Neutral")).tag("Netral")
                }
                Toggle(model.t("Smooth panel transitions (ease-in/ease-out)"), isOn: $model.animations)
                Toggle(model.t("Show lyrics in the island"), isOn: $model.showLyrics)
                Picker(model.t("Lyric lines"), selection: $model.lyricLineCount) {
                    Text(model.t("1 · current")).tag(1)
                    Text(model.t("2 · current + next")).tag(2)
                    Text(model.t("3 · previous + current + next")).tag(3)
                }.disabled(!model.showLyrics)
                Text(model.t("Applies to compact and expanded islands. The spectrum is decorative, not audio analysis, and settles when paused or stopped. The animation toggle and Reduce Motion also control it."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(model.t("Lyrics")) {
                Toggle(model.t("Prefer Japanese on shared timestamps"), isOn: $model.preferJapaneseLyrics)
                Text(model.t("Latin lines that share an exact timestamp with Japanese are hidden from display, not deleted. Other-language lines at different times and mixed text stay intact. Turn it off to see every variant, including simultaneous bilingual duets."))
                    .font(.caption).foregroundStyle(.secondary)
                Picker(model.t("Lyrics source"), selection: $model.lyricSource) {
                    Text(model.t("Automatic · LRCLIB, then captions")).tag("auto")
                    Text(model.t("LRCLIB / LRC only")).tag("lrclib")
                    Text(model.t("YouTube subtitles only")).tag("caption")
                }
                Toggle(model.t("Search LRCLIB automatically when the song changes"), isOn: $model.automaticLyrics).disabled(model.lyricSource == "caption")
                Text(lyricSourceStatus).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(model.t("Back to automatic result")) { model.retryMedia() }.disabled(model.trackKey == nil || !model.automaticLyrics || model.lyricSource == "caption")
                    Button(model.t("Import LRC…")) { model.importLyrics() }.disabled(model.trackKey == nil || model.lyricSource == "caption")
                }
                Text(model.trackKey.flatMap { model.lyricNames[$0] }.map { model.t($0) } ?? model.t("No lyrics selected yet")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack {
                    Text(model.t("Offset for this song"))
                    Slider(value: Binding(get: { model.lyricOffset }, set: { model.lyricOffset = $0 }), in: -60...60, step: 0.1)
                    Text(model.t("%@ s", seconds(model.lyricOffset, signed: true))).monospacedDigit().frame(width: 72)
                    Button(model.t("Reset")) { model.lyricOffset = 0 }
                }.disabled(model.trackKey == nil || model.lyricSource == "caption" || model.usesVideoCaption)
                HStack {
                    Button(model.t("Earlier by %@ s", seconds(0.1, signed: false))) { model.lyricOffset -= 0.1 }
                    Button(model.t("Later by %@ s", seconds(0.1, signed: false))) { model.lyricOffset += 0.1 }
                }.disabled(model.trackKey == nil || model.lyricSource == "caption" || model.usesVideoCaption)
                Text(model.t("Offset is saved per video or song; positive values delay lyrics, negative values advance them. Not applied to CC. Duration is used to choose candidates, not to stretch timestamps automatically."))
                    .font(.caption).foregroundStyle(.secondary)
                DisclosureGroup(model.t("Search and choose a lyrics version")) {
                    HStack {
                        TextField(model.t("Title, artist, or song alias"), text: $lyricSearchText)
                            .onSubmit { model.searchLyrics(lyricSearchText) }
                        Button(model.lyricSearchBusy ? model.t("Searching…") : model.t("Search")) { model.searchLyrics(lyricSearchText) }
                            .disabled(model.lyricSearchBusy)
                    }
                    Text(model.t("Player duration: %@ · results sorted by smallest duration difference.", durationLabel(model.current?.snapshot.duration)))
                        .font(.caption).foregroundStyle(.secondary)
                    if let status = model.lyricSearchStatus {
                        Text(model.t(status)).font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(model.lyricCandidates, id: \.id) { record in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: "\(record.trackName) — \(record.artistName)").font(.callout).lineLimit(2)
                                Text(verbatim: "\(record.albumName ?? model.t("Unknown album")) · #\(record.id)").font(.caption).foregroundStyle(.secondary)
                                Text(verbatim: "\(durationLabel(record.duration)) · \(differenceLabel(record.duration)) · \(recordKind(record))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(model.t("Use")) { model.selectLyrics(record) }
                                .disabled(!record.instrumental && !record.hasValidSyncedLyrics && (record.plainLyrics?.isEmpty ?? true))
                        }.padding(.vertical, 4)
                    }
                    Text(model.t("Check the artist and recording version. A large difference can mean an intro, live, cover, or different song. Manual choices last while the app is open."))
                        .font(.caption).foregroundStyle(.secondary)
                }.disabled(model.lyricSource == "caption" || model.trackKey == nil)
                if let error = model.commandError { Text(model.t(error)).font(.caption).foregroundStyle(.orange) }
            }
            Section(model.t("Prototype")) {
                Text(verbatim: "Ririku 0.3.1 · Native macOS").font(.caption).foregroundStyle(.secondary)
                Toggle(model.t("Local demo (no audio)"), isOn: $model.demo)
                Text(model.t("No telemetry or cookies. Song metadata is sent to LRCLIB when automatic search is on; the Search button sends your search terms. Subtitles-only mode does not query LRCLIB. Thumbnails come from YouTube/Google image servers."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .environment(\.locale, model.locale)
        .frame(width: 580, height: 700)
        .onAppear { resetSearch() }
        .onChange(of: model.lyricSearchIdentity) { _, _ in resetSearch() }
    }

    private func setupStep<Control: View>(_ number: Int, _ title: String, detail: String, done: Bool, @ViewBuilder control: () -> Control) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle")
                .foregroundStyle(done ? Color.green : Color.secondary).font(.title3).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            control()
        }
        .accessibilityElement(children: .combine)
    }

    /// One row covers every installed browser, so the worst status decides what step 1 shows.
    private func registrationStatus(_ browsers: [Browser]) -> BrowserSetup.HostStatus {
        let statuses = browsers.map(BrowserSetup.hostStatus(for:))
        for status in [BrowserSetup.HostStatus.unavailable, .translocated, .needsUpdate, .notRegistered] where statuses.contains(status) {
            return status
        }
        return statuses.isEmpty ? .notRegistered : .registered
    }

    private func registrationText(_ browsers: [Browser], _ status: BrowserSetup.HostStatus) -> String {
        if browsers.isEmpty {
            return model.t("No supported browser found. Ririku works with Chrome, Brave, Edge, Vivaldi, Opera, Chromium, and Arc.")
        }
        switch status {
        case .unavailable: return model.t("Available only when Ririku runs from its app bundle.")
        case .translocated: return model.t("Blocked until Ririku is moved to Applications.")
        case .needsUpdate: return model.t("Registered for another copy of Ririku. Register again.")
        case .registered: return model.t("Registered for %@.", names(browsers))
        case .notRegistered:
            let pending = browsers.filter { BrowserSetup.hostStatus(for: $0) != .registered }
            guard pending.count < browsers.count else { return model.t("Not registered yet. Found %@.", names(browsers)) }
            return model.t("Registered for %@. Not registered: %@.", names(browsers.filter { !pending.contains($0) }), names(pending))
        }
    }

    private func names(_ browsers: [Browser]) -> String {
        ListFormatter.localizedString(byJoining: browsers.map(\.name))
    }

    private func loginItemText(_ state: LoginItem.State) -> String {
        switch state {
        case .unavailable: return model.t("Available only when Ririku runs from its app bundle.")
        case .translocated: return model.t("Blocked until Ririku is moved to Applications.")
        case .off: return model.t("Ririku stays closed until you open it yourself.")
        case .on: return model.t("Ririku opens in the background after you log in.")
        case .needsApproval: return model.t("macOS is waiting for your approval. Turn Ririku on in System Settings → General → Login Items.")
        }
    }

    private var extensionCopyCurrent: Bool {
        guard let installed = BrowserSetup.installedExtensionVersion else { return false }
        return installed == BrowserSetup.bundledExtensionVersion
    }

    private var extensionCopyText: String {
        guard let bundled = BrowserSetup.bundledExtensionVersion else { return model.t("Available only when Ririku runs from its app bundle.") }
        guard let installed = BrowserSetup.installedExtensionVersion else { return model.t("Not copied yet.") }
        return installed == bundled ? model.t("Copied version %@. Choose this folder in your browser.", installed)
            : model.t("Copied version %@ is outdated. Show it in Finder to update it, then click the extension's reload button in your browser.", installed)
    }

    private var connectionCurrent: Bool {
        guard let connected = model.connectedExtensionVersion else { return false }
        return BrowserSetup.bundledExtensionVersion.map { $0 == connected } ?? true
    }

    private var connectionText: String {
        guard let connected = model.connectedExtensionVersion else {
            return model.t("Not connected. After loading the extension, refresh an open YouTube or YouTube Music tab.")
        }
        if let bundled = BrowserSetup.bundledExtensionVersion, bundled != connected {
            return model.t("Extension %@ is connected, but Ririku includes %@. Show the folder in Finder to update it, then click the extension's reload button in your browser.", connected, bundled)
        }
        guard let browser = model.connectedBrowser else { return model.t("Connected · extension %@", connected) }
        return model.t("Connected · %1$@ · extension %2$@", browser, connected)
    }

    private var lyricSourceStatus: String {
        if model.usesVideoCaption { return model.t("Video captions active · following player CC") }
        if model.lyricSource == "caption" { return model.lyricStatus }
        return model.trackKey.flatMap { model.lyricMessages[$0] }.map { model.t($0) } ?? model.t("Lyrics are searched when a song starts playing.")
    }

    private func resetSearch() {
        model.cancelLyricSearch()
        lyricSearchText = model.suggestedLyricSearch
    }

    private func seconds(_ value: Double, signed: Bool) -> String {
        let style = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1)).locale(model.locale)
        return signed ? value.formatted(style.sign(strategy: .always())) : value.formatted(style)
    }

    private func recordKind(_ record: LyricsRecord) -> String {
        record.instrumental ? model.t("Instrumental") : record.hasValidSyncedLyrics ? model.t("Timestamped") : model.t("Text only")
    }

    private func durationLabel(_ duration: Double?) -> String {
        guard let duration, duration.isFinite, duration > 0, duration < 86400 else { return model.t("unknown") }
        let seconds = Int(duration.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func differenceLabel(_ duration: Double?) -> String {
        guard let duration, duration.isFinite, duration > 0, let playback = model.current?.snapshot.duration else { return model.t("difference unknown") }
        let difference = seconds(duration - playback, signed: true)
        return abs(duration - playback) > 3 ? model.t("difference %@ s · check version", difference) : model.t("difference %@ s", difference)
    }
}
