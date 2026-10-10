import Foundation
import IOKit.pwr_mgt

// KeepAwake.swift
// Stops your Mac's screen from going to sleep for a while, using Apple's public power-assertion call
// (the same thing "caffeinate" uses). It changes NO system settings: when you stop it, or quit
// LifeNotch, everything goes back to normal automatically.

final class KeepAwakeModel: ObservableObject {
    @Published private(set) var isOn = false
    @Published private(set) var until: Date?

    private var assertionID = IOPMAssertionID(0)
    private var timer: Timer?

    deinit { release() }

    /// minutes == nil means "until I turn it off".
    func start(minutes: Int?) {
        stop()
        let status = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                                 IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 "LifeNotch Keep Awake" as CFString,
                                                 &assertionID)
        guard status == kIOReturnSuccess else { return }
        isOn = true
        if let minutes = minutes {
            let end = Date().addingTimeInterval(TimeInterval(minutes * 60))
            until = end
            timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
                self?.stop()
            }
        }
    }

    func stop() {
        release()
        isOn = false
        until = nil
        timer?.invalidate()
        timer = nil
    }

    private func release() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }
}
