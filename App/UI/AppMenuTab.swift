import SwiftUI
import Combine

/// Aba "Menu do app" (iMenuPeek): ⌘ + clique direito abre o menu do app em primeiro plano no cursor.
/// Mostra o estado da Acessibilidade (obrigatória), um botão para pedi-la e o liga/desliga.
struct AppMenuTab: View {
    @State private var enabled = AppMenuAtCursor.isEnabled
    @State private var accessibilityOK = Permissions.accessibilityTrusted
    @State private var running = AppMenuAtCursor.shared.isActive
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "appMenu.title"))
                        .font(.system(size: 15, weight: .semibold))
                    Text(String(localized: "appMenu.subtitle"))
                        .font(.system(size: 12))
                        .foregroundStyle(MMColor.label2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                MMGroup(header: String(localized: "appMenu.permissionHeader")) {
                    MMRow {
                        Image(systemName: accessibilityOK ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(accessibilityOK ? MMColor.green : MMColor.red)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(localized: accessibilityOK ? "appMenu.accessibilityOn" : "appMenu.accessibilityOff"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(MMColor.label)
                            Text(String(localized: "appMenu.accessibilityWhy"))
                                .font(.system(size: 11))
                                .foregroundStyle(MMColor.label3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        MMButton(String(localized: accessibilityOK ? "onboarding.permission.openSettings" : "appMenu.requestPermission"),
                                 systemImage: "accessibility", kind: accessibilityOK ? .normal : .primary, size: .sm) {
                            if !accessibilityOK { Permissions.requestAccessibility() }
                            Permissions.openAccessibilitySettings()
                        }
                    }
                }

                MMGroup(header: String(localized: "appMenu.activationHeader")) {
                    MMRow {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(localized: "appMenu.toggle"))
                                .font(.system(size: 13))
                                .foregroundStyle(MMColor.label)
                            Text(String(localized: statusKey))
                                .font(.system(size: 11))
                                .foregroundStyle(running ? MMColor.green : MMColor.label3)
                        }
                        Spacer(minLength: 0)
                        MMSwitch($enabled, scale: 0.78)
                            .onChange(of: enabled) { value in
                                AppMenuAtCursor.isEnabled = value
                                refresh()
                            }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .onAppear { refresh() }
        .onReceive(timer) { _ in refresh() }
    }

    private var statusKey: String.LocalizationValue {
        if !enabled { return "appMenu.statusOff" }
        if !accessibilityOK { return "appMenu.statusWaiting" }
        return running ? "appMenu.statusRunning" : "appMenu.statusStarting"
    }

    private func refresh() {
        accessibilityOK = Permissions.accessibilityTrusted
        running = AppMenuAtCursor.shared.isActive
    }
}
