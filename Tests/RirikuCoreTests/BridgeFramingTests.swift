import Foundation
import Testing
@testable import RirikuCore

@Suite("Bridge framing")
struct BridgeFramingTests {
    /// Uses a temporary file instead of a pipe: a frame can be larger than the pipe buffer,
    /// which would block a single-threaded write.
    private func roundTrip(_ payloads: [Data]) throws -> [Data] {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ririku-frames-\(UUID().uuidString)")
        _ = FileManager.default.createFile(atPath: url.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try FileHandle(forWritingTo: url)
        for payload in payloads { try Frames.write(payload, to: writer) }
        try writer.close()
        let reader = try FileHandle(forReadingFrom: url)
        defer { try? reader.close() }
        var received: [Data] = []
        while let frame = try Frames.read(reader) { received.append(frame) }
        return received
    }

    @Test("Reads back what it wrote, in order")
    func roundTripsFrames() throws {
        let payloads = [Data("{\"kind\":\"hello\"}".utf8), Data("{\"kind\":\"snapshot\"}".utf8)]
        #expect(try roundTrip(payloads) == payloads)
    }

    @Test("Uses a little-endian length prefix")
    func writesLittleEndianLength() throws {
        let pipe = Pipe()
        try Frames.write(Data([0x41, 0x42]), to: pipe.fileHandleForWriting)
        try pipe.fileHandleForWriting.close()
        #expect(try pipe.fileHandleForReading.readToEnd() == Data([2, 0, 0, 0, 0x41, 0x42]))
    }

    @Test("Returns nil at a clean end of stream")
    func returnsNilAtEndOfStream() throws {
        let pipe = Pipe()
        try pipe.fileHandleForWriting.close()
        #expect(try Frames.read(pipe.fileHandleForReading) == nil)
    }

    @Test("Refuses to write empty or oversized payloads")
    func refusesInvalidWrites() {
        let pipe = Pipe()
        #expect(throws: BridgeError.self) { try Frames.write(Data(), to: pipe.fileHandleForWriting) }
        #expect(throws: BridgeError.self) {
            try Frames.write(Data(count: Frames.maximumSize + 1), to: pipe.fileHandleForWriting)
        }
    }

    @Test("Rejects a header announcing more than the maximum size")
    func rejectsOversizedHeader() throws {
        let pipe = Pipe()
        try pipe.fileHandleForWriting.write(contentsOf: Data([0, 0, 0xFF, 0xFF]) + Data(count: 8))
        try pipe.fileHandleForWriting.close()
        #expect(throws: BridgeError.self) { try Frames.read(pipe.fileHandleForReading) }
    }

    @Test("Rejects a truncated body and a zero length")
    func rejectsBrokenFrames() throws {
        let truncated = Pipe()
        try truncated.fileHandleForWriting.write(contentsOf: Data([4, 0, 0, 0, 0x41]))
        try truncated.fileHandleForWriting.close()
        #expect(throws: BridgeError.self) { try Frames.read(truncated.fileHandleForReading) }

        let empty = Pipe()
        try empty.fileHandleForWriting.write(contentsOf: Data([0, 0, 0, 0]))
        try empty.fileHandleForWriting.close()
        #expect(throws: BridgeError.self) { try Frames.read(empty.fileHandleForReading) }
    }

    @Test("Carries a payload at the maximum size")
    func carriesMaximumPayload() throws {
        let payload = Data(repeating: 0x7A, count: Frames.maximumSize)
        #expect(try roundTrip([payload]) == [payload])
    }

    @Test("Describes errors in English for logs")
    func describesErrors() {
        #expect(BridgeError.invalidFrame.errorDescription == "Invalid or oversized bridge message.")
        #expect(BridgeError.system("Lyrics search failed (HTTP %@).", ["503"]).errorDescription == "Lyrics search failed (HTTP 503).")
        #expect(BridgeError.system("Open the Ririku app first.").errorDescription == "Open the Ririku app first.")
        let message = BridgeError.system("Bridge directory is unsafe; check %@.", ["/tmp/ririku-501"]).message
        #expect(message.key == "Bridge directory is unsafe; check %@." && message.arguments == ["/tmp/ririku-501"])
    }
}

@Suite("Island motion")
struct IslandMotionTests {
    private let start = CGRect(x: 100, y: 800, width: 200, height: 40)
    private let target = CGRect(x: 50, y: 700, width: 300, height: 140)

    @Test("Returns the start and target frames at the edges of the animation")
    func returnsEdges() {
        #expect(IslandMotion.frame(from: start, to: target, progress: 0).size == start.size)
        #expect(IslandMotion.frame(from: start, to: target, progress: 1) == target)
    }

    @Test("Clamps progress outside zero and one")
    func clampsProgress() {
        #expect(IslandMotion.frame(from: start, to: target, progress: -5).size == start.size)
        #expect(IslandMotion.frame(from: start, to: target, progress: 5) == target)
    }

    @Test("Keeps the top edge fixed at the target for every frame")
    func keepsTopEdge() {
        for step in 0...120 {
            let frame = IslandMotion.frame(from: start, to: target, progress: Double(step) / 120)
            #expect(abs(frame.maxY - target.maxY) < 0.0001)
        }
    }

    @Test("Moves width, height, and center monotonically")
    func interpolatesMonotonically() {
        var previous = IslandMotion.frame(from: start, to: target, progress: 0)
        for step in 1...60 {
            let frame = IslandMotion.frame(from: start, to: target, progress: Double(step) / 60)
            #expect(frame.width >= previous.width)
            #expect(frame.height >= previous.height)
            #expect(frame.midX <= previous.midX)
            previous = frame
        }
    }

    @Test("Eases in and out around the midpoint")
    func easesSymmetrically() {
        let midpoint = IslandMotion.frame(from: start, to: target, progress: 0.5)
        #expect(abs(midpoint.width - 250) < 0.0001)
        let early = IslandMotion.frame(from: start, to: target, progress: 0.1)
        #expect(early.width - start.width < 250 - start.width)
    }
}
