import Foundation
import Darwin
import RirikuCore

final class BridgeServer {
    private let lock = NSLock()
    private var client: FileHandle?
    private var listener: Int32 = -1
    private var lockFile: Int32 = -1
    private var socketPath: String?
    private var language = "en"
    private let writer = DispatchQueue(label: "ririku.bridge.writer")
    var onPacket: ((Data) -> Void)?
    var onDisconnect: (() -> Void)?

    func start() throws {
        let path = try LocalSocket.path()
        lockFile = open(path + ".lock", O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard lockFile >= 0, flock(lockFile, LOCK_EX | LOCK_NB) == 0 else {
            if lockFile >= 0 { Darwin.close(lockFile); lockFile = -1 }
            throw BridgeError.system("Another Ririku instance is already running.")
        }
        unlink(path)
        var address = try LocalSocket.address(for: path)
        listener = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listener >= 0 else { throw BridgeError.system("Unable to create the server socket.") }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0, listen(listener, 2) == 0 else {
            Darwin.close(listener)
            listener = -1
            throw BridgeError.system("The local bridge could not be started.")
        }
        socketPath = path
        chmod(path, 0o600)
        let descriptor = listener
        DispatchQueue.global(qos: .utility).async { [weak self] in
            while true {
                let accepted = accept(descriptor, nil, nil)
                guard accepted >= 0, let self else { return }
                guard LocalSocket.isSameUser(accepted) else { Darwin.close(accepted); continue }
                let handle = FileHandle(fileDescriptor: accepted, closeOnDealloc: true)
                self.lock.lock()
                let busy = self.client != nil
                if !busy { self.client = handle }
                self.lock.unlock()
                if busy { try? handle.close(); continue }
                self.send(self.packet(kind: "hello"))
                DispatchQueue.global(qos: .utility).async { [weak self] in self?.read(handle) }
            }
        }
    }

    private func read(_ handle: FileHandle) {
        do {
            while let packet = try Frames.read(handle) {
                DispatchQueue.main.async { [weak self] in self?.onPacket?(packet) }
            }
        } catch {}
        lock.lock()
        if client === handle { client = nil }
        DispatchQueue.main.async { [weak self] in self?.onDisconnect?() }
        lock.unlock()
        try? handle.close()
    }

    /// Bahasa UI terkini ikut dikirim agar popup extension memakai bahasa yang sama.
    func setLanguage(_ code: String) {
        lock.lock()
        language = code
        let connected = client != nil
        lock.unlock()
        if connected { send(packet(kind: "preferences")) }
    }

    private func packet(kind: String) -> Data {
        lock.lock()
        let code = language
        lock.unlock()
        return (try? JSONSerialization.data(withJSONObject: ["protocolVersion": 1, "kind": kind, "language": code])) ?? Data()
    }

    func send(_ data: Data) {
        writer.async { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let handle = self.client
            self.lock.unlock()
            guard let handle else { return }
            do { try Frames.write(data, to: handle) }
            catch { shutdown(handle.fileDescriptor, SHUT_RDWR) }
        }
    }

    func stop() {
        if listener >= 0 { Darwin.close(listener); listener = -1 }
        lock.lock()
        if let client { shutdown(client.fileDescriptor, SHUT_RDWR) }
        lock.unlock()
        if let socketPath { unlink(socketPath) }
        if lockFile >= 0 { flock(lockFile, LOCK_UN); Darwin.close(lockFile); lockFile = -1 }
    }
}
