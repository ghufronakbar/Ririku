import AppKit
import SwiftUI

/// Access to something macOS protects, such as the calendars or the camera. Widgets that need it ask only when the
/// user adds them, and once denied they point to System Settings instead of asking again (R-WID-3).
enum PermissionState {
    case notDetermined, granted, denied
}

enum PrivacySettings {
    static let calendars = "Privacy_Calendars"
    static let camera = "Privacy_Camera"

    /// Opens Privacy & Security in System Settings at the given list.
    static func open(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?" + pane) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// What a widget shows while it has no access: why, and one button to ask or to open System Settings.
struct PermissionPrompt: View {
    @ObservedObject var model: AppModel
    let state: PermissionState
    let message: String
    let pane: String
    let request: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            Text(message).font(.caption).foregroundStyle(.white.opacity(0.75)).lineLimit(3).fixedSize(horizontal: false, vertical: true)
            Button { state == .denied ? PrivacySettings.open(pane) : request() } label: {
                Text(state == .denied ? model.t("Open System Settings") : model.t("Allow Access")).lineLimit(1).minimumScaleFactor(0.7)
            }
            .buttonStyle(.plain)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Capsule().fill(.white.opacity(0.14)))
        }
    }
}

private struct PanelPreviewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True in Setup's preview of the panel, where the camera stays off (R-WID-5).
    var panelPreview: Bool {
        get { self[PanelPreviewKey.self] }
        set { self[PanelPreviewKey.self] = newValue }
    }
}
