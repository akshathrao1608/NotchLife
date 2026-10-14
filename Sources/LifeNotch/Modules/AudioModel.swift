import Foundation
import AppKit
import CoreAudio

// AudioModel.swift
// Sound controls for the whole Mac: volume, mute, and which speakers / headphones are used.
// Uses Apple's public CoreAudio calls and the standard "volume settings" command. It changes things only
// when YOU move the slider or tap a device. (Per-app volume and equalizers are not possible: macOS gives
// apps no public way to change another app's sound.)

struct AudioOutput: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
}

final class AudioModel: ObservableObject {
    @Published private(set) var outputs: [AudioOutput] = []
    @Published private(set) var currentID: AudioDeviceID = 0
    @Published var volume: Double = 0.5
    @Published private(set) var muted = false
    @Published private(set) var volumeAvailable = true

    func refresh() {
        outputs = Self.listOutputs()
        currentID = Self.defaultOutput()
        let info = Self.volumeSettings()
        volumeAvailable = info.volume != nil
        if let v = info.volume { volume = Double(v) / 100 }
        muted = info.muted
    }

    func setVolume(_ value: Double) {
        volume = min(max(value, 0), 1)
        _ = Self.run("set volume output volume \(Int((volume * 100).rounded()))")
    }

    func setMuted(_ on: Bool) {
        muted = on
        _ = Self.run("set volume output muted \(on ? "true" : "false")")
    }

    func select(_ output: AudioOutput) {
        var id = output.id
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
                                                UInt32(MemoryLayout<AudioDeviceID>.size), &id)
        if status == noErr { currentID = output.id }
        refresh()
    }

    // MARK: Helpers

    private static func run(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        return NSAppleScript(source: source)?.executeAndReturnError(&error)
    }

    private static func volumeSettings() -> (volume: Int?, muted: Bool) {
        let volume = run("output volume of (get volume settings)")
        let muted = run("output muted of (get volume settings)")
        // Some outputs (HDMI, some displays) have no software volume; then the answer is "missing value".
        let v: Int? = (volume?.stringValue).flatMap { Int($0) }
        return (v, muted?.booleanValue ?? false)
    }

    private static func defaultOutput() -> AudioDeviceID {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return id
    }

    private static func listOutputs() -> [AudioOutput] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            guard hasOutputs(id), let name = deviceName(id) else { return nil }
            return AudioOutput(id: id, name: name)
        }
    }

    private static func hasOutputs(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams,
                                                 mScope: kAudioObjectPropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func deviceName(_ id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name)
        guard status == noErr, let cf = name?.takeRetainedValue() else { return nil }
        return cf as String
    }
}
