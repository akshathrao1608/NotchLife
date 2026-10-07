import AppKit
import Carbon.HIToolbox

// HotKeyManager.swift
// Registers the global shortcut (default: Option + Space) that opens/closes the notch from
// ANY app. It uses Apple's public "RegisterEventHotKey" call. Unlike keyboard-spying APIs,
// this needs NO special permission (no Accessibility, no Input Monitoring).

enum HotKeyChoice: String, CaseIterable, Identifiable, Codable {
    case optionSpace, controlSpace, commandShiftSpace
    var id: String { rawValue }

    var title: String {
        switch self {
        case .optionSpace: return "Option + Space"
        case .controlSpace: return "Control + Space"
        case .commandShiftSpace: return "Command + Shift + Space"
        }
    }

    var keyCode: UInt32 { UInt32(kVK_Space) }

    var carbonModifiers: UInt32 {
        switch self {
        case .optionSpace: return UInt32(optionKey)
        case .controlSpace: return UInt32(controlKey)
        case .commandShiftSpace: return UInt32(cmdKey | shiftKey)
        }
    }
}

final class HotKeyManager {
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    deinit { unregister() }

    /// Registers (or re-registers) the shortcut. Returns false if another app already owns it.
    @discardableResult
    func register(_ choice: HotKeyChoice) -> Bool {
        unregister()
        installHandlerIfNeeded()
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C4E5443), id: 1) // 'LNTC'
        let status = RegisterEventHotKey(choice.keyCode,
                                         choice.carbonModifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        return status == noErr
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData = userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onTrigger?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }
}
