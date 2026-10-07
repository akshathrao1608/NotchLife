import AppKit

// NotchGeometry.swift
// Works out how big the camera notch is on THIS screen, using Apple's public screen APIs
// (safeAreaInsets and auxiliaryTopLeftArea / auxiliaryTopRightArea).
// On Macs/displays without a notch we draw a small pill-shaped bar instead.

struct NotchGeometry: Equatable {
    var screenWidth: CGFloat = 1512
    var notchWidth: CGFloat = 190
    var notchHeight: CGFloat = 34
    var hasHardwareNotch = true

    static func detect(screen: NSScreen) -> NotchGeometry {
        let topInset = screen.safeAreaInsets.top
        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = screen.frame.width - left.width - right.width
            return NotchGeometry(screenWidth: screen.frame.width,
                                 notchWidth: max(width, 100),
                                 notchHeight: topInset,
                                 hasHardwareNotch: true)
        }
        return NotchGeometry(screenWidth: screen.frame.width,
                             notchWidth: 0,
                             notchHeight: 30,
                             hasHardwareNotch: false)
    }

    /// Prefer the built-in display that has the notch, otherwise the main screen.
    static func targetScreen() -> NSScreen {
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) { return notched }
        return NSScreen.main ?? NSScreen.screens[0]
    }
}
