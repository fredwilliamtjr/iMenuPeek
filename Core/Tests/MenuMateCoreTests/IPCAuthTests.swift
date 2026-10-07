import XCTest
@testable import MenuMateCore

final class IPCAuthTests: XCTestCase {
    private let key = Data(repeating: 7, count: 32)
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testSignedPayloadVerifies() throws {
        let envelope = try IPCAuth.sign(payload: #"{"paths":["/tmp/a b"]}"#, key: key, now: now)
        XCTAssertEqual(IPCAuth.verify(envelope, key: key, now: now, replay: ReplayGuard()),
                       .success(#"{"paths":["/tmp/a b"]}"#))
    }

    func testWrongKeyIsRejected() throws {
        let envelope = try IPCAuth.sign(payload: "x", key: key, now: now)
        XCTAssertEqual(IPCAuth.verify(envelope, key: Data(repeating: 8, count: 32), now: now, replay: ReplayGuard()),
                       .failure(.badSignature))
    }

    func testTamperedPayloadIsRejected() throws {
        let envelope = try IPCAuth.sign(payload: #"{"paths":["/a"]}"#, key: key, now: now)
        let tampered = envelope.replacingOccurrences(of: #"[\"/a\"]"#, with: #"[\"/b\"]"#)
        XCTAssertNotEqual(tampered, envelope)
        XCTAssertEqual(IPCAuth.verify(tampered, key: key, now: now, replay: ReplayGuard()), .failure(.badSignature))
    }

    func testUnsignedOldStylePayloadIsRejected() {
        XCTAssertEqual(IPCAuth.verify(#"{"actionID":"00000000-0000-0000-0000-000000000001","paths":[]}"#,
                                      key: key, now: now, replay: ReplayGuard()), .failure(.malformed))
    }

    func testReplayIsRejected() throws {
        let guardian = ReplayGuard()
        let envelope = try IPCAuth.sign(payload: "x", key: key, now: now)
        XCTAssertEqual(IPCAuth.verify(envelope, key: key, now: now, replay: guardian), .success("x"))
        XCTAssertEqual(IPCAuth.verify(envelope, key: key, now: now.addingTimeInterval(1), replay: guardian),
                       .failure(.replayed))
    }

    func testOutsideTimeWindowIsRejected() throws {
        let envelope = try IPCAuth.sign(payload: "x", key: key, now: now)
        XCTAssertEqual(IPCAuth.verify(envelope, key: key, now: now.addingTimeInterval(IPCAuth.maxSkew + 1),
                                      replay: ReplayGuard()), .failure(.expired))
        XCTAssertEqual(IPCAuth.verify(envelope, key: key, now: now.addingTimeInterval(-(IPCAuth.maxSkew + 1)),
                                      replay: ReplayGuard()), .failure(.expired))
    }

    func testKeyFileIsCreatedPrivateAndReused() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent("ipcauth-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: home) }
        let url = IPCAuth.keyURL(home: home)
        XCTAssertTrue(url.path.hasSuffix("Library/Application Support/iMenuPeek/IPC/ipc.key"))
        let first = try IPCAuth.loadOrCreateKey(at: url)
        XCTAssertEqual(first.count, 32)
        XCTAssertEqual(try IPCAuth.loadOrCreateKey(at: url), first)
        XCTAssertEqual(IPCAuth.readKey(at: url), first)
        let fileMode = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int
        let dirMode = try FileManager.default.attributesOfItem(atPath: url.deletingLastPathComponent().path)[.posixPermissions] as? Int
        XCTAssertEqual(fileMode, 0o600)
        XCTAssertEqual(dirMode, 0o700)
    }

    func testReplayGuardForgetsOldNonces() {
        let guardian = ReplayGuard(window: 10)
        XCTAssertTrue(guardian.accept("n", now: now))
        XCTAssertFalse(guardian.accept("n", now: now.addingTimeInterval(5)))
        XCTAssertTrue(guardian.accept("n", now: now.addingTimeInterval(11)))
    }
}
