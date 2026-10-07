import AppKit
import SwiftUI
import Combine

// NotchPanelController.swift
// Owns the real macOS window and decides WHEN it opens, closes, grows and shrinks.
//
// How the animation works (simple version):
//  - The SwiftUI view draws the black shape and animates its size with a spring.
//  - The window itself has to be at least as big as the shape, otherwise the shape would be cut
//    off. So before growing we make the window big first, and after shrinking we wait for the
//    animation to finish and THEN shrink the window. (A big see-through window left over the top
//    of the screen would block clicks on whatever is underneath.)

final class NotchPanelController {
    private let env: AppEnvironment
    let panel: NotchPanel

    private let container = NotchContainerView()
    private let hotKey = HotKeyManager()
    private var cancellables = Set<AnyCancellable>()

    private var generation = 0
    private var hoverWork: DispatchWorkItem?
    private var previewPoller: Timer?
    private var outsideClickMonitor: Any?
    private var registeredHotKey: HotKeyChoice?
    private var registeredHotKeyEnabled = false

    init(env: AppEnvironment) {
        self.env = env
        panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 40))

        let root = NotchRootView().injectEnvironment(env)
        let hosting = FirstMouseHostingView(rootView: AnyView(root))
        hosting.sizingOptions = []   // don't let SwiftUI resize our window by itself
        hosting.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        panel.contentView = container

        container.onMouseEnter = { [weak self] in self?.hoverEntered() }
        container.onMouseExit = { [weak self] in self?.hoverExited() }
        panel.keyHandler = { [weak self] event in self?.handleKey(event) ?? false }

        env.notch.selectedTab = env.settings.prefs.lastTab
        env.notch.macFunSection = env.settings.prefs.lastMacFunSection
        env.notch.onRequestMode = { [weak self] mode in self?.setMode(mode) }

        hotKey.onTrigger = { [weak self] in self?.env.notch.toggle() }

        // React to settings changes (compact bar width, shortcut choice).
        env.settings.$prefs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prefs in self?.prefsChanged(prefs) }
            .store(in: &cancellables)

        // Remember the last tab you used.
        env.notch.$selectedTab
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tab in
                guard let self = self else { return }
                if self.env.settings.prefs.lastTab != tab { self.env.settings.prefs.lastTab = tab }
            }
            .store(in: &cancellables)

        env.notch.$macFunSection
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] section in
                guard let self = self else { return }
                if self.env.settings.prefs.lastMacFunSection != section { self.env.settings.prefs.lastMacFunSection = section }
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            self?.refreshGeometry()
        }

        refreshGeometry()
    }

    // MARK: Showing

    func show() {
        refreshGeometry()
        panel.orderFrontRegardless()
    }

    private func targetScreen() -> NSScreen { NotchGeometry.targetScreen() }

    private func refreshGeometry() {
        let screen = targetScreen()
        env.notch.geometry = NotchGeometry.detect(screen: screen)
        env.notch.recomputeCompactWidths(env.settings.prefs)
        panel.setFrame(frame(for: env.notch.mode, on: screen), display: true)
    }

    private func frame(for mode: NotchState.Mode, on screen: NSScreen) -> NSRect {
        let size = env.notch.size(for: mode)
        let pad = env.notch.padding(for: mode)
        let width = size.width + pad * 2
        let height = size.height + pad
        return NSRect(x: screen.frame.midX - width / 2,
                      y: screen.frame.maxY - height,
                      width: width,
                      height: height)
    }

    private func prefsChanged(_ prefs: Preferences) {
        env.notch.recomputeCompactWidths(prefs)
        if env.notch.mode != .expanded {
            panel.setFrame(frame(for: env.notch.mode, on: targetScreen()), display: true)
        }
        if registeredHotKey != prefs.hotKey || registeredHotKeyEnabled != prefs.globalHotKeyEnabled {
            registeredHotKey = prefs.hotKey
            registeredHotKeyEnabled = prefs.globalHotKeyEnabled
            if prefs.globalHotKeyEnabled {
                let ok = hotKey.register(prefs.hotKey)
                env.hotKeyRegistrationFailed = !ok
            } else {
                hotKey.unregister()
                env.hotKeyRegistrationFailed = false
            }
        }
    }

    // MARK: Changing mode (the animation)

    func setMode(_ newMode: NotchState.Mode) {
        let notch = env.notch
        let oldMode = notch.mode
        guard newMode != oldMode else { return }

        generation += 1
        let myGeneration = generation
        let screen = targetScreen()
        let oldFrame = frame(for: oldMode, on: screen)
        let newFrame = frame(for: newMode, on: screen)

        // 1. Make the window big enough for BOTH sizes while the animation runs.
        panel.setFrame(oldFrame.union(newFrame), display: true)

        if newMode == .expanded {
            panel.makeKeyAndOrderFront(nil)
            startOutsideClickMonitor()
        } else if oldMode == .expanded {
            stopOutsideClickMonitor()
        }

        // 2. Play the spring animation.
        withAnimation(env.settings.notchAnimation) {
            notch.mode = newMode
        }

        // 3. When it has settled, shrink the window to exactly fit.
        let delay = env.settings.notchAnimationSettleTime
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, myGeneration == self.generation else { return }
            self.panel.setFrame(self.frame(for: self.env.notch.mode, on: self.targetScreen()), display: true)
        }
    }

    // MARK: Hover to preview

    private func hoverEntered() {
        guard env.settings.prefs.hoverPreview, env.notch.mode == .collapsed else { return }
        hoverWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.env.notch.mode == .collapsed else { return }
            self.setMode(.preview)
            self.startPreviewPoller()
        }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func hoverExited() {
        hoverWork?.cancel()
    }

    /// While in preview, check a few times a second whether the mouse has left, and collapse if so.
    private func startPreviewPoller() {
        previewPoller?.invalidate()
        previewPoller = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] timer in
            guard let self = self, self.env.notch.mode == .preview else {
                timer.invalidate()
                return
            }
            let area = self.panel.frame.insetBy(dx: -6, dy: -6)
            if !area.contains(NSEvent.mouseLocation) {
                timer.invalidate()
                self.setMode(.collapsed)
            }
        }
    }

    // MARK: Click outside to close

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        // A *global* monitor only sees clicks in OTHER apps and needs no permission.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self,
                      self.env.settings.prefs.collapseOnOutsideClick,
                      self.env.notch.mode == .expanded else { return }
                if !self.panel.frame.contains(NSEvent.mouseLocation) {
                    self.setMode(.collapsed)
                }
            }
        }
    }

    private func stopOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    // MARK: Keyboard

    private func handleKey(_ event: NSEvent) -> Bool {
        guard env.notch.mode == .expanded else { return false }

        // Escape closes the panel.
        if event.keyCode == 53 {
            setMode(.collapsed)
            return true
        }

        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let prefs = env.settings.prefs

        // Option + letter shortcuts (only while the notch is open).
        if flags == .option && prefs.tabShortcutsEnabled {
            switch event.keyCode {
            case 0:  env.notch.open(.ai); return true          // Option + A
            case 11: env.notch.open(.browser); return true     // Option + B
            case 1:  env.notch.open(.sports); return true      // Option + S
            case 5:  env.notch.open(.games); return true       // Option + G
            case 17:                                           // Option + T
                env.notch.macFunSection = .focus
                env.notch.open(.macFun)
                return true
            default: break
            }
        }

        // Command + 1...8 switches tabs; Command + C/V/X/A/Z are forwarded to the focused field.
        if flags == .command, let chars = event.charactersIgnoringModifiers {
            if let digit = Int(chars), digit >= 1, digit <= NotchTab.allCases.count {
                env.notch.selectedTab = NotchTab.allCases[digit - 1]
                return true
            }
            switch chars {
            case "v": return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            case "c": return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            case "x": return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            case "a": return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            default: break
            }
        }
        return false
    }
}
