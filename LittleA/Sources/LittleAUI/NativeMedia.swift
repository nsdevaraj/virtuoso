import UIKit
import AVFoundation
import LittleA
import LittleAFFI

final class NativeMedia {
    private final class WeakReference: @unchecked Sendable {
        weak var value: NativeMedia?

        init(_ value: NativeMedia) {
            self.value = value
        }
    }

    private struct MediaError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private struct PlainSoundVoice {
        let clip: String
        let player: AVAudioPlayer
    }

    private final class AudioPlayerReference: @unchecked Sendable {
        let player: AVAudioPlayer

        init(_ player: AVAudioPlayer) {
            self.player = player
        }
    }

    private final class VideoAsset {
        let asset: AVURLAsset
        let generator: AVAssetImageGenerator

        init(url: URL) {
            asset = AVURLAsset(url: url)
            generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
        }
    }

    private final class VideoVoice {
        let source: String
        let player: AVPlayer
        var sourceTime: Float
        var frame: Double
        var rate: Float = 1
        var isAdvancing = false
        var lastAdvanceTime = ProcessInfo.processInfo.systemUptime
        private var isSeeking = false

        init(source: String, asset: AVAsset, time: Float, frame: Double) {
            self.source = source
            player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
            player.actionAtItemEnd = .pause
            sourceTime = time
            self.frame = frame
            seek(to: time)
        }

        func seek(to time: Float) {
            guard !isSeeking else { return }
            isSeeking = true
            player.seek(to: CMTime(seconds: Double(time), preferredTimescale: 60_000),
                        toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                DispatchQueue.main.async { [weak self] in self?.isSeeking = false }
            }
        }
    }

    private let engine: LittleAEngine
    private let fps: Double
    private let events: [LittleAAudioEvent]
    private let videoDirectory: URL
    private var audioData: [String: Data] = [:]
    private var cuePlayers: [Int: AVAudioPlayer] = [:]
    private var plainSoundVoices: [PlainSoundVoice] = []
    private let soundEngine = AVAudioEngine()
    private var soundBuffers: [String: NativeSoundBuffer] = [:]
    private var decodedSoundBytes = 0
    private var soundVoices: [NativeSoundVoice] = []
    private var videoAssets: [String: VideoAsset] = [:]
    private var videoVoices: [UInt32: VideoVoice] = [:]
    private var nextCue = 0
    private var lastFrame: Double?
    private var isPaused = true
    private var audioSessionActive = false
    private var audioSessionActivationPending = false
    private var audioPlayersPreparing: Set<ObjectIdentifier> = []

    init(engine: LittleAEngine, fps: Double) throws {
        guard fps.isFinite, fps > 0 else {
            throw MediaError(message: "The scene has an invalid media frame rate.")
        }
        self.engine = engine
        self.fps = fps
        events = try engine.audioEvents()
        guard events.count <= 1024 else {
            throw MediaError(message: "The scene exceeds the 1024-cue media limit.")
        }
        var starts: [UInt32: Int] = [:]
        for event in events {
            starts[event.frame, default: 0] += 1
            guard starts[event.frame, default: 0] <= 64 else {
                throw MediaError(message: "The scene exceeds the 64-voice media limit.")
            }
        }
        videoDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LittleA-media-\(UUID().uuidString)", isDirectory: true)
    }

    deinit {
        for player in cuePlayers.values { player.stop() }
        for voice in plainSoundVoices { voice.player.stop() }
        for voice in soundVoices { voice.stop() }
        soundEngine.stop()
        for voice in videoVoices.values { voice.player.pause() }
        for video in videoAssets.values { video.generator.cancelAllCGImageGeneration() }
        videoVoices.removeAll()
        videoAssets.removeAll()
        if FileManager.default.fileExists(atPath: videoDirectory.path) {
            do {
                try FileManager.default.removeItem(at: videoDirectory)
            } catch {
                NSLog("LittleA media cleanup failed at %@: %@", videoDirectory.path,
                      error.localizedDescription)
            }
        }
    }

