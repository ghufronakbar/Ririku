import SwiftUI

struct GeneralPage: View {
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
            Section(model.t("Icons")) {
                Toggle(model.t("Show in Dock"), isOn: $model.showInDock)
                Toggle(model.t("Show in the menu bar"), isOn: $model.showMenuBarIcon)
                if !model.showInDock && !model.showMenuBarIcon {
                    Text(model.t("Both icons are hidden. To come back to Setup, open Ririku again from Finder, Launchpad, or Spotlight, or click the gear in the expanded panel."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section(model.t("Panel")) {
                let _ = model.screenRevision
                let displays = ConnectedDisplay.all()
                Picker(model.t("Show the panel on"), selection: Binding(
                    get: { model.panelDisplayID },
                    set: { id in model.choosePanelDisplay(id: id, name: displays.first { $0.id == id }?.name) })) {
                    Text(model.t("Automatic")).tag(String?.none)
                    ForEach(displays) { display in
                        Text(verbatim: display.name).tag(Optional(display.id))
                    }
                    if let id = model.panelDisplayID, !displays.contains(where: { $0.id == id }) {
                        Text(model.t("%@ (not connected)", model.panelDisplayName ?? id)).tag(Optional(id))
                    }
                }
                Text(model.t("Automatic uses the display with a notch, otherwise the main display. On a display without a notch, the panel sits at the top center. A chosen display that is not connected falls back to automatic."))
                    .font(.caption).foregroundStyle(.secondary)
                delaySlider(model.t("Delay before opening"), value: $model.hoverOpenDelay, in: AppModel.hoverOpenDelayRange)
                delaySlider(model.t("Delay before closing"), value: $model.hoverCloseDelay, in: AppModel.hoverCloseDelayRange)
                Text(model.t("How long the pointer rests on the notch before the panel opens, and how long it stays away before the panel closes. Clicking the island opens it at once."))
                    .font(.caption).foregroundStyle(.secondary)
                Toggle(model.t("Haptic feedback when the pointer reaches the notch"), isOn: $model.hapticFeedback)
                Text(model.t("A light tap as the pointer reaches the closed notch, even when it only passes by. It needs a Force Touch trackpad with Force Click and haptic feedback turned on in System Settings → Trackpad."))
                    .font(.caption).foregroundStyle(.secondary)
                if model.hapticFeedback {
                    Button(model.t("Open Trackpad settings")) { model.openTrackpadSettings() }
                }
            }
        }
    }

    private func delaySlider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title)
            // Snapped to 0.05 s in the binding rather than with `step`, which would draw dozens of tick marks.
            Slider(value: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = ($0 * 20).rounded() * 5 / 100 }), in: range)
            Text(model.t("%@ s", value.wrappedValue.formatted(.number.precision(.fractionLength(2)).locale(model.locale))))
                .monospacedDigit().frame(width: 60)
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
