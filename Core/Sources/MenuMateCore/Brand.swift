import Foundation

/// Identidade do app (nome e bundle IDs) num lugar só; IPC, AppPaths e Declutter derivam daqui.
public enum Brand {
    public static let name = "iMenuPeek"
    public static let appBundleID = "com.smartfull.imenupeek"
    public static let extensionBundleID = "com.smartfull.imenupeek.FinderExtension"
    /// SF Symbol do app (ícone da barra de menus e do item "iMenuPeek ▸" no Finder).
    public static let menuSymbol = "contextualmenu.and.cursorarrow"

    /// O próprio app ou qualquer componente embutido dele.
    public static func owns(bundleID: String) -> Bool {
        bundleID == appBundleID || bundleID.hasPrefix(appBundleID + ".")
    }
}
