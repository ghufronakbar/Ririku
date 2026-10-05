import AppKit
import SwiftUI
import RirikuCore

struct KeyboardPage: View {
    @ObservedObject var model: AppModel
    @State private var monitor: Any?
    @State private var hint: UIText?

    var body: some View {
        Form {
            Section(model.t("Keyboard")) {
                HStack {
                    Text(model.t("Open or close the panel"))
                    Spacer()
                    Button(model.recordingShortcut ? model.t("Press a shortcut…") : model.panelShortcut?.label ?? model.t("Record Shortcut")) {
                        model.recordingShortcut ? stopRecording() : startRecording()
                    }
                    .monospacedDigit()
                    if model.panelShortcut != nil && !model.recordingShortcut {
                        Button(model.t("Clear")) { model.panelShortcut = nil }
                    }
                }
                Text(model.t("Off until you record one. Use Command, Option, or Control with another key; Esc cancels. No Accessibility permission is needed."))
                    .font(.caption).foregroundStyle(.secondary)
                if let hint { Text(model.t(hint)).font(.caption).foregroundStyle(.orange) }
                if let message = model.shortcutMessage { Text(model.t(message)).font(.caption).foregroundStyle(.orange) }
            }
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        hint = nil
        model.recordingShortcut = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            record(event)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if model.recordingShortcut { model.recordingShortcut = false }
    }

    private func record(_ event: NSEvent) {
        let modifiers = HotKeyCenter.modifiers(from: event.modifierFlags.intersection(.deviceIndependentFlagsMask))
        if event.keyCode == 53 && modifiers == 0 { stopRecording(); return }
        guard let key = HotKey.keyName(keyCode: UInt32(event.keyCode), characters: event.charactersIgnoringModifiers) else { return }
        let shortcut = HotKey(keyCode: UInt32(event.keyCode), modifiers: modifiers, key: key)
        guard shortcut.isValid else {
            hint = UIText("Use Command, Option, or Control together with another key.")
            return
        }
        hint = nil
        model.panelShortcut = shortcut
        stopRecording()
    }
}
