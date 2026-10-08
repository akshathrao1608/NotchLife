import SwiftUI

// NotchState.swift
// The "brain" of the notch's open/closed status. Screens watch this object, so when `mode`
// changes from .collapsed to .expanded the animation plays automatically.

final class NotchState: ObservableObject {
    enum Mode {
        case collapsed   // just the slim bar beside the camera notch
        case preview     // hovered: the bar grows slightly and shows a quick peek
        case expanded    // clicked: the full panel with all 8 tabs
    }

    @Published var mode: Mode = .collapsed
    @Published var geometry = NotchGeometry()
    @Published var selectedTab: NotchTab = .ai
    @Published var macFunSection: MacFunSection = .focus
    /// Set by "Random Fun" so the Games tab can jump straight into a game.
    @Published var pendingGame: GameKind?
    /// How big the open panel is (from Settings).
    @Published var panelSize: PanelSize = .normal

    /// Width available to the left / right of the camera notch in the compact bar.
    @Published var leftSide: CGFloat = 150
    @Published var rightSide: CGFloat = 150

    /// The controller (which owns the real macOS window) plugs itself in here.
    var onRequestMode: ((Mode) -> Void)?

    func request(_ mode: Mode) { onRequestMode?(mode) }
    func collapse() { request(.collapsed) }

    func open(_ tab: NotchTab) {
        selectedTab = tab
        request(.expanded)
    }

    func toggle() {
        request(mode == .expanded ? .collapsed : .expanded)
    }

    /// The visible size of the black shape for each mode.
    func size(for mode: Mode) -> CGSize {
        let compactWidth = geometry.notchWidth + leftSide + rightSide
        switch mode {
        case .collapsed:
            return CGSize(width: compactWidth, height: geometry.notchHeight)
        case .preview:
            return CGSize(width: compactWidth + 24, height: geometry.notchHeight + 46)
        case .expanded:
            let base = panelSize.size
            let width = min(base.width, max(geometry.screenWidth - 80, compactWidth))
            return CGSize(width: max(width, compactWidth), height: base.height)
        }
    }

    /// Extra transparent space around the shape (room for the glow theme's shadow).
    func padding(for mode: Mode) -> CGFloat {
        mode == .expanded ? 24 : 0
    }

    // MARK: Compact bar layout

    private static func chipsWidth(_ widths: [CGFloat]) -> CGFloat {
        guard !widths.isEmpty else { return 34 }
        return widths.reduce(0, +) + CGFloat(widths.count - 1) * 8 + 28
    }

    /// Re-calculates the layout from your settings: how wide each side of the compact bar is,
    /// and how big the open panel is.
    func recomputeCompactWidths(_ p: Preferences) {
        if panelSize != p.panelSize { panelSize = p.panelSize }

        // Medium shows icons only; Large also shows text. (Timer and unread count keep their numbers.)
        let iconsOnly = p.compactStyle != .large
        func w(_ full: CGFloat, keepsText: Bool = false) -> CGFloat {
            (iconsOnly && !keepsText) ? 22 : full
        }
        var left: [CGFloat] = []
        if p.showAssignmentChip { left.append(w(74)) }
        if p.showCountdownChip && p.countdownSource != .off { left.append(w(66)) }
        if p.showTimerChip { left.append(58) }
        if p.notchAnimation != .none { left.append(30) }

        var right: [CGFloat] = []
        if p.showMessagesChip && p.messagesEnabled { right.append(40) }
        if p.showBestScoreChip { right.append(w(64)) }
        if p.showAIChip { right.append(24) }
        if p.showBrowserChip { right.append(24) }
        if p.showBattery { right.append(w(48)) }
        if p.showWifi { right.append(22) }
        if p.showTime { right.append(52) }

        // Both sides get the SAME width so the gap for the camera notch stays exactly centred.
        var side = max(Self.chipsWidth(left), Self.chipsWidth(right))
        if let fixed = p.compactStyle.fixedSideWidth { side = fixed }       // Tiny and Small are fixed
        if p.compactSideWidth > 0 { side = CGFloat(p.compactSideWidth) }   // your own width wins
        if side != leftSide { leftSide = side }
        if side != rightSide { rightSide = side }
    }
}
