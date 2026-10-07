import SwiftUI
import MenuMateCore

@main
struct MenuMateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // 菜单栏下拉 — 对照 docs/design/hifi/screen-misc.jsx MenuBar(系统右键菜单外观)。
        // 用系统原生 MenuBarExtra,项与分隔结构对齐设计稿。
        MenuBarExtra {
            Button(String(localized: "menubar.openSettings")) {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button(String(localized: "menubar.recentRuns")) {
                openWindow(id: "log")
                NSApp.activate(ignoringOtherApps: true)
            }
            Divider()
            Button(String(localized: "menubar.restartFinder")) { ShellRunner.run("/usr/bin/killall", ["Finder"], timeout: 10) }
            Divider()
            Button(String(localized: "menubar.quit")) { NSApp.terminate(nil) }
        } label: {
            Image(systemName: Brand.menuSymbol)
                .accessibilityLabel(Brand.name)
                .onReceive(NotificationCenter.default.publisher(for: AppDelegate.showSettingsNotification)) { _ in
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        Window(String(localized: "menubar.settingsWindowTitle"), id: "settings") { SettingsWindow() }
            .defaultSize(width: 1000, height: 1140)   // tamanho escolhido pelo Fred (estreita e alta)
        Window(String(localized: "menubar.logWindowTitle"), id: "log") {
            ExecutionLogView()
        }
        .defaultSize(width: 540, height: 480)
    }
}
