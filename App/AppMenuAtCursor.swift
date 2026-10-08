// AppMenuAtCursor.swift — menu do app em primeiro plano aberto junto do cursor com ⌘ + clique direito
// (estilo Menuwhere).
//
// A leitura do menu por Acessibilidade (AXMenuBar → NSMenu, submenus sob demanda, ação AXPress) foi
// adaptada do menuanywhere — https://github.com/acsandmann/menuanywhere
// Copyright (c) 2025 acsandmann — licença MIT (texto completo em THIRD-PARTY-NOTICES.md).
// O gatilho por clique (event tap) é do iMenuPeek.
//
// Requer Acessibilidade: ler o menu de outros apps e interceptar o clique (tap que consome o evento).

import AppKit
import ApplicationServices
import ObjectiveC

final class AppMenuAtCursor: NSObject, NSMenuDelegate {
    static let shared = AppMenuAtCursor()
    /// Liga/desliga nos Ajustes › Geral. Padrão: ligado.
    static let enabledKey = "appMenuAtCursorEnabled"

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            shared.refresh()
        }
    }

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var waitForPermission: Timer?
    /// O clique direito que abriu o menu: o "soltar" correspondente também é consumido.
    fileprivate var swallowNextRightMouseUp = false
    private weak var currentApp: NSRunningApplication?
    private var activeMenu: NSMenu?

    /// Chamado no início do app e quando a opção muda. Sem Acessibilidade, espera ela ser concedida.
    func refresh() {
        guard Self.isEnabled else { uninstallTap(); stopWaiting(); return }
        if AXIsProcessTrusted() {
            stopWaiting()
            installTap()
        } else if waitForPermission == nil {
            waitForPermission = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                if AXIsProcessTrusted() { self?.refresh() }
            }
        }
    }

    var isActive: Bool { tap != nil }

    private func stopWaiting() {
        waitForPermission?.invalidate()
        waitForPermission = nil
    }

    private func installTap() {
        guard tap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: appMenuTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            NSLog("iMenuPeek: não foi possível instalar o monitor do ⌘ + clique direito")
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        runLoopSource = source
    }

    private func uninstallTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        swallowNextRightMouseUp = false
    }

    /// O sistema desliga o tap se ele demorar; religa na hora.
    fileprivate func reenableTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    // MARK: - Menu

    func showMenu(at location: NSPoint) {
        cleanupActiveMenu()
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        currentApp = app
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var menuBar: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBar) == .success,
              let menuBarElement = menuBar,
              CFGetTypeID(menuBarElement as CFTypeRef) == AXUIElementGetTypeID() else {
            NSLog("iMenuPeek: menu de %@ indisponível por Acessibilidade", app.localizedName ?? "?")
            return
        }
        let axMenuBar = menuBarElement as! AXUIElement
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        AXMenuReader.items(from: axMenuBar, isSubmenu: false, target: self,
                           action: #selector(menuAction(_:))).forEach(menu.addItem)
        activeMenu = menu
        menu.popUp(positioning: nil, at: location, in: nil)
    }

    private func cleanupActiveMenu() {
        guard let menu = activeMenu else { return }
        clean(menu.items)
        menu.removeAllItems()
        activeMenu = nil
    }

    private func clean(_ items: [NSMenuItem]) {
        for item in items {
            if let submenu = item.submenu { clean(submenu.items); submenu.removeAllItems() }
            item.representedObject = nil
            item.target = nil
            item.action = nil
        }
    }

    @objc private func menuAction(_ sender: NSMenuItem) {
        guard let object = sender.representedObject,
              CFGetTypeID(object as CFTypeRef) == AXUIElementGetTypeID(),
              let app = currentApp, !app.isTerminated else { return }
        let element = object as! AXUIElement
        // Apps Java (IntelliJ, Android Studio, NetBeans…) aceitam o AXPress no item (retorno 0) mas
        // ignoram — provado no log em 07/10/2026; o Menuwhere também falha neles. Para eles: abrir
        // o menu de verdade na barra e apertar o item com o menu aberto.
        if Self.isJavaApp(app) {
            let path = Self.titlePath(of: element)
            if !path.isEmpty {
                let appElement = AXUIElementCreateApplication(app.processIdentifier)
                if !app.isActive { app.activate(options: []) }
                DispatchQueue.global(qos: .userInitiated).async {
                    Self.pressThroughRealMenu(appElement: appElement, path: path)
                }
                return
            }
        }
        if app.isActive {
            AXUIElementPerformAction(element, kAXPressAction as CFString)
        } else {
            app.activate(options: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                AXUIElementPerformAction(element, kAXPressAction as CFString)
            }
        }
    }

    // MARK: - Apps Java: abrir o menu de verdade e apertar o item

    /// Pacotes com runtime Java embutido: jbr (JetBrains), Home (NetBeans), Java ou runtime (jpackage).
    static func isJavaApp(_ app: NSRunningApplication) -> Bool {
        guard let contents = app.bundleURL?.appendingPathComponent("Contents") else { return false }
        let fm = FileManager.default
        if ["jbr", "Java", "runtime"].contains(where: { fm.fileExists(atPath: contents.appendingPathComponent($0).path) }) {
            return true
        }
        return fm.fileExists(atPath: contents.appendingPathComponent("Home/bin/java").path)
    }

    /// Títulos do item da barra até o item clicado, ex.: ["File", "New", "Project…"].
    static func titlePath(of element: AXUIElement) -> [String] {
        var path: [String] = []
        var current: AXUIElement? = element
        while let node = current {
            let role = node.axString(kAXRoleAttribute)
            if role == "AXMenuBar" || role == "AXApplication" { break }
            if role == "AXMenuItem" || role == "AXMenuBarItem", let title = node.axString(kAXTitleAttribute), !title.isEmpty {
                path.insert(title, at: 0)
            }
            current = node.axParent()
        }
        return path
    }

    /// Fora da main: aperta cada nível pelo título, esperando o menu real abrir antes de descer.
    /// Se algo falhar no meio, manda Esc para não deixar o menu do app aberto.
    static func pressThroughRealMenu(appElement: AXUIElement, path: [String]) {
        var menuBarRef: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBarRef, CFGetTypeID(menuBarRef) == AXUIElementGetTypeID() else {
            return
        }
        var container = menuBarRef as! AXUIElement
        for (level, title) in path.enumerated() {
            guard let node = container.axChildren()?.first(where: { $0.axString(kAXTitleAttribute) == title }) else {
                pressEscape()
                return
            }
            AXUIElementPerformAction(node, kAXPressAction as CFString)
            if level == path.count - 1 { return }
            usleep(250_000)   // dá tempo do menu real abrir
            guard let submenu = node.axChildren()?.first(where: { $0.axString(kAXRoleAttribute) == "AXMenu" }) else {
                pressEscape()
                return
            }
            container = submenu
        }
    }

    private static func pressEscape() {
        for down in [true, false] {
            CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: down)?.post(tap: .cghidEventTap)
        }
    }

    // Submenus são lidos só quando abertos (menus grandes não travam a abertura).
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu !== activeMenu, menu.items.isEmpty, let root = menu.axRootElement else { return }
        AXMenuReader.items(from: root, isSubmenu: true, target: self,
                           action: #selector(menuAction(_:))).forEach(menu.addItem)
    }

    // Sem limpeza em menuDidClose: o fechamento chega ANTES da ação do item escolhido, e limpar ali
    // apagava target/action/representedObject (nenhum item funcionava). A limpeza fica no próximo showMenu.
}