    func update(frame: Float) throws {
        guard frame.isFinite, frame >= 0 else {
            throw MediaError(message: "The scene has an invalid media playhead.")
        }
        let frame = Double(frame)
        if let previous = lastFrame, frame < previous {
            for player in cuePlayers.values { player.stop() }
            cuePlayers.removeAll()
            nextCue = 0
        }
        lastFrame = frame

        while nextCue < events.count, Double(events[nextCue].frame) <= frame {
            let event = events[nextCue]
            let player = try makeSound(clip: event.clip, gain: event.gain,
                                       looping: event.isLooping)
            let elapsed = (frame - Double(event.frame)) / fps
            if event.isLooping || elapsed < player.duration {
                player.currentTime = event.isLooping
                    ? elapsed.truncatingRemainder(dividingBy: player.duration) : elapsed
                cuePlayers[nextCue] = player
            }
            nextCue += 1
        }
        for index in Array(cuePlayers.keys).sorted() {
            guard let player = cuePlayers[index] else { continue }
            let event = events[index]
            let elapsed = (frame - Double(event.frame)) / fps
            if !event.isLooping && elapsed >= player.duration {
                player.stop()
                cuePlayers.removeValue(forKey: index)
                continue
            }
            let target = event.isLooping
                ? elapsed.truncatingRemainder(dividingBy: player.duration) : elapsed
            var drift = abs(player.currentTime - target)
            if event.isLooping { drift = min(drift, abs(player.duration - drift)) }
            if isPaused || drift > 0.1 { player.currentTime = target }
            if !isPaused && !player.isPlaying { try play(player) }
        }

        if !isPaused {
            plainSoundVoices.removeAll {
                !$0.player.isPlaying && !audioPlayersPreparing.contains(ObjectIdentifier($0.player))
            }
        }
        soundVoices.removeAll { $0.isFinished }
        try drainSoundRequests()
        for voice in videoVoices.values { try checkVideoPlayer(voice.player, source: voice.source) }
    }

    func pause() {
        if !isPaused { plainSoundVoices.removeAll { !$0.player.isPlaying } }
        soundVoices.removeAll { $0.isFinished }
        isPaused = true
        audioSessionActive = false
        for player in cuePlayers.values { player.pause() }
        for voice in plainSoundVoices { voice.player.pause() }
        for voice in soundVoices { voice.pause() }
        soundEngine.pause()
        for voice in videoVoices.values { voice.player.pause() }
    }

    func resume() throws {
        guard isPaused else { return }
        do {
            if !cuePlayers.isEmpty || !plainSoundVoices.isEmpty || !soundVoices.isEmpty || !videoVoices.isEmpty {
                try activateAudioSession()
            }
            isPaused = false
            for index in cuePlayers.keys.sorted() {
                if let player = cuePlayers[index] { try play(player) }
            }
            for voice in plainSoundVoices { try play(voice.player) }
            for voice in soundVoices { try play(voice) }
            for voice in videoVoices.values {
                try checkVideoPlayer(voice.player, source: voice.source)
                if voice.isAdvancing { voice.player.rate = voice.rate }
            }
        } catch {
            pause()
            throw error
        }
    }

    func prepareVideoFrames(width: UInt32, height: UInt32) throws {
        let requests = try engine.prepareVideoFrames(width: width, height: height, fit: .contain)
        var audible = Set<UInt32>()
        do {
            for request in requests {
                guard request.sourceTime.isFinite, request.sourceTime >= 0 else {
                    throw MediaError(message: "Video '\(request.source)' has an invalid source time.")
                }
                let video = try videoAsset(source: request.source)
                let duration = video.asset.duration.seconds
                let seconds = duration.isFinite && duration > 0
                    ? min(Double(request.sourceTime), max(0, duration - 1 / 60_000.0))
                    : Double(request.sourceTime)
                let time = CMTime(seconds: seconds, preferredTimescale: 60_000)
                video.generator.maximumSize = CGSize(width: CGFloat(request.width),
                                                     height: CGFloat(request.height))
                let image: CGImage
                do {
                    image = try video.generator.copyCGImage(at: time, actualTime: nil)
                } catch {
                    throw MediaError(message: "Cannot decode video '\(request.source)': \(error.localizedDescription)")
                }
                let rgba = try Self.rgba(image, width: request.width, height: request.height)
                guard engine.supplyVideoFrame(request, rgba: rgba) else {
                    throw MediaError(message: "The engine refused a frame from '\(request.source)'.")
                }
                if !request.isMuted {
                    audible.insert(request.index)
                    try synchronizeVideoAudio(request, video: video)
                }
            }
            for index in Array(videoVoices.keys) where !audible.contains(index) {
                videoVoices.removeValue(forKey: index)?.player.pause()
            }
        } catch {
            for voice in videoVoices.values { voice.player.pause() }
            throw error
        }
    }

