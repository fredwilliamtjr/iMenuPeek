// Permissions.swift — 一次性把 MenuMate 需要的系统权限申请掉(在首次引导里预请求,使用前就授权)。
//
// macOS 的 TCC 对每类权限只问一次:授权后永久生效、永不再弹;拒绝后也不再自动弹,
// 需用户去「系统设置」改。所以这里的目标是"在使用前主动触发那一次弹窗",而不是反复请求。
// 涉及两类:
//   - 通知:脚本失败提醒(UNUserNotificationCenter)。
//   - 自动化 › Finder:「前往上一层/所在目录」在 Finder 内同窗导航(发 Apple Event)。
// iMenuPeek 不申请「辅助功能」:脚本是 App 的子进程,会继承该授权(可合成按键、操控任意 App)。
//
// 开发期注意:ad-hoc 签名每次重编 cdhash 变化,TCC 会"忘记"授权而重新弹;
// 用稳定签名(Apple Development / Developer ID)后即可一次授权跨版本保留。

import AppKit
import CoreServices
import UserNotifications
import MenuMateCore

enum Permissions {
    /// Estado de uma permissão para os indicadores da tela de boas-vindas.
    enum State: Equatable { case granted, denied, notDetermined }

    /// Consulta SEM perguntar ao usuário se o iMenuPeek pode controlar o Finder.
    /// Bloqueia (fala com o Finder): chamar fora da main.
    nonisolated static func finderAutomationState() -> State {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
        guard let desc = target.aeDesc else { return .notDetermined }
        let status = AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, false)
        switch Int(status) {
        case Int(noErr): return .granted
        case errAEEventNotPermitted: return .denied               // -1743: usuário negou
        default: return .notDetermined                            // -1744: ainda não perguntado; -600: Finder fora do ar
        }
    }

    static func notificationState(_ completion: @escaping (State) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let state: State
            switch settings.authorizationStatus {
            case .authorized, .provisional: state = .granted
            case .denied: state = .denied
            default: state = .notDetermined
            }
            DispatchQueue.main.async { completion(state) }
        }
    }

    static func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(Brand.appBundleID)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: 自动化(Finder)

    /// 向 Finder 发一个无害 Apple Event,触发一次性「iMenuPeek 想要控制 Finder」授权框。
    /// 导航脚本运行期就是用 osascript 控制 Finder(同窗导航),
    /// 故这里也用 osascript 子进程预约,保证授权主体(iMenuPeek)与运行期完全一致。
    /// executeAndReturnError 同步阻塞等用户回应,故放后台线程触发。
    static func primeAutomation() {
        DispatchQueue.global(qos: .userInitiated).async {
            // "return name" é respondido pelo próprio AppleScript, sem Apple Event → o TCC nunca pergunta.
            // "count Finder windows" exige conversar com o Finder (só leitura) e dispara o aviso de Automação.
            runOsascript("tell application \"Finder\" to count Finder windows")
        }
    }

    private static func runOsascript(_ source: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", source]
        try? p.run()
        p.waitUntilExit()
    }

    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: 通知

    static func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    // MARK: 一键预请求

    /// 在使用前一次性触发全部权限弹窗(供首次引导调用)。
    static func primeAll() {
        requestNotifications()
        primeAutomation()
    }
}