/// Callback C do event tap: ⌘ + clique direito abre o menu e consome o clique (e o "soltar" dele).
private func appMenuTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                                userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let service = Unmanaged<AppMenuAtCursor>.fromOpaque(userInfo).takeUnretainedValue()
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        service.reenableTap()
    case .rightMouseDown where event.flags.contains(.maskCommand):
        service.swallowNextRightMouseUp = true
        DispatchQueue.main.async { service.showMenu(at: NSEvent.mouseLocation) }
        return nil
    case .rightMouseUp where service.swallowNextRightMouseUp:
        service.swallowNextRightMouseUp = false
        return nil
    default:
        break
    }
    return Unmanaged.passUnretained(event)
}

// MARK: - Leitura do menu por Acessibilidade (adaptado do menuanywhere, MIT)

enum AXMenuReader {
    private static let keys = ["AXTitle", "AXRole", "AXRoleDescription", "AXEnabled",
                               "AXMenuItemMarkChar", "AXMenuItemCmdChar", "AXMenuItemCmdModifiers", "AXChildren"]
    private static let boldFont = NSFontManager.shared.convert(
        NSFont.menuFont(ofSize: NSFont.systemFontSize), toHaveTrait: .boldFontMask)

    /// Itens de um menu AX. No nível de cima (isSubmenu false) o primeiro menu (nome do app) vai em
    /// negrito e o menu Apple vai para o fim, como no menuanywhere.
    static func items(from element: AXUIElement, isSubmenu: Bool,
                      target: AnyObject, action: Selector) -> [NSMenuItem] {
        guard let children = element.axChildren() else { return [] }
        var items: [NSMenuItem] = []
        var appleItem: NSMenuItem?
        var isFirst = true
        var needsSeparator = false
        for child in children {
            let data = child.axAttributes(keys) ?? [:]
            let title = data["AXTitle"] as? String ?? ""
            let role = data["AXRole"] as? String ?? ""
            if title.isEmpty || role == "AXSeparator" { needsSeparator = true; continue }
            let isApple = title == "Apple" || (data["AXRoleDescription"] as? String) == "Apple menu"
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.representedObject = child
            item.isEnabled = data["AXEnabled"] as? Bool ?? true
            if let mark = data["AXMenuItemMarkChar"] as? String, !mark.isEmpty {
                item.state = mark == "✓" ? .on : (mark == "•" ? .mixed : .off)
            }
            if let cmd = data["AXMenuItemCmdChar"] as? String, !cmd.isEmpty {
                item.keyEquivalent = cmd.lowercased()
                item.keyEquivalentModifierMask = .fromAXModifiers(data["AXMenuItemCmdModifiers"] as? Int)
            }
            if let sub = (data["AXChildren"] as? [AXUIElement])?.first,
               sub.axAttribute("AXRole") as? String == "AXMenu" {
                let submenu = NSMenu(title: title)
                submenu.autoenablesItems = false
                submenu.delegate = target as? NSMenuDelegate
                submenu.axRootElement = sub
                item.submenu = submenu
            } else if item.isEnabled {
                item.target = target
                item.action = action
            }
            if !isSubmenu, isFirst || isApple {
                item.attributedTitle = NSAttributedString(string: title, attributes: [.font: boldFont])
                if !isApple { isFirst = false }
            }
            if isApple { appleItem = item; continue }
            if needsSeparator, !items.isEmpty { items.append(.separator()) }
            needsSeparator = false
            items.append(item)
        }
        if let appleItem {
            if items.last?.isSeparatorItem == false { items.append(.separator()) }
            items.append(appleItem)
        }
        return items
    }
}

