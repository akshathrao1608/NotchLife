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

    /// Each shortcut gets its own number so several can live side by side.
    private let identifier: UInt32
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(identifier: UInt32 = 1) {
        self.identifier = identifier
    }

    deinit { unregister() }

    /// Registers (or re-registers) the shortcut. Returns false if another app already owns it.
    @discardableResult
    func register(_ choice: HotKeyChoice) -> Bool {
        register(keyCode: choice.keyCode, modifiers: choice.carbonModifiers)
    }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> Bool {
        unregister()
        installHandlerIfNeeded()
        let hotKeyID = EventHotKeyID(signature: OSType(0x4C4E5443), id: identifier) // 'LNTC'
        let status = RegisterEventHotKey(keyCode,
                                         modifiers,
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
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event = event, let userData = userData else { return OSStatus(eventNotHandledErr) }
            // Which shortcut was pressed? Ignore the ones that belong to another manager.
            var pressed = EventHotKeyID()
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &pressed)
            guard status == noErr else { return status }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            guard pressed.id == manager.identifier else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async { manager.onTrigger?() }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
    }
}