    private func makeSound(clip: String, gain: Float, looping: Bool) throws -> AVAudioPlayer {
        guard cuePlayers.count + plainSoundVoices.count + soundVoices.count + videoVoices.count < 64 else {
            throw MediaError(message: "The scene exceeds the 64-voice media limit.")
        }
        guard let source = try engine.soundSource(id: clip) else {
            throw MediaError(message: "Sound '\(clip)' has no declared source.")
        }
        guard gain.isFinite else {
            throw MediaError(message: "Sound '\(clip)' has an invalid gain.")
        }
        let data: Data
        if let cached = audioData[source] {
            data = cached
        } else {
            data = try assetData(source)
            audioData[source] = data
        }
        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(data: data)
        } catch {
            throw MediaError(message: "Cannot decode sound '\(clip)' (\(source)): \(error.localizedDescription)")
        }
        guard player.duration.isFinite, player.duration > 0 else {
            throw MediaError(message: "Cannot decode sound '\(clip)' for playback.")
        }
        player.volume = min(1, max(0, gain))
        player.numberOfLoops = looping ? -1 : 0
        return player
    }

    private func play(_ player: AVAudioPlayer) throws {
        if !audioSessionActive {
            try activateAudioSession()
            return
        }

        let identifier = ObjectIdentifier(player)
        guard audioPlayersPreparing.insert(identifier).inserted else { return }

        let playerReference = AudioPlayerReference(player)
        let mediaReference = WeakReference(self)
        DispatchQueue.global(qos: .userInitiated).async {
            let prepared = playerReference.player.prepareToPlay()
            DispatchQueue.main.async {
                guard let self = mediaReference.value else { return }
                self.audioPlayersPreparing.remove(identifier)
                guard prepared, !self.isPaused else {
                    if !prepared {
                        NSLog("LittleA native audio playback could not be prepared.")
                    }
                    return
                }
                guard playerReference.player.play() else {
                    NSLog("LittleA native audio playback could not start.")
                    return
                }
            }
        }
    }

    private func activateAudioSession() throws {
        guard !audioSessionActive, !audioSessionActivationPending else { return }
        let session = AVAudioSession.sharedInstance()
        audioSessionActivationPending = true

        let reference = WeakReference(self)
        let completion: @Sendable (Bool, (any Error)?) -> Void = { success, error in
            DispatchQueue.main.async {
                guard let self = reference.value else { return }
                self.audioSessionActivationPending = false
                self.audioSessionActive = success
                guard success else {
                    NSLog("LittleA audio session activation failed: %@",
                          error?.localizedDescription ?? "Unknown error")
                    return
                }
                self.resumeAudioAfterSessionActivation()
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                if #available(iOS 27.0, *) {
                    session.activate(completionHandler: completion)
                } else {
                    try session.setActive(true)
                    completion(true, nil)
                }
            } catch {
                completion(false, error)
            }
        }
    }

    private func resumeAudioAfterSessionActivation() {
        guard !isPaused else { return }
        do {
            for index in cuePlayers.keys.sorted() {
                if let player = cuePlayers[index], !player.isPlaying { try play(player) }
            }
            for voice in plainSoundVoices where !voice.player.isPlaying { try play(voice.player) }
            for voice in soundVoices { try play(voice) }
            for voice in videoVoices.values where voice.isAdvancing {
                voice.player.rate = voice.rate
            }
        } catch {
            NSLog("LittleA audio playback could not resume: %@", error.localizedDescription)
        }
    }

    private func play(_ voice: NativeSoundVoice) throws {
        if !audioSessionActive {
            try activateAudioSession()
            return
        }
        if !soundEngine.isRunning { try soundEngine.start() }
        voice.play()
    }

    private func soundBuffer(clip: String) throws -> NativeSoundBuffer {
        guard let source = try engine.soundSource(id: clip) else {
            throw MediaError(message: "Sound '\(clip)' has no declared source.")
        }
        if let cached = soundBuffers[source] { return cached }
        let data = try assetData(source)
        try FileManager.default.createDirectory(at: videoDirectory, withIntermediateDirectories: true)
        let url = videoDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: url, options: .atomic)
        let buffer = try NativeSoundVoice.decode(url, remainingBytes: 64 * 1024 * 1024 - decodedSoundBytes)
        soundBuffers[source] = buffer
        decodedSoundBytes += buffer.byteCount
        return buffer
    }

    private func drainSoundRequests() throws {
        let handle = engine.rawHandle
        let count = littlea_drain_sound_requests(handle)
        guard count <= 1024 else {
            throw MediaError(message: "The scene exceeds the 1024 sound-request batch limit.")
        }
        for index in 0..<count {
            let kind = littlea_sound_request_kind(handle, index)
            let length = littlea_sound_request_sound(handle, index, nil, 0)
            guard (0...3).contains(kind), (0...1024).contains(length) else {
                throw MediaError(message: "Cannot read a native sound request.")
            }
            var bytes = [UInt8](repeating: 0, count: length)
            let written = bytes.withUnsafeMutableBufferPointer {
                littlea_sound_request_sound(handle, index, $0.baseAddress, $0.count)
            }
            guard written == length, let clip = String(bytes: bytes, encoding: .utf8) else {
                throw MediaError(message: "A native sound request has invalid text.")
            }
            if kind == 0 {
                for cue in Array(cuePlayers.keys) where clip.isEmpty || events[cue].clip == clip {
                    cuePlayers.removeValue(forKey: cue)?.stop()
                }
                plainSoundVoices.removeAll { voice in
                    guard clip.isEmpty || voice.clip == clip else { return false }
                    voice.player.stop()
                    return true
                }
                soundVoices.removeAll { voice in
                    guard clip.isEmpty || voice.clip == clip else { return false }
                    voice.stop()
                    return true
                }
                continue
            }
            guard !clip.isEmpty, try engine.soundSource(id: clip) != nil else {
                throw MediaError(message: "Sound '\(clip)' has no declared source.")
            }
            let controls = try NativeSoundControls(
                gain: littlea_sound_request_gain(handle, index),
                pitch: kind >= 2 ? littlea_sound_request_parameter(handle, index, 0) : 1,
                pan: kind >= 2 ? littlea_sound_request_parameter(handle, index, 1) : 0,
                fade: kind >= 2 ? littlea_sound_request_parameter(handle, index, 2) : 0)
            if kind == 3 {
                for voice in soundVoices where voice.clip == clip { voice.update(controls) }
                for index in plainSoundVoices.indices.reversed() where plainSoundVoices[index].clip == clip {
                    let previous = plainSoundVoices[index].player
                    let voice = try NativeSoundVoice(engine: soundEngine, clip: clip,
                        buffer: soundBuffer(clip: clip), looping: previous.numberOfLoops != 0,
                        controls: NativeSoundControls(gain: previous.volume), offset: previous.currentTime)
                    voice.update(controls)
                    previous.stop()
                    plainSoundVoices.remove(at: index)
                    soundVoices.append(voice)
                    if !isPaused { try play(voice) }
                }
                continue
            }
            let loops = littlea_sound_request_loops(handle, index)
            guard loops == 0 || loops == 1 else {
                throw MediaError(message: "A native sound request has an invalid loop setting.")
            }
            if kind == 1 {
                let player = try makeSound(clip: clip, gain: controls.gain, looping: loops == 1)
                if !isPaused { try play(player) }
                plainSoundVoices.append(PlainSoundVoice(clip: clip, player: player))
                continue
            }
            guard cuePlayers.count + plainSoundVoices.count + soundVoices.count + videoVoices.count < 64 else {
                throw MediaError(message: "The scene exceeds the 64-voice media limit.")
            }
            let voice = try NativeSoundVoice(engine: soundEngine, clip: clip,
                buffer: soundBuffer(clip: clip), looping: loops == 1, controls: controls)
            soundVoices.append(voice)
            if !isPaused { try play(voice) }
        }
    }

    private func assetData(_ source: String) throws -> Data {
        guard let data = try engine.assetData(named: source), !data.isEmpty else {
            throw MediaError(message: "Media asset '\(source)' is missing from the bundle.")
        }
        return data
    }

    private func videoAsset(source: String) throws -> VideoAsset {
        if let cached = videoAssets[source] { return cached }
        let data = try assetData(source)
        try FileManager.default.createDirectory(at: videoDirectory, withIntermediateDirectories: true)
        let sourceExtension = (source as NSString).pathExtension
        let safeExtension = sourceExtension.rangeOfCharacter(from: .alphanumerics.inverted) == nil
            && !sourceExtension.isEmpty && sourceExtension.count <= 10 ? sourceExtension : "mov"
        let url = videoDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(safeExtension)
        try data.write(to: url, options: .atomic)
        let video = VideoAsset(url: url)
        guard video.asset.isPlayable, !video.asset.tracks(withMediaType: .video).isEmpty else {
            throw MediaError(message: "Video '\(source)' is not supported by this device.")
        }
        videoAssets[source] = video
        return video
    }

    private func synchronizeVideoAudio(_ request: LittleAVideoFrameRequest, video: VideoAsset) throws {
        let voice: VideoVoice
        let frame = Double(engine.playhead)
        if let existing = videoVoices[request.index], existing.source == request.source {
            voice = existing
            let now = ProcessInfo.processInfo.systemUptime
            if request.sourceTime != voice.sourceTime {
                let delta = Double(request.sourceTime) - Double(voice.sourceTime)
                if delta > 0, frame > voice.frame {
                    let rate = Float(delta * fps / (frame - voice.frame))
                    guard rate.isFinite, rate > 0 else {
                        throw MediaError(message: "Video '\(request.source)' has an invalid playback rate.")
                    }
                    voice.rate = rate
                }
                voice.lastAdvanceTime = now
                voice.isAdvancing = true
                voice.frame = frame
            }
            voice.isAdvancing = voice.isAdvancing && now - voice.lastAdvanceTime < max(0.1, 2 / fps)
            if !voice.isAdvancing { voice.frame = frame }
            voice.sourceTime = request.sourceTime
        } else {
            videoVoices.removeValue(forKey: request.index)?.player.pause()
            voice = VideoVoice(source: request.source, asset: video.asset,
                               time: request.sourceTime, frame: frame)
            videoVoices[request.index] = voice
        }
        try checkVideoPlayer(voice.player, source: request.source)
        if voice.rate > 2, let item = voice.player.currentItem,
           item.status == .readyToPlay, !item.canPlayFastForward {
            throw MediaError(message: "Unmuted video '\(request.source)' cannot play at \(voice.rate)x on this device.")
        }
        let currentTime = voice.player.currentTime().seconds
        if !currentTime.isFinite || abs(currentTime - Double(request.sourceTime)) > 0.1 {
            voice.seek(to: request.sourceTime)
        }
        let duration = video.asset.duration.seconds
        if duration.isFinite && Double(request.sourceTime) >= duration { voice.isAdvancing = false }
        if isPaused || !voice.isAdvancing {
            voice.player.pause()
        } else {
            if !audioSessionActive { try activateAudioSession() }
            voice.player.rate = voice.rate
        }
    }

    private func checkVideoPlayer(_ player: AVPlayer, source: String) throws {
        if player.status == .failed || player.currentItem?.status == .failed {
            let reason = player.currentItem?.error?.localizedDescription
                ?? player.error?.localizedDescription ?? "unsupported audio or video"
            throw MediaError(message: "Cannot play unmuted video '\(source)': \(reason)")
        }
    }

    private static func rgba(_ image: CGImage, width: UInt32, height: UInt32) throws -> Data {
        let (pixels, pixelOverflow) = Int(width).multipliedReportingOverflow(by: Int(height))
        let (length, byteOverflow) = pixels.multipliedReportingOverflow(by: 4)
        guard width > 0, height > 0, !pixelOverflow, !byteOverflow, length <= 128 * 1024 * 1024 else {
            throw MediaError(message: "The requested native video frame is too large or empty.")
        }
        var data = Data(count: length)
        try data.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) in
            guard let address = buffer.baseAddress,
                  let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: address, width: Int(width), height: Int(height),
                                          bitsPerComponent: 8, bytesPerRow: Int(width) * 4,
                                          space: colorSpace,
                                          bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue
                                              | CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw MediaError(message: "Cannot allocate a native video bitmap.")
            }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            let bytes = buffer.bindMemory(to: UInt8.self)
            for offset in stride(from: 0, to: length, by: 4) {
                let alpha = Int(bytes[offset + 3])
                guard alpha > 0, alpha < 255 else { continue }
                for channel in 0..<3 {
                    bytes[offset + channel] = UInt8(min(255, (Int(bytes[offset + channel]) * 255 + alpha / 2) / alpha))
                }
            }
        }
        return data
    }
}