private var axRootElementKey: UInt8 = 0

extension NSMenu {
    /// Elemento AX do submenu, lido sob demanda em menuNeedsUpdate.
    var axRootElement: AXUIElement? {
        get {
            guard let object = objc_getAssociatedObject(self, &axRootElementKey) else { return nil }
            return (object as! AXUIElement)
        }
        set { objc_setAssociatedObject(self, &axRootElementKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

private extension AXUIElement {
    func axString(_ name: String) -> String? { axAttribute(name) as? String }

    func axParent() -> AXUIElement? {
        guard let parent = axAttribute(kAXParentAttribute), CFGetTypeID(parent as CFTypeRef) == AXUIElementGetTypeID() else { return nil }
        return (parent as! AXUIElement)
    }

    func axAttribute(_ name: String) -> Any? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success ? value : nil
    }

    func axChildren() -> [AXUIElement]? {
        guard let children = axAttribute("AXChildren") as? [AXUIElement], !children.isEmpty else { return nil }
        return children
    }

    func axAttributes(_ names: [String]) -> [String: Any]? {
        var values: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(self, names as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &values) == .success,
              let results = values as? [Any], results.count == names.count else { return nil }
        var dict: [String: Any] = [:]
        for (index, value) in results.enumerated() where !(value is NSNull) { dict[names[index]] = value }
        return dict.isEmpty ? nil : dict
    }
}

private extension NSEvent.ModifierFlags {
    /// AXMenuItemCmdModifiers: bits 1 Shift, 2 Option, 4 Control, 8 = SEM Command.
    static func fromAXModifiers(_ mods: Int?) -> NSEvent.ModifierFlags {
        guard let mods else { return [.command] }
        var flags: NSEvent.ModifierFlags = []
        if mods & 1 != 0 { flags.insert(.shift) }
        if mods & 2 != 0 { flags.insert(.option) }
        if mods & 4 != 0 { flags.insert(.control) }
        if mods & 8 == 0 { flags.insert(.command) }
        return flags
    }
}
