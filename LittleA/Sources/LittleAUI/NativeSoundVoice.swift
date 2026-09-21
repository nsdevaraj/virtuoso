import AVFoundation

final class NativeSoundVoice {
    let clip: String
    private let engine: AVAudioEngine
    private let node: AVAudioSourceNode
    private let samples: NativeSoundSamples
    private var attached = true

    init(engine: AVAudioEngine, clip: String, buffer: NativeSoundBuffer,
         looping: Bool, controls: NativeSoundControls, offset: TimeInterval = 0) throws {
        self.engine = engine
        self.clip = clip
        samples = NativeSoundSamples(buffer: buffer, looping: looping, controls: controls)
        try samples.seek(seconds: offset)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: buffer.sampleRate, channels: 2) else {
            throw NativeSoundError.invalidSamples
        }
        let state = samples
        node = AVAudioSourceNode(format: format) { _, _, count, output in
            let channels = UnsafeMutableAudioBufferListPointer(output)
            guard channels.count == 2, let left = channels[0].mData, let right = channels[1].mData else {
                return kAudio_ParamError
            }
            state.render(left: left.assumingMemoryBound(to: Float.self),
                         right: right.assumingMemoryBound(to: Float.self), count: Int(count))
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    deinit { stop() }

    var isFinished: Bool { samples.isFinished }
    func play() { samples.play() }
    func pause() { samples.pause() }
    func update(_ controls: NativeSoundControls) { samples.setControls(controls) }

    func stop() {
        samples.stop()
        guard attached else { return }
        attached = false
        engine.disconnectNodeOutput(node)
        engine.detach(node)
    }

    static func decode(_ url: URL, remainingBytes: Int) throws -> NativeSoundBuffer {
        let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = file.processingFormat
        guard (1...2).contains(format.channelCount), file.length > 0 else {
            throw NativeSoundError.invalidSamples
        }
        guard file.length <= Int64(remainingBytes / (2 * MemoryLayout<Float>.size)),
              file.length <= Int64(UInt32.max) else {
            throw NativeSoundError.tooLarge
        }
        guard let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw NativeSoundError.invalidSamples
        }
        try file.read(into: pcm)
        guard pcm.frameLength > 0, let channels = pcm.floatChannelData else {
            throw NativeSoundError.invalidSamples
        }
        let left = Array(UnsafeBufferPointer(start: channels[0], count: Int(pcm.frameLength)))
        let right = format.channelCount == 1 ? left
            : Array(UnsafeBufferPointer(start: channels[1], count: Int(pcm.frameLength)))
        return try NativeSoundBuffer(left: left, right: right, sampleRate: format.sampleRate)
    }
}
