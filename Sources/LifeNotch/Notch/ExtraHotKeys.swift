import AppKit
import Combine
import Carbon.HIToolbox

// ExtraHotKeys.swift
// Optional global shortcuts (all use Control + Option, none need a permission):
//   S = ask AI about part of the screen, X = copy text from part of the screen,
//   arrows / Return / C = snap the front window (only if you turn that on; it needs Accessibility).

final class ExtraHotKeys {
    private let env: AppEnvironment
    private var capture: [HotKeyManager] = []
    private var windows: [(HotKeyManager, SnapZone)] = []
    private var cancellables = Set<AnyCancellable>()
    private var captureOn = false
    private var windowsOn = false

    init(env: AppEnvironment) {
        self.env = env

        let ask = HotKeyManager(identifier: 3)
        ask.onTrigger = { [weak env] in Task { await env?.capture.askAI() } }
        let grab = HotKeyManager(identifier: 4)
        grab.onTrigger = { [weak env] in Task { await env?.capture.textGrab() } }
        capture = [ask, grab]
        keysForCapture = [(ask, UInt32(kVK_ANSI_S)), (grab, UInt32(kVK_ANSI_X))]

        let map: [(UInt32, SnapZone)] = [
            (UInt32(kVK_LeftArrow), .leftHalf), (UInt32(kVK_RightArrow), .rightHalf),
            (UInt32(kVK_UpArrow), .topHalf), (UInt32(kVK_DownArrow), .bottomHalf),
            (UInt32(kVK_Return), .maximize), (UInt32(kVK_ANSI_C), .center)
        ]
        for (index, entry) in map.enumerated() {
            let manager = HotKeyManager(identifier: UInt32(10 + index))
            let zone = entry.1
            manager.onTrigger = { [weak env] in
                guard let env = env else { return }
                _ = env.snapper.snap(zone, settings: env.settings)
            }
            windows.append((manager, zone))
            keysForWindows.append((manager, entry.0))
        }

        env.settings.$prefs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] prefs in self?.update(prefs) }
            .store(in: &cancellables)
    }

    private var keysForCapture: [(HotKeyManager, UInt32)] = []
    private var keysForWindows: [(HotKeyManager, UInt32)] = []

    private func update(_ prefs: Preferences) {
        let mods = UInt32(controlKey | optionKey)
        if prefs.captureHotKeysEnabled != captureOn {
            captureOn = prefs.captureHotKeysEnabled
            for (manager, key) in keysForCapture {
                if captureOn { manager.register(keyCode: key, modifiers: mods) } else { manager.unregister() }
            }
        }
        if prefs.windowHotKeysEnabled != windowsOn {
            windowsOn = prefs.windowHotKeysEnabled
            for (manager, key) in keysForWindows {
                if windowsOn { manager.register(keyCode: key, modifiers: mods) } else { manager.unregister() }
            }
        }
    }
}
