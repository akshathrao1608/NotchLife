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
        var p = Path()
        // start at top-left corner of the screen edge
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // concave curve: top edge bends down into the left side
        p.addQuadCurve(to: CGPoint(x: rect.minX + t, y: rect.minY + t),
                       control: CGPoint(x: rect.minX + t, y: rect.minY))
        // left side down
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY - b))
        // rounded bottom-left
        p.addQuadCurve(to: CGPoint(x: rect.minX + t + b, y: rect.maxY),
                       control: CGPoint(x: rect.minX + t, y: rect.maxY))
        // bottom edge
        p.addLine(to: CGPoint(x: rect.maxX - t - b, y: rect.maxY))
        // rounded bottom-right
        p.addQuadCurve(to: CGPoint(x: rect.maxX - t, y: rect.maxY - b),
                       control: CGPoint(x: rect.maxX - t, y: rect.maxY))
        // right side up
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY + t))
        // concave curve into the top-right of the screen edge
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.maxX - t, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
