import AppKit
import ApplicationServices

// WindowSnapper.swift
// Moves and resizes the FRONT window of the app you were using, using Apple's public Accessibility API.
// That API needs the "Accessibility" permission in System Settings. LifeNotch asks you in plain words first,
// and only ever reads and sets the position and size of one window when you press a zone or a shortcut.

enum SnapZone: String, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds
    case center, almostMaximize, maximize

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftHalf: return "Left half"
        case .rightHalf: return "Right half"
        case .topHalf: return "Top half"
        case .bottomHalf: return "Bottom half"
        case .topLeft: return "Top left"
        case .topRight: return "Top right"
        case .bottomLeft: return "Bottom left"
        case .bottomRight: return "Bottom right"
        case .leftThird: return "Left third"
        case .centerThird: return "Middle third"
        case .rightThird: return "Right third"
        case .leftTwoThirds: return "Left two thirds"
        case .rightTwoThirds: return "Right two thirds"
        case .center: return "Center"
        case .almostMaximize: return "Almost maximize"
        case .maximize: return "Maximize"
        }
    }

    /// x, y, width, height as fractions of the screen's usable area (y counts from the TOP).
    var unitRect: CGRect {
        switch self {
        case .leftHalf: return CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf: return CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .topHalf: return CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case .bottomHalf: return CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        case .topLeft: return CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .topRight: return CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .bottomLeft: return CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRight: return CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .leftThird: return CGRect(x: 0, y: 0, width: 1.0 / 3, height: 1)
        case .centerThird: return CGRect(x: 1.0 / 3, y: 0, width: 1.0 / 3, height: 1)
        case .rightThird: return CGRect(x: 2.0 / 3, y: 0, width: 1.0 / 3, height: 1)
        case .leftTwoThirds: return CGRect(x: 0, y: 0, width: 2.0 / 3, height: 1)
        case .rightTwoThirds: return CGRect(x: 1.0 / 3, y: 0, width: 2.0 / 3, height: 1)
        case .center: return CGRect(x: 0.2, y: 0.15, width: 0.6, height: 0.7)
        case .almostMaximize: return CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)
        case .maximize: return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
    }

    /// Pure maths (easy to test): the new window frame inside `area`, both in top-left coordinates.
    func frame(in area: CGRect) -> CGRect {
        let u = unitRect
        return CGRect(x: area.minX + u.minX * area.width,
                      y: area.minY + u.minY * area.height,
                      width: u.width * area.width,
                      height: u.height * area.height)
    }
}

final class WindowSnapper: ObservableObject {
    @Published private(set) var targetName = "none yet"
    @Published var message = ""

    /// The last normal app you used before LifeNotch (LifeNotch itself never takes focus).
    private var target: NSRunningApplication?
    private var observer: NSObjectProtocol?

    init() {
        target = NSWorkspace.shared.frontmostApplication
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  app.activationPolicy == .regular else { return }
            self?.target = app
            self?.targetName = app.localizedName ?? "the front app"
        }
    }

    deinit {
        if let observer = observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    var isTrusted: Bool { AXIsProcessTrusted() }

    /// Asks macOS to show its Accessibility permission screen.
    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    @discardableResult
    func snap(_ zone: SnapZone, settings: AppSettings) -> Bool {
        guard isTrusted else {
            let ok = ConsentGate.request(
                .windowControl, settings: settings,
                explanation: "To move another app's window, macOS requires the Accessibility permission. LifeNotch will only read and set the position and size of the front window when you press a zone or shortcut. It cannot see what is inside windows. After you press Allow, switch LifeNotch on in System Settings > Privacy & Security > Accessibility.")
            if ok { requestPermission() }
            return false
        }
        guard let app = target ?? NSWorkspace.shared.frontmostApplication else {
            message = "Click the window you want to move first."
            return false
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowRef: CFTypeRef?
        var status = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)
        if status != .success { status = AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &windowRef) }
        guard status == .success, let ref = windowRef else {
            message = "\(app.localizedName ?? "That app") has no window LifeNotch can move."
            return false
        }
        let window = ref as! AXUIElement

        // Where is the window now? (top-left coordinates)
        var position = CGPoint.zero
        var size = CGSize.zero
        var valueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &valueRef) == .success, let v = valueRef {
            AXValueGetValue(v as! AXValue, .cgPoint, &position)
        }
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &valueRef) == .success, let v = valueRef {
            AXValueGetValue(v as! AXValue, .cgSize, &size)
        }

        let area = usableArea(forWindowAt: CGRect(origin: position, size: size))
        let target = zone.frame(in: area)

        var newSize = target.size
        var newPosition = target.origin
        // Some apps clamp the size, so set size, then position, then size again.
        if let sizeValue = AXValueCreate(.cgSize, &newSize), let positionValue = AXValueCreate(.cgPoint, &newPosition) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
        message = "Moved \(app.localizedName ?? "window") to \(zone.title.lowercased())."
        return true
    }

    /// The usable part of the screen the window is on, in top-left (Accessibility) coordinates.
    private func usableArea(forWindowAt frame: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        // Convert the window centre to Cocoa (bottom-left) coordinates to find its screen.
        let centre = CGPoint(x: frame.midX, y: primaryHeight - frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(centre) } ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        return CGRect(x: visible.minX, y: primaryHeight - visible.maxY, width: visible.width, height: visible.height)
    }
}
