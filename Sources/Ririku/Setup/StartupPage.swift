import SwiftUI

struct StartupPage: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
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
        }
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
}
