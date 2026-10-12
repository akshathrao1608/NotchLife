import SwiftUI

// NotchShape.swift
// The outline of the black panel.
//  - The two TOP corners curve outwards ("concave") so the bar flows into the top edge of the
//    screen right next to the camera notch, like one connected piece.
//  - The two BOTTOM corners are normal rounded corners.

struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    // These two lines let SwiftUI smoothly animate the corner sizes.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let t = min(topRadius, rect.height / 2, rect.width / 4)
        let b = min(bottomRadius, max(rect.height - t, 0), rect.width / 4)
        // k > 0.5523 gives "continuous" (squircle-like) corners, the same soft feel as Apple's own hardware.
        let k: CGFloat = 0.64
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // concave top-left: leaves the top edge flat, then bends smoothly down
        p.addCurve(to: CGPoint(x: rect.minX + t, y: rect.minY + t),
                   control1: CGPoint(x: rect.minX + t * k, y: rect.minY),
                   control2: CGPoint(x: rect.minX + t, y: rect.minY + t * (1 - k)))
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY - b))
        // rounded bottom-left
        p.addCurve(to: CGPoint(x: rect.minX + t + b, y: rect.maxY),
                   control1: CGPoint(x: rect.minX + t, y: rect.maxY - b * (1 - k)),
                   control2: CGPoint(x: rect.minX + t + b * (1 - k), y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t - b, y: rect.maxY))
        // rounded bottom-right
        p.addCurve(to: CGPoint(x: rect.maxX - t, y: rect.maxY - b),
                   control1: CGPoint(x: rect.maxX - t - b * (1 - k), y: rect.maxY),
                   control2: CGPoint(x: rect.maxX - t, y: rect.maxY - b * (1 - k)))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY + t))
        // concave top-right
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                   control1: CGPoint(x: rect.maxX - t, y: rect.minY + t * (1 - k)),
                   control2: CGPoint(x: rect.maxX - t * k, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
