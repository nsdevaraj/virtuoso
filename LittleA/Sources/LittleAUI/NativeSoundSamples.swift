import Foundation

struct NativeSoundControls {
    let gain: Float
    let pitch: Float
    let pan: Float
    let fade: Float

    init(gain: Float, pitch: Float = 1, pan: Float = 0, fade: Float = 0) throws {
        guard gain.isFinite, gain >= 0, pitch.isFinite, (0.0625...16).contains(pitch),
              pan.isFinite, (-1...1).contains(pan), fade.isFinite, (0...3600).contains(fade) else {
            throw NativeSoundError.invalidControls
        }
        self.gain = gain
        self.pitch = pitch
        self.pan = pan
        self.fade = fade
    }
}

enum NativeSoundError: LocalizedError {
    case invalidControls
    case invalidSamples
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .invalidControls: return "Invalid native sound gain, pitch, pan, or fade."
        case .invalidSamples: return "Interactive audio requires nonempty, finite mono or stereo PCM."
        case .tooLarge: return "Interactive decoded audio exceeds the 64 MiB cache limit."
        }
    }
}

struct NativeSoundBuffer {
    let left: [Float]
    let right: [Float]
    let sampleRate: Double
    var byteCount: Int { (left.count + right.count) * MemoryLayout<Float>.size }

    init(left: [Float], right: [Float], sampleRate: Double) throws {
        guard !left.isEmpty, left.count == right.count, left.allSatisfy(\.isFinite),
              right.allSatisfy(\.isFinite), sampleRate.isFinite, (8000...192000).contains(sampleRate) else {
            throw NativeSoundError.invalidSamples
        }
        self.left = left
        self.right = right
        self.sampleRate = sampleRate
    }
}

// Controls and the render callback share only this bounded PCM state. Fades use
// sample time, so even a 3 ms attack is smooth and pausing freezes the envelope.
final class NativeSoundSamples {
    private let lock = NSLock()
    private let buffer: NativeSoundBuffer
    private let looping: Bool
    private var position: Double = 0
    private var gain: Float = 0
    private var targetGain: Float = 0
    private var remainingFade: Int = 0
    private var pitch: Double = 1
    private var pan: Float = 0
    private var active = false
    private var finished = false

    init(buffer: NativeSoundBuffer, looping: Bool, controls: NativeSoundControls) {
        self.buffer = buffer
        self.looping = looping
        setControls(controls)
    }

    var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return finished
    }

    func setControls(_ controls: NativeSoundControls) {
        lock.lock()
        defer { lock.unlock() }
        targetGain = controls.gain
        pitch = Double(controls.pitch)
        pan = controls.pan
        remainingFade = Int(Double(controls.fade) * buffer.sampleRate)
        if remainingFade == 0 { gain = targetGain }
    }

    func seek(seconds: Double) throws {
        let frame = seconds * buffer.sampleRate
        guard frame.isFinite, frame >= 0 else { throw NativeSoundError.invalidControls }
        lock.lock()
        defer { lock.unlock() }
        position = looping ? frame.truncatingRemainder(dividingBy: Double(buffer.left.count)) : frame
        finished = !looping && position >= Double(buffer.left.count)
    }

    func play() {
        lock.lock()
        defer { lock.unlock() }
        active = true
    }

    func pause() {
        lock.lock()
        defer { lock.unlock() }
        active = false
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        active = false
        finished = true
    }

    func render(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, count: Int) {
        lock.lock()
        defer { lock.unlock() }
        let frames = buffer.left.count
        for output in 0..<count {
            guard active, !finished else {
                left[output] = 0
                right[output] = 0
                continue
            }
            let index = Int(position)
            let next = index + 1 < frames ? index + 1 : (looping ? 0 : index)
            let fraction = Float(position - Double(index))
            if remainingFade > 0 {
                gain += (targetGain - gain) / Float(remainingFade)
                remainingFade -= 1
            }
            let l = buffer.left[index] + (buffer.left[next] - buffer.left[index]) * fraction
            let r = buffer.right[index] + (buffer.right[next] - buffer.right[index]) * fraction
            left[output] = l * gain * (1 - max(0, pan))
            right[output] = r * gain * (1 + min(0, pan))
            position += pitch
            if position >= Double(frames) {
                if looping { position.formTruncatingRemainder(dividingBy: Double(frames)) }
                else { finished = true }
            }
        }
    }
}
