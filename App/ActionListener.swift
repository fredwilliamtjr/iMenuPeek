import Foundation
import MenuMateCore

final class ActionListener {
    private let reassembler = ChunkReassembler()   // queue: .main 串行投递 → 单线程使用
    private let replay = ReplayGuard()             // idem

    func start() {
        // iMenuPeek: só executa pedidos assinados pela extensão com a chave desta instalação (IPCAuth).
        // Sem chave legível, nenhum pedido passa — falha fechada.
        let key: Data?
        do { key = try IPCAuth.loadOrCreateKey() } catch {
            key = nil
            NSLog("iMenuPeek: não foi possível criar a chave de IPC (%@); ações do menu ficam bloqueadas",
                  String(describing: error))
        }
        DistributedNotificationCenter.default().addObserver(
            // object: nil 有意为之——DNC 发送方不可信：防御靠 HMAC(IPCAuth)+块/总量上限+解码+派发闸门，
            // 切勿改成按 bundleID 过滤（可被伪造）
            forName: .init(IPC.actionNotification), object: nil, queue: .main) { [reassembler, replay] note in
            guard let s = note.object as? String, s.utf8.count <= 64 * 1024,
                  let chunk = try? ChunkedTransport.Chunk.decode(s),
                  let signed = reassembler.receive(chunk) else { return }
            guard let key else { return }
            switch IPCAuth.verify(signed, key: key, replay: replay) {
            case .success(let payload):
                guard let request = try? ActionRequest.decode(payload) else { return }
                Task { @MainActor in ActionDispatcher.shared.dispatch(request) }
            case .failure(let failure):
                NSLog("iMenuPeek: pedido de ação recusado (%@)", String(describing: failure))
            }
        }
    }
}
