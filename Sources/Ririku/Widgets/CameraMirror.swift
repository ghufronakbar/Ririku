@preconcurrency import AVFoundation
import AppKit
import SwiftUI

/// The camera mirror (D-020). Access is asked for when the widget is added (R-WID-3). The camera turns on only
/// after a click on the Camera widget in the open panel, and turns off when that widget disappears, because the
/// panel closed or the tab changed (R-WID-5). The picture is only shown: never recorded, saved, or sent.
@MainActor
final class CameraMirror: ObservableObject {
    enum Problem { case noCamera, stopped }

    @Published private(set) var access: PermissionState
    /// The widget that turned the camera on. Only it shows the picture, and the camera stops when it disappears.
    @Published private(set) var owner: UUID?
    @Published private(set) var problem: Problem?

    /// Made on first use, so nothing of the camera is set up until the widget is clicked.
    private(set) lazy var session = AVCaptureSession()
    private let queue = DispatchQueue(label: "io.github.lanstheprodigy.ririku.camera")
    private let status: () -> PermissionState
    private let requester: (() async -> Bool)?
    private var requesting = false
    private var observer: NSObjectProtocol?

    /// `status` and `requester` replace the system's in tests, which must not show the permission prompt.
    init(status: (() -> PermissionState)? = nil, requester: (() async -> Bool)? = nil) {
        self.status = status ?? Self.systemStatus
        self.requester = requester
        access = self.status()
    }

    private static func systemStatus() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    func refreshAccess() { access = status() }

    /// Shows the system prompt if the user has never answered it. Never asks again after an answer (R-WID-3).
    @discardableResult
    func requestAccessIfNeeded() -> Task<Void, Never>? {
        refreshAccess()
        guard access == .notDetermined, !requesting else { return nil }
        requesting = true
        return Task {
            if let requester {
                _ = await requester()
            } else {
                _ = await AVCaptureDevice.requestAccess(for: .video)
            }
            requesting = false
            refreshAccess()
        }
    }

    /// Turns the camera on for the widget `owner`, using the Mac's default camera.
    func start(for owner: UUID) {
        refreshAccess()
        guard access == .granted, self.owner == nil else { return }
        self.owner = owner
        problem = nil
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.failed(.stopped) }
            }
        }
        let session = session
        queue.async {
            // The default camera can change, for example when an external one is plugged in.
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            var started = false
            if let device = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                session.addInput(input)
                started = true
            }
            session.commitConfiguration()
            if started { session.startRunning() }
            let found = started
            Task { @MainActor [weak self] in if !found { self?.failed(.noCamera) } }
        }
    }

    /// Turns the camera off if `owner` turned it on.
    func stop(for owner: UUID) {
        guard self.owner == owner else { return }
        self.owner = nil
        let session = session
        queue.async { session.stopRunning() }
    }

    private func failed(_ problem: Problem) {
        guard let owner else { return }
        stop(for: owner)
        self.problem = problem
    }
}

/// The camera picture, mirrored like a mirror.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewView { CameraPreviewView(session: session) }
    func updateNSView(_ view: CameraPreviewView, context: Context) {}
}

final class CameraPreviewView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.transform = CATransform3DMakeScale(-1, 1, 1)
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // With a transform set, the layer is placed by its bounds and position, not its frame.
        previewLayer.bounds = bounds
        previewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }
}
