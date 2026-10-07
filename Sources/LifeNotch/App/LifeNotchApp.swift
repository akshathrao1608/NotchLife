import SwiftUI

// LifeNotchApp.swift
// The front door of the app. LifeNotch has no normal window: the notch panel is created
// by the AppDelegate. SwiftUI just needs *a* scene, so we give it an empty Settings scene.

@main
struct LifeNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
