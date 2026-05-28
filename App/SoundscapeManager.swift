import AVFoundation
import Foundation

/// AVFoundation-based audio feedback engine for Kanban events.
///
/// Synthesises all PCM buffers at init time so every `play*()` call is lock-free
/// and instant. Accessed only on @MainActor; AVAudioEngine handles its own
/// audio-thread scheduling internally.
@MainActor
final class SoundscapeManager {

    // MARK: - Singleton

    static let shared = SoundscapeManager()

    // MARK: - Private State

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100

    // Pre-computed buffers — nil when synthesis or engine setup fails
    private let hoverBuffer: AVAudioPCMBuffer?
    private let dropBuffer: AVAudioPCMBuffer?
    private let launchBuffer: AVAudioPCMBuffer?
    private let completeBuffer: AVAudioPCMBuffer?

    // MARK: - Mute Control

    /// When `true`, all play calls are silently ignored.
    /// Backed by UserDefaults so the setting survives relaunches.
    var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: "soundscape.muted") }
        set { UserDefaults.standard.set(newValue, forKey: "soundscape.muted") }
    }

    // MARK: - Init

    private init() {
        // Connect player → mixer → output
        engine.attach(player)
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )

        if let fmt = format {
            engine.connect(player, to: engine.mainMixerNode, format: fmt)
        }

        // Pre-synthesise all buffers before starting the engine
        hoverBuffer   = SoundscapeManager.makeHoverBuffer(sampleRate: 44_100)
        dropBuffer    = SoundscapeManager.makeDropBuffer(sampleRate: 44_100)
        launchBuffer  = SoundscapeManager.makeLaunchBuffer(sampleRate: 44_100)
        completeBuffer = SoundscapeManager.makeCompleteBuffer(sampleRate: 44_100)

        do {
            try engine.start()
        } catch {
            // No audio output — all play calls will silently no-op
        }
    }

    // MARK: - Public API

    /// Subtle tick when a dragged card first enters a valid drop column.
    func playCardHover() {
        play(hoverBuffer)
    }

    /// Satisfying thud when a card is successfully placed in a column.
    func playCardDrop() {
        play(dropBuffer)
    }

    /// Ascending two-note chime when an agent terminal is opened.
    func playAgentLaunch() {
        play(launchBuffer)
    }

    /// Three-note ascending arpeggio when an issue is closed.
    func playTaskComplete() {
        play(completeBuffer)
    }

    // MARK: - Playback

    private func play(_ buffer: AVAudioPCMBuffer?) {
        guard !isMuted, let buffer else { return }

        // Attempt lazy restart after audio device changes, etc.
        if !engine.isRunning {
            try? engine.start()
        }
        guard engine.isRunning else { return }

        // .interrupts stops any currently-playing sound so rapid events
        // never pile up into an ugly overlap.
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    // MARK: - Sound Synthesis

    /// A note descriptor used by `makeTone`.
    private struct Note {
        let freq: Double
        let startTime: Double   // seconds from buffer start
        let duration: Double    // seconds
        let amplitude: Float
    }

    /// Generates a stereo Float32 PCM buffer containing one or more
    /// sine-wave notes with a simple ADSR envelope per note.
    ///
    /// - Parameters:
    ///   - notes: Individual tone segments.
    ///   - totalDuration: Total buffer length in seconds.
    ///   - sampleRate: Samples per second.
    private static func makeTone(
        notes: [Note],
        totalDuration: Double,
        sampleRate: Double
    ) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        ) else { return nil }

        let frameCount = AVAudioFrameCount(sampleRate * totalDuration)
        guard frameCount > 0 else { return nil }

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount

        guard let channels = buffer.floatChannelData else { return nil }
        let left  = channels[0]
        let right = channels[1]

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            var sample: Float = 0

            for note in notes {
                let end = note.startTime + note.duration
                guard t >= note.startTime, t < end else { continue }

                let localT = t - note.startTime
                let progress = localT / note.duration

                // ADSR envelope — fixed attack/decay, sustain + release fills the rest
                let attackTime: Double = 0.010
                let decayTime: Double  = 0.040
                let sustainLevel: Float = 0.75
                let releaseTime: Double = min(0.12, note.duration * 0.35)

                let envelope: Float
                if localT < attackTime {
                    // Attack
                    envelope = Float(localT / attackTime)
                } else if localT < attackTime + decayTime {
                    // Decay
                    let d = (localT - attackTime) / decayTime
                    envelope = 1.0 - Float(d) * (1.0 - sustainLevel)
                } else if progress > 1.0 - releaseTime / note.duration {
                    // Release
                    let rel = (note.duration - localT) / releaseTime
                    envelope = sustainLevel * Float(max(rel, 0.0))
                } else {
                    // Sustain
                    envelope = sustainLevel
                }

                let phase = 2.0 * Double.pi * note.freq * localT
                sample += Float(sin(phase)) * note.amplitude * envelope
            }

            // Soft clip to avoid any accidental clipping artefacts
            let clipped = max(-0.99, min(0.99, sample))
            left[frame]  = clipped
            right[frame] = clipped
        }

        return buffer
    }

    // MARK: - Per-Event Buffer Factories

    /// Soft 380 Hz sine tick — card enters drop column.
    private static func makeHoverBuffer(sampleRate: Double) -> AVAudioPCMBuffer? {
        makeTone(
            notes: [Note(freq: 380, startTime: 0, duration: 0.06, amplitude: 0.04)],
            totalDuration: 0.06,
            sampleRate: sampleRate
        )
    }

    /// Low 100 Hz thud + 500 Hz click layer — card placed in column.
    private static func makeDropBuffer(sampleRate: Double) -> AVAudioPCMBuffer? {
        makeTone(
            notes: [
                Note(freq: 100,  startTime: 0.000, duration: 0.14, amplitude: 0.12),
                Note(freq: 500,  startTime: 0.000, duration: 0.06, amplitude: 0.08),
                Note(freq: 1200, startTime: 0.005, duration: 0.03, amplitude: 0.04)
            ],
            totalDuration: 0.15,
            sampleRate: sampleRate
        )
    }

    /// 440 Hz → 660 Hz ascending two-note chime — agent terminal opened.
    private static func makeLaunchBuffer(sampleRate: Double) -> AVAudioPCMBuffer? {
        makeTone(
            notes: [
                Note(freq: 440, startTime: 0.00, duration: 0.22, amplitude: 0.10),
                Note(freq: 660, startTime: 0.18, duration: 0.20, amplitude: 0.10)
            ],
            totalDuration: 0.38,
            sampleRate: sampleRate
        )
    }

    /// C5→E5→G5 (523→659→784 Hz) staggered arpeggio — issue closed.
    private static func makeCompleteBuffer(sampleRate: Double) -> AVAudioPCMBuffer? {
        makeTone(
            notes: [
                Note(freq: 523, startTime: 0.00, duration: 0.22, amplitude: 0.09),
                Note(freq: 659, startTime: 0.14, duration: 0.22, amplitude: 0.09),
                Note(freq: 784, startTime: 0.28, duration: 0.27, amplitude: 0.09)
            ],
            totalDuration: 0.55,
            sampleRate: sampleRate
        )
    }
}
