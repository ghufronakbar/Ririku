import Foundation
import Darwin
import RirikuCore

signal(SIGPIPE, SIG_IGN)

do {
    var connection = try? LocalSocket.connect()
    var initialPacket: Data?
    if connection == nil {
        var input = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
        guard poll(&input, 1, 500) > 0, let packet = try Frames.read(.standardInput),
              let message = try? JSONSerialization.jsonObject(with: packet) as? [String: Any],
              message["protocolVersion"] as? Int == 1, message["kind"] as? String == "openSetup" else {
            throw BridgeError.system("Open Ririku or click Open Setup in the extension.")
        }
        initialPacket = packet
        let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
        let application = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        if application.pathExtension == "app", FileManager.default.fileExists(atPath: application.appendingPathComponent("Contents/Info.plist").path) {
            let launcher = Process()
            launcher.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            launcher.arguments = ["-g", application.path]
            launcher.standardOutput = FileHandle.standardError
            try launcher.run()
            for _ in 0..<40 {
                Thread.sleep(forTimeInterval: 0.1)
                connection = try? LocalSocket.connect()
                if connection != nil { break }
            }
        }
    }
    guard let descriptor = connection else { throw BridgeError.system("Unable to connect to the Ririku app.") }
    let socketHandle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    if let initialPacket { try Frames.write(initialPacket, to: socketHandle) }
    DispatchQueue.global().async {
        do {
            while let packet = try Frames.read(socketHandle) {
                try Frames.write(packet, to: .standardOutput)
            }
        } catch {
            FileHandle.standardError.write(Data("Ririku: app connection ended.\n".utf8))
        }
        exit(0)
    }
    while let packet = try Frames.read(.standardInput) {
        try Frames.write(packet, to: socketHandle)
    }
} catch {
    FileHandle.standardError.write(Data("Ririku: \(error.localizedDescription)\n".utf8))
    exit(1)
}
