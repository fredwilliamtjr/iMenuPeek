import Foundation
import CryptoKit
import Darwin

/// Autenticação dos pedidos de ação extensão → app (iMenuPeek).
///
/// O canal é a DistributedNotificationCenter: qualquer processo — inclusive app sandboxed — pode
/// postar e escutar. Por isso o app só executa pedidos assinados com HMAC-SHA256 por uma chave
/// gerada por instalação, guardada em `~/Library/Application Support/iMenuPeek/IPC/ipc.key` (0600).
/// - App sandboxed de terceiros não lê esse arquivo (fora do container dele).
/// - A extensão lê via exceção read-only do sandbox restrita à pasta `IPC/`.
/// - Quem escuta um pedido legítimo não consegue forjar outro (sem a chave) nem repeti-lo
///   (janela de tempo + nonce de uso único).
public enum IPCAuth {
    public static let version = 1
    /// Diferença máxima aceita entre o carimbo de tempo do pedido e o relógio do app.
    public static let maxSkew: TimeInterval = 30
    public static let keyByteCount = 32

    public struct Envelope: Codable, Equatable {
        public var v: Int
        public var ts: Int64        // milissegundos desde 1970
        public var nonce: String
        public var payload: String
        public var mac: String      // base64(HMAC-SHA256)
    }

    public enum Failure: Error, Equatable {
        case malformed, unsupportedVersion, badSignature, expired, replayed
    }

    // MARK: Chave

    /// Pasta Application Support do usuário REAL. Dentro do sandbox (extensão) o
    /// FileManager devolve o container; getpwuid devolve a home verdadeira nos dois processos.
    public static func realHomeDirectory() -> URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    public static func keyURL(home: URL = realHomeDirectory()) -> URL {
        home.appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(Brand.name, isDirectory: true)
            .appendingPathComponent("IPC", isDirectory: true)
            .appendingPathComponent("ipc.key")
    }

    /// Lê a chave (32 bytes). nil se ausente ou com tamanho errado.
    public static func readKey(at url: URL = keyURL()) -> Data? {
        guard let data = try? Data(contentsOf: url), data.count == keyByteCount else { return nil }
        return data
    }

    /// App: devolve a chave existente ou cria uma nova (pasta 0700, arquivo 0600, escrita atômica).
    public static func loadOrCreateKey(at url: URL = keyURL()) throws -> Data {
        if let key = readKey(at: url) { return key }
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        try fm.createDirectory(at: dir, withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        try key.write(to: url, options: [.atomic])
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return key
    }

    // MARK: Assinar / verificar

    private static func message(v: Int, ts: Int64, nonce: String, payload: String) -> Data {
        Data("iMenuPeek-ipc\nv\(v)\n\(ts)\n\(nonce)\n\(payload)".utf8)
    }

    public static func sign(payload: String, key: Data, now: Date = Date(),
                            nonce: String = UUID().uuidString) throws -> String {
        let ts = Int64((now.timeIntervalSince1970 * 1000).rounded())
        let mac = HMAC<SHA256>.authenticationCode(
            for: message(v: version, ts: ts, nonce: nonce, payload: payload), using: SymmetricKey(data: key))
        let envelope = Envelope(v: version, ts: ts, nonce: nonce, payload: payload,
                                mac: Data(mac).base64EncodedString())
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        return String(decoding: try encoder.encode(envelope), as: UTF8.self)
    }

    /// Devolve o payload se a assinatura, a janela de tempo e o nonce forem válidos.
    public static func verify(_ string: String, key: Data, now: Date = Date(),
                              replay: ReplayGuard) -> Result<String, Failure> {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: Data(string.utf8)),
              !envelope.nonce.isEmpty, envelope.nonce.utf8.count <= 64,
              let mac = Data(base64Encoded: envelope.mac) else { return .failure(.malformed) }
        guard envelope.v == version else { return .failure(.unsupportedVersion) }
        let valid = HMAC<SHA256>.isValidAuthenticationCode(
            mac, authenticating: message(v: envelope.v, ts: envelope.ts, nonce: envelope.nonce, payload: envelope.payload),
            using: SymmetricKey(data: key))
        guard valid else { return .failure(.badSignature) }
        let sent = Date(timeIntervalSince1970: Double(envelope.ts) / 1000)
        guard abs(now.timeIntervalSince(sent)) <= maxSkew else { return .failure(.expired) }
        guard replay.accept(envelope.nonce, now: now) else { return .failure(.replayed) }
        return .success(envelope.payload)
    }
}

/// Nonces já aceitos dentro da janela de validade (uso único). Single-thread (fila main do app).
public final class ReplayGuard {
    private var seen: [String: Date] = [:]
    private let window: TimeInterval

    public init(window: TimeInterval = IPCAuth.maxSkew * 2) { self.window = window }

    public func accept(_ nonce: String, now: Date = Date()) -> Bool {
        seen = seen.filter { now.timeIntervalSince($0.value) <= window }
        guard seen[nonce] == nil else { return false }
        seen[nonce] = now
        return true
    }
}
