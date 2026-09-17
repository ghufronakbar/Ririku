import Foundation
import Darwin

public enum BridgeError: Error, LocalizedError {
    case invalidFrame
    /// Teks sumber English; argumen mengisi `%@` agar aplikasi dapat menerjemahkannya.
    case system(String, [String] = [])

    public var message: (key: String, arguments: [String]) {
        switch self {
        case .invalidFrame: return ("Invalid or oversized bridge message.", [])
        case .system(let key, let arguments): return (key, arguments)
        }
    }

    public var errorDescription: String? {
        let (key, arguments) = message
        return arguments.isEmpty ? key : String(format: key, arguments: arguments.map { $0 as NSString as CVarArg })
    }
}

public enum Frames {
    public static let maximumSize = 256 * 1024

    private static func readExactly(_ handle: FileHandle, count: Int) throws -> Data? {
        var result = Data()
        while result.count < count {
            guard let part = try handle.read(upToCount: count - result.count), !part.isEmpty else {
                if result.isEmpty { return nil }
                throw BridgeError.invalidFrame
            }
            result.append(part)
        }
        return result
    }

    public static func read(_ handle: FileHandle) throws -> Data? {
        guard let header = try readExactly(handle, count: 4) else { return nil }
        let size = header.enumerated().reduce(UInt32(0)) { $0 | (UInt32($1.element) << ($1.offset * 8)) }
        guard size > 0, size <= maximumSize,
              let body = try readExactly(handle, count: Int(size)) else { throw BridgeError.invalidFrame }
        return body
    }

    public static func write(_ data: Data, to handle: FileHandle) throws {
        guard !data.isEmpty, data.count <= maximumSize else { throw BridgeError.invalidFrame }
        let count = UInt32(data.count)
        var packet = Data((0..<4).map { UInt8(truncatingIfNeeded: count >> ($0 * 8)) })
        packet.append(data)
        try handle.write(contentsOf: packet)
    }
}

public enum LocalSocket {
    public static func path() throws -> String {
        let directory = "/tmp/ririku-\(getuid())"
        if mkdir(directory, 0o700) != 0 && errno != EEXIST {
            throw BridgeError.system("Unable to create the bridge directory.")
        }
        var info = stat()
        guard lstat(directory, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR,
              info.st_uid == getuid(), (info.st_mode & 0o777) == 0o700 else {
            throw BridgeError.system("Bridge directory is unsafe; check %@.", [directory])
        }
        return directory + "/bridge.sock"
    }

    public static func address(for path: String) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let bytes = Array(path.utf8) + [0]
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw BridgeError.invalidFrame }
        withUnsafeMutableBytes(of: &address.sun_path) { target in target.copyBytes(from: bytes) }
        return address
    }

    public static func connect() throws -> Int32 {
        var address = try address(for: path())
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw BridgeError.system("Unable to create socket.") }
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0, isSameUser(descriptor) else {
            Darwin.close(descriptor)
            throw BridgeError.system("Open the Ririku app first.")
        }
        return descriptor
    }

    public static func isSameUser(_ descriptor: Int32) -> Bool {
        var user: uid_t = 0
        var group: gid_t = 0
        return getpeereid(descriptor, &user, &group) == 0 && user == getuid()
    }
}
