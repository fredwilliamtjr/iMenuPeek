import AppKit
import FinderSync
import MenuMateCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let extensionBundleID = Brand.extensionBundleID
    static let showSettingsNotification = Notification.Name("MenuMateShowSettings")

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: Self.showSettingsNotification, object: nil)
        }
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // App de barra de menus fica sem janelas a maior parte do tempo; sem isto o macOS pode
        // encerrá-lo sozinho (Automatic Termination — log: _kLSApplicationWouldBeTerminatedByTALKey=1).
        ProcessInfo.processInfo.disableAutomaticTermination("iMenuPeek vive na barra de menus")
        Notifier.requestAuthorizationOnce()
        Task { @MainActor in AppState.shared.start() }

        let onboardingDone = UserDefaults.standard.bool(forKey: "onboardingDone")
        let enabled = Self.extensionEnabled()
        if !onboardingDone || !enabled {
            Task { @MainActor in OnboardingWindowController.show() }
        }
    }

    /// 扩展是否启用。FIFinderSyncController.isExtensionEnabled 在开发/ad-hoc 签名版上不可靠
    /// (常返回 false 即便扩展已启用、右键正常)→ 用 pluginkit 这个「Finder 真正加载哪个」的实况兜底。
    /// nonisolated: a tela de boas-vindas consulta isto a cada 2 s fora da main (pluginkit bloqueia até 5 s).
    nonisolated static func extensionEnabled(log: Bool = true) -> Bool {
        let api = FIFinderSyncController.isExtensionEnabled
        let pk = ShellRunner.run("/usr/bin/pluginkit", ["-m", "-i", Brand.extensionBundleID], timeout: 5)
        // pluginkit -m 输出行首:`+` 启用 / `-` 停用 / `!` 异常;空=未注册。
        let pkEnabled = pk.stdout.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+")
        guard log else { return api || pkEnabled }
        NSLog("[iMenuPeek][onboarding] isExtensionEnabled=\(api) pluginkit=\(pkEnabled) onboardingDone=\(UserDefaults.standard.bool(forKey: "onboardingDone")) pkRaw=\(pk.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
        return api || pkEnabled
    }
}
