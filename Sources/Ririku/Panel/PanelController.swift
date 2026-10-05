import AppKit
import SwiftUI
import RirikuCore

final class NotchPanel: NSPanel {
    var dismissPanel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { dismissPanel?() }
}

/// Owns the notch panel: its place under the notch, the resize animation, and opening and closing by hover.
@MainActor
final class PanelController: NSObject {
    private let model: AppModel
    private let panel: NotchPanel
    private var hoverWork: DispatchWorkItem?
    /// Set when the menu opens the panel, so it stays open until the pointer has visited it.
    private var pinnedOpen = false
    private var pointerTimer: Timer?
    private var pointerLeftAt: TimeInterval?
    private var resizeTimer: Timer?
    private var targetPanelFrame: NSRect?

    init(model: AppModel) {
        self.model = model
        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.dismissPanel = { [weak self] in self?.collapse() }
        let hosting = NSHostingView(rootView: PanelView(model: model, hoverChanged: { [weak self] inside in self?.hover(inside) }))
        hosting.sizingOptions = []
        panel.contentView = hosting
        model.geometryChanged = { [weak self] in self?.position() }
        model.fileDragEntered = { [weak self] in self?.showTrayForDrag() }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(accessibilityChanged), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    func show() {
        position()
        panel.orderFrontRegardless()
    }

    /// Opened from the menu bar item, the panel takes focus and stays open until the pointer has visited it.
    func expandFromMenu() { pinnedOpen = true; model.expanded = true; panel.makeKeyAndOrderFront(nil) }

    /// A file dragged onto the notch opens the panel on the Tray, like hovering does. It closes once the pointer
    /// has left with no button held, so it stays open for the whole drag.
    func showTrayForDrag() {
        guard let tray = model.trayTab else { return }
        hoverWork?.cancel()
        pinnedOpen = false
        model.expanded = true
        model.selectedTabID = tray.id
        watchPointer()
    }

    /// The keyboard shortcut opens the panel like the menu item does, and closes it when it is open.
    func toggleFromShortcut() { model.expanded ? collapse() : expandFromMenu() }

    func stop() { resizeTimer?.invalidate() }

    @objc private func screenChanged() { model.screensChanged(); position(animate: false) }
    @objc private func accessibilityChanged() { model.objectWillChange.send(); position(animate: false) }

    private func position(animate: Bool = true) {
        let displays = ConnectedDisplay.all()
        guard let index = PanelDisplay.choose(preferred: model.panelDisplayID, from: displays.map(\.candidate)) else { return }
        let screen = displays[index].screen
        let top = max(32, screen.safeAreaInsets.top)
        let notch: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea, right.minX > left.maxX {
            notch = right.minX - left.maxX
        } else { notch = 180 }
        if model.notchWidth != notch { model.notchWidth = notch }
        if model.topHeight != top { model.topHeight = top }
        let size = model.panelSize(screenWidth: screen.frame.width)
        let width = size.width
        let height = size.height
        let frame = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height, width: width, height: height)
        if !animate || !model.canAnimate || !panel.isVisible {
            resizeTimer?.invalidate()
            resizeTimer = nil
            targetPanelFrame = frame
            panel.setFrame(frame, display: true)
            return
        }
        guard targetPanelFrame != frame else { return }
        targetPanelFrame = frame
        resizeTimer?.invalidate()
        let start = panel.frame
        let startedAt = ProcessInfo.processInfo.systemUptime
        let duration = model.popupDuration
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                let progress = min(1, (ProcessInfo.processInfo.systemUptime - startedAt) / duration)
                self.panel.setFrame(IslandMotion.frame(from: start, to: frame, progress: progress), display: true)
                if progress >= 1 {
                    timer.invalidate()
                    self.resizeTimer = nil
                }
            }
        }
        resizeTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func hover(_ inside: Bool) {
        hoverWork?.cancel()
        if inside {
            pinnedOpen = false
            // The tap comes as the pointer arrives, while the finger is still moving on the trackpad: macOS drops
            // haptic feedback once the finger is lifted, which a quick swipe to the notch does before the open delay ends.
            if !model.expanded && model.hapticFeedback {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            }
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if inside {
                self.model.expanded = true
                self.watchPointer()
            } else if !self.pointerIsInside {
                self.collapse()
            }
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (inside ? model.hoverOpenDelay : model.hoverCloseDelay), execute: work)
    }

    /// Clicking a control makes the panel key and SwiftUI can miss the exit while the content changes
    /// (for example after pausing), so the pointer position decides when a hover-opened panel closes.
    private var pointerIsInside: Bool {
        pinnedOpen || NSEvent.pressedMouseButtons != 0 || panel.frame.contains(NSEvent.mouseLocation)
    }

    private func watchPointer() {
        pointerTimer?.invalidate()
        pointerLeftAt = nil
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, self.model.expanded else { timer.invalidate(); return }
                let now = ProcessInfo.processInfo.systemUptime
                if self.pointerIsInside { self.pointerLeftAt = nil; return }
                let leftAt = self.pointerLeftAt ?? now
                self.pointerLeftAt = leftAt
                if now - leftAt >= self.model.hoverCloseDelay { self.collapse() }
            }
        }
        pointerTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func collapse() {
        hoverWork?.cancel()
        pointerTimer?.invalidate()
        pointerTimer = nil
        pinnedOpen = false
        if panel.isKeyWindow { panel.resignKey() }
        model.expanded = false
    }
}
