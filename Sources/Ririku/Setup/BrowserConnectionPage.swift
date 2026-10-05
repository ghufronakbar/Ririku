import SwiftUI
import RirikuCore

struct BrowserConnectionPage: View {
    @ObservedObject var model: AppModel
    @ObservedObject var music: MusicModel

    var body: some View {
        Form {
            Section(model.t("Browser connection")) {
                let _ = music.browserSetupRevision
                let browsers = BrowserSetup.installedBrowsers()
                let hostStatus = registrationStatus(browsers)
                Text(model.t("Ririku follows YouTube and YouTube Music through a companion extension in a Chromium browser: Chrome, Brave, Edge, Vivaldi, Opera, Chromium, or Arc. Complete these steps once."))
                    .font(.caption).foregroundStyle(.secondary)
                if BrowserSetup.isTranslocated {
                    Text(model.t("Move Ririku to the Applications folder and open it again before connecting a browser.")).foregroundStyle(.orange)
                }
                setupStep(1, model.t("Register the browser connection"), detail: registrationText(browsers, hostStatus), done: hostStatus == .registered) {
                    Button(hostStatus == .registered ? model.t("Register Again") : model.t("Register")) { music.connectBrowsers() }
                        .disabled(browsers.isEmpty || hostStatus == .unavailable || hostStatus == .translocated)
                }
                setupStep(2, model.t("Copy the extension folder"), detail: extensionCopyText, done: extensionCopyCurrent) {
                    Button(model.t("Show in Finder")) { music.showExtensionFolder() }.disabled(BrowserSetup.bundledExtensionURL == nil)
                }
                setupStep(3, model.t("Load the extension in your browser"), detail: model.t("Open the extensions page, turn on Developer mode, click Load unpacked, and choose the “Chrome Extension” folder."), done: music.connectedExtensionVersion != nil) {
                    if browsers.count > 1 {
                        Menu(model.t("Copy Address")) {
                            ForEach(browsers) { browser in
                                Button(browser.extensionsPage) { music.copyExtensionsPage(for: browser) }
                            }
                        }.fixedSize()
                    } else {
                        Button(model.t("Copy Address")) { music.copyExtensionsPage(for: browsers.first ?? Browser.all[0]) }
                    }
                }
                setupStep(4, model.t("Check the connection"), detail: connectionText, done: connectionCurrent) { EmptyView() }
                if let message = music.browserSetupMessage {
                    Text(model.t(message)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
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
        guard let connected = music.connectedExtensionVersion else { return false }
        return BrowserSetup.bundledExtensionVersion.map { $0 == connected } ?? true
    }

    private var connectionText: String {
        guard let connected = music.connectedExtensionVersion else {
            return model.t("Not connected. After loading the extension, refresh an open YouTube or YouTube Music tab.")
        }
        if let bundled = BrowserSetup.bundledExtensionVersion, bundled != connected {
            return model.t("Extension %@ is connected, but Ririku includes %@. Show the folder in Finder to update it, then click the extension's reload button in your browser.", connected, bundled)
        }
        guard let browser = music.connectedBrowser else { return model.t("Connected · extension %@", connected) }
        return model.t("Connected · %1$@ · extension %2$@", browser, connected)
    }
}
