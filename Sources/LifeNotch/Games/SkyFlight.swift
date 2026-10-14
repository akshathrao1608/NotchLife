import SwiftUI

// SkyFlight.swift
// A tiny flight sim. Your plane stays on the left; rings and storm clouds fly towards you.
// Press Up / Down (or W / S) to climb and dive. Fly through rings to score, avoid the dark clouds.
// The rules are in `SkyFlightState` (pure logic, easy to test). The screen is `SkyFlightView`.

struct SkyObject: Equatable, Identifiable {
    enum Kind { case ring, storm }
    let id = UUID()
    var kind: Kind
    var x: Double      // 0 (left) ... 1 (right)
    var y: Double      // 0 (top) ... 1 (bottom)
}

struct SkyFlightState: Equatable {
    static let planeX = 0.2
    static let hitRadius = 0.075

    var planeY = 0.5
    var velocity = 0.0
    var objects: [SkyObject] = []
    var score = 0
    var alive = true
    var elapsed = 0.0

    var speed: Double { 0.32 + 0.015 * Double(min(score, 30)) }

    mutating func climb() { velocity = -0.85 }
    mutating func dive() { velocity = 0.85 }

    mutating func step<G: RandomNumberGenerator>(dt: Double, using generator: inout G) {
        guard alive else { return }
        elapsed += dt
        velocity *= pow(0.02, dt)               // the plane levels off by itself
        planeY = min(max(planeY + velocity * dt, 0.04), 0.96)

        for index in objects.indices { objects[index].x -= speed * dt }
        objects.removeAll { $0.x < -0.1 }

        // Aspect ratio of the sky is about 2:1, so x distances count double.
        var remaining: [SkyObject] = []
        for object in objects {
            let dx = (object.x - Self.planeX) * 2
            let dy = object.y - planeY
            if (dx * dx + dy * dy).squareRoot() < Self.hitRadius + 0.04 {
                switch object.kind {
                case .ring: score += 1
                case .storm: alive = false
                }
                if object.kind == .ring { continue }
            }
            remaining.append(object)
        }
        objects = remaining

        if (objects.map { $0.x }.max() ?? 0) < 0.75 {
            let isRing = Double.random(in: 0...1, using: &generator) < 0.55
            objects.append(SkyObject(kind: isRing ? .ring : .storm,
                                     x: 1.08,
                                     y: Double.random(in: 0.1...0.9, using: &generator)))
        }
    }
}

struct SkyFlightView: View {
    @EnvironmentObject private var scores: GameScores
    @State private var state = SkyFlightState()
    @State private var running = false
    @State private var savedScore = false

    private let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        KeyCatcher(onKey: handleKey) {
            VStack(spacing: 8) {
                HStack {
                    Text("Rings: \(state.score)").lnFont(13, .bold)
                    Text("Best: \(scores.data.bestSkyFlight.map(String.init) ?? "–")").lnFont(11).foregroundStyle(.secondary)
                    Spacer()
                    if !state.alive { Text("Crashed!").lnFont(12, .bold).foregroundStyle(.red) }
                    Button(running ? "Pause" : (state.alive ? "Take off" : "Fly again")) { startOrPause() }
                        .buttonStyle(LNButtonStyle(prominent: true))
                }
                sky.frame(maxHeight: .infinity)
                Text("Up / Down arrows or W / S to climb and dive · Space to start or pause").lnFont(10).foregroundStyle(.secondary)
            }
        }
        .onReceive(ticker) { _ in tick() }
        .onDisappear { running = false; saveIfNeeded() }
    }

    private var sky: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(Gradient(colors: [Color(red: 0.1, green: 0.3, blue: 0.7), Color(red: 0.6, green: 0.8, blue: 1.0)]),
                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
            for object in state.objects {
                let center = CGPoint(x: object.x * w, y: object.y * h)
                switch object.kind {
                case .ring:
                    let rect = CGRect(x: center.x - 12, y: center.y - 20, width: 24, height: 40)
                    context.stroke(Path(ellipseIn: rect), with: .color(.yellow), lineWidth: 4)
                case .storm:
                    let rect = CGRect(x: center.x - 26, y: center.y - 16, width: 52, height: 32)
                    context.fill(Path(ellipseIn: rect), with: .color(Color(white: 0.2)))
                    context.fill(Path(ellipseIn: rect.insetBy(dx: 12, dy: -8).offsetBy(dx: -6, dy: -4)), with: .color(Color(white: 0.28)))
                }
            }
            let plane = CGPoint(x: SkyFlightState.planeX * w, y: state.planeY * h)
            var body = Path()
            body.move(to: CGPoint(x: plane.x + 18, y: plane.y))
            body.addLine(to: CGPoint(x: plane.x - 14, y: plane.y - 9))
            body.addLine(to: CGPoint(x: plane.x - 8, y: plane.y))
            body.addLine(to: CGPoint(x: plane.x - 14, y: plane.y + 9))
            body.closeSubpath()
            context.fill(body, with: .color(.white))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sky Flight. Rings collected \(state.score)")
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow: state.climb()
        case .downArrow: state.dive()
        case .space: startOrPause()
        default:
            switch press.characters.lowercased() {
            case "w": state.climb()
            case "s": state.dive()
            default: return .ignored
            }
        }
        return .handled
    }

    private func startOrPause() {
        if !state.alive {
            state = SkyFlightState()
            savedScore = false
            running = true
        } else {
            running.toggle()
        }
    }

    private func tick() {
        guard running, state.alive else { return }
        var generator = SystemRandomNumberGenerator()
        let before = state.score
        state.step(dt: 1.0 / 30.0, using: &generator)
        if state.score > before { SoundPlayer.play(.tap) }
        if !state.alive {
            running = false
            SoundPlayer.play(.lose)
            saveIfNeeded()
        }
    }

    private func saveIfNeeded() {
        guard !savedScore else { return }
        savedScore = true
        scores.submitSkyFlight(score: state.score)
    }
}
