import AVFoundation

// AmbientPlayer.swift
// Calm background sounds: rain, café, white noise and racing ambience.
// There are NO audio files: LifeNotch makes the sound itself with simple maths, which is why
// they are "impressions" of rain/café/racing rather than recordings. It only PLAYS sound;
// it never uses the microphone.

enum AmbientSound: String, CaseIterable, Identifiable {
    case rain, cafe, whiteNoise, racing
    var id: String { rawValue }

    var title: String {
        switch self {
        case .rain: return "Rain"
        case .cafe: return "Café"
        case .whiteNoise: return "White noise"
        case .racing: return "Racing ambience"
        }
    }

    var icon: String {
        switch self {
        case .rain: return "cloud.rain"
        case .cafe: return "cup.and.saucer"
        case .whiteNoise: return "waveform"
        case .racing: return "flag.checkered"
        }
    }
}

/// Creates one sample of audio at a time. Runs on the audio thread, so it avoids allocating.
final class AmbientGenerator {
    var kind: AmbientSound = .whiteNoise
    var volume: Float = 0.4

    private let sampleRate: Float = 44_100
    private var rng: UInt32 = 0x1234_5678
    private var low: Float = 0
    private var brown: Float = 0
    private var murmur: Float = 0
    private var mod1: Float = 0, mod2: Float = 0, mod3: Float = 0
    private var phase: Float = 0
    private var time: Float = 0
    private var smoothVolume: Float = 0

    private func white() -> Float {
        rng ^= rng << 13
        rng ^= rng >> 17
        rng ^= rng << 5
        return Float(Int32(bitPattern: rng)) / Float(Int32.max)
    }

    func next() -> Float {
        smoothVolume += (volume - smoothVolume) * 0.0005
        time += 1 / sampleRate
        let w = white()
        var sample: Float

        switch kind {
        case .whiteNoise:
            sample = w * 0.5

        case .rain:
            low += (w - low) * 0.25
            let highs = w - low
            mod1 += (white() * 0.5 - mod1) * 0.0004
            sample = highs * (0.55 + 0.25 * mod1)

        case .cafe:
            brown = (brown + w * 0.02) * 0.995
            murmur += (w - murmur) * 0.06
            mod1 += (white() - mod1) * 0.00015
            mod2 += (white() - mod2) * 0.00023
            mod3 += (white() - mod3) * 0.00031
            let talk = murmur * (abs(mod1) + abs(mod2) + abs(mod3)) * 1.6
            sample = brown * 1.8 + talk * 0.8

        case .racing:
            // A car passing by about every 11 seconds: pitch glides down, volume swells and fades.
            let lap = time.truncatingRemainder(dividingBy: 11) / 11
            let swell = max(0, sin(lap * .pi))
            let frequency = 150 - 70 * lap
            phase += frequency / sampleRate
            if phase > 1 { phase -= 1 }
            var engine: Float = 0
            for harmonic in 1...5 {
                engine += sin(2 * .pi * phase * Float(harmonic)) / Float(harmonic)
            }
            low += (w - low) * 0.05
            sample = engine * 0.18 * swell + low * 0.25
        }
        return max(-1, min(1, sample)) * smoothVolume
    }
}

final class AmbientPlayer: ObservableObject {
    @Published private(set) var current: AmbientSound?
    @Published var volume: Double {
        didSet {
            generator.volume = Float(volume)
            settings.prefs.ambientVolume = volume
        }
    }

    private let settings: AppSettings
    private let generator = AmbientGenerator()
    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?

    init(settings: AppSettings) {
        self.settings = settings
        volume = settings.prefs.ambientVolume
        generator.volume = Float(settings.prefs.ambientVolume)
    }

    func toggle(_ sound: AmbientSound) {
        if current == sound { stop() } else { play(sound) }
    }

    func play(_ sound: AmbientSound) {
        generator.kind = sound
        if node == nil {
            let generator = self.generator
            let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
            let source = AVAudioSourceNode(format: format!) { _, _, frameCount, audioBufferList -> OSStatus in
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for frame in 0..<Int(frameCount) {
                    let value = generator.next()
                    for buffer in buffers {
                        buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = value
                    }
                }
                return noErr
            }
            engine.attach(source)
            engine.connect(source, to: engine.mainMixerNode, format: format)
            node = source
        }
        if !engine.isRunning {
            do { try engine.start() } catch {
                current = nil
                return
            }
        }
        current = sound
    }

    func stop() {
        engine.stop()
        if let node = node {
            engine.detach(node)
            self.node = nil
        }
        current = nil
    }
}
