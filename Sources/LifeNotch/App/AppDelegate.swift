import AppKit

// AppDelegate.swift
// Runs when the app starts. It:
//  - hides the Dock icon (LifeNotch lives in the notch),
//  - creates the notch panel,
//  - adds a small menu-bar icon so you can always open Settings or Quit.

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: NotchPanelController?
    private var statusItem: NSStatusItem?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Receive lifenotch:// links (see URLCommands.swift).
        NSAppleEventManager.shared().setEventHandler(self,
                                                     andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
                                                     forEventClass: AEEventClass(kInternetEventClass),
                                                     andEventID: AEEventID(kAEGetURL))
    }

    @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let text = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: text) else { return }
        DispatchQueue.main.async { URLCommands.handle(url, env: AppEnvironment.shared) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let env = AppEnvironment.shared
        env.start()

        let controller = NotchPanelController(env: env)
        env.panel = controller
        panelController = controller
        controller.show()

        setupStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: Menu-bar icon

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "capsule.tophalf.filled", accessibilityDescription: "LifeNotch")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open / Close LifeNotch", action: #selector(toggleNotch), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit LifeNotch", action: #selector(quit), keyEquivalent: "q"))
        for entry in menu.items { entry.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func toggleNotch() { AppEnvironment.shared.notch.toggle() }
    @objc private func openSettings() { AppEnvironment.shared.notch.open(.settings) }
    @objc private func quit() { NSApp.terminate(nil) }
}
