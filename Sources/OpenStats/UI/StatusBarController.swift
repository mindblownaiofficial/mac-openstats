import AppKit
import SwiftUI
import Combine

/// Hosting view that lets clicks fall through to the status bar button underneath.
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let store: StatsStore
    private let settings: Settings
    private let popoverState = PopoverState()
    private let popover = NSPopover()
    private var items: [Module: NSStatusItem] = [:]
    private var hosts: [Module: NSView] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var settingsWindow: NSWindow?

    init(store: StatsStore, settings: Settings) {
        self.store = store
        self.settings = settings
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(openSettings: { [weak self] in self?.showSettings() },
                                  quit: { NSApp.terminate(nil) })
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(popoverState)
        )

        rebuild()
        settings.$configs
            .removeDuplicates()
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)
        settings.$refreshInterval
            .sink { [weak self] interval in self?.store.setInterval(interval) }
            .store(in: &cancellables)
        store.$snapshot
            .sink { [weak self] _ in self?.updateWidths() }
            .store(in: &cancellables)
    }

    private var visibleModules: [Module] {
        settings.enabledModules.filter { $0 != .battery || store.hasBattery }
    }

    private func rebuild() {
        for item in items.values { NSStatusBar.system.removeStatusItem(item) }
        items.removeAll()
        hosts.removeAll()

        // Status items are inserted to the left of existing ones, so add in reverse
        // to keep the natural module order from left to right.
        for module in visibleModules.reversed() {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            let host = PassthroughHostingView(rootView: MenuBarItemView(module: module)
                .environmentObject(store)
                .environmentObject(settings))
            host.translatesAutoresizingMaskIntoConstraints = false
            guard let button = item.button else { continue }
            button.title = ""
            button.addSubview(host)
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                host.topAnchor.constraint(equalTo: button.topAnchor),
                host.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            ])
            button.target = self
            button.action = #selector(itemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.identifier = NSUserInterfaceItemIdentifier(module.rawValue)
            items[module] = item
            hosts[module] = host
        }
        updateWidths()
    }

    private func updateWidths() {
        for (module, item) in items {
            guard let host = hosts[module] else { continue }
            let width = host.fittingSize.width
            if abs(item.length - width) > 0.5 { item.length = width }
        }
    }

    @objc private func itemClicked(_ sender: NSStatusBarButton) {
        guard let id = sender.identifier?.rawValue, let module = Module(rawValue: id) else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(for: module, button: sender)
            return
        }
        if popover.isShown {
            let sameModule = popoverState.module == module
            popover.performClose(nil)
            if sameModule { return }
        }
        popoverState.module = module
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        sender.highlight(true)
        NSApp.activate(ignoringOtherApps: true)
    }

    func popoverDidClose(_ notification: Notification) {
        for item in items.values { item.button?.highlight(false) }
    }

    private func showContextMenu(for module: Module, button: NSStatusBarButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "About OpenStats", action: #selector(showAbout), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit OpenStats", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        guard let item = items[module] else { return }
        item.menu = menu
        button.performClick(nil)
        item.menu = nil
    }

    @objc func showSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 520),
                                  styleMask: [.titled, .closable, .miniaturizable],
                                  backing: .buffered, defer: false)
            window.title = "OpenStats Settings"
            window.contentViewController = NSHostingController(rootView: SettingsView().environmentObject(settings))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "OpenStats",
            .applicationVersion: "0.1.0",
            .credits: NSAttributedString(string: "A free, open-source system monitor for the macOS menu bar.\nMIT licensed."),
        ])
    }
}
