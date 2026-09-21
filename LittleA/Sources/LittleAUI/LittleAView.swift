import UIKit
import AVFoundation
import LittleA

@MainActor
public final class LittleAView: UIView {
    public private(set) var engine: LittleAEngine?
    public private(set) var isPlaying = false
    public private(set) var lastError: Error?
    public var onError: ((Error) -> Void)?
    public var onEvents: (([LittleADrainedEvent]) -> Void)?
    public var onPlaybackChanged: ((Bool) -> Void)?

    private let canvas = NativeSceneView(frame: .zero)
    private var media: NativeMedia?
    private var clock = PlayerClock(fps: 60)
    private var displayLink: CADisplayLink?
    private var heldKeys = Set<String>()
    private var refreshing = false
    private var disposed = false
    private lazy var displayTarget = DisplayTarget(view: self)

    public override var canBecomeFirstResponder: Bool { engine != nil && !disposed }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = .clear
        isAccessibilityElement = false
        canvas.frame = bounds
        canvas.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(canvas)
        canvas.onInteraction = { [weak self] in self?.refreshReportingErrors() }
        canvas.onError = { [weak self] error in self?.report(error) }
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted),
            name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(interrupted),
            name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reducedMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
    }

    deinit {
        displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    public func load(bundleData: Data, framesPerSecond: Double,
                     scene: String? = nil, globalScope: LittleAGlobalDataScope? = nil) throws {
        guard !disposed else { throw LittleAError.apiFailure("The view is disposed") }
        guard !bundleData.isEmpty, bundleData.count <= 64 * 1024 * 1024,
              framesPerSecond.isFinite, (1...240).contains(framesPerSecond) else {
            throw LittleAError.apiFailure("Expected a LAB up to 64 MiB and a frame rate from 1 to 240")
        }
        let previousEngine = engine
        let loaded: LittleAEngine
        switch (scene, globalScope) {
        case let (name?, scope?): loaded = try LittleAEngine(bundleData: bundleData, scene: name, globalScope: scope)
        case let (name?, nil): loaded = try LittleAEngine(bundleData: bundleData, scene: name)
        case let (nil, scope?): loaded = try LittleAEngine(bundleData: bundleData, globalScope: scope)
        case (nil, nil): loaded = try LittleAEngine(bundleData: bundleData)
        }
        guard loaded.width > 0, loaded.height > 0 else {
            throw LittleAError.apiFailure("The scene has no renderable stage")
        }
        if let message = try loaded.scriptError() { throw LittleAError.apiFailure(message) }
        loaded.pause()
        _ = loaded.setReducedMotion(UIAccessibility.isReduceMotionEnabled)
        let preparedMedia = try NativeMedia(engine: loaded, fps: framesPerSecond)
        try preparedMedia.update(frame: loaded.playhead)
        let preparedFrame = try makeFrame(engine: loaded, media: preparedMedia)
        pause()
        guard !disposed else { throw LittleAError.apiFailure("The view was disposed during load") }
        guard engine === previousEngine, !isPlaying else {
            throw LittleAError.apiFailure("The view changed during load")
        }
        canvas.clear()
        engine = loaded
        media = preparedMedia
        clock = PlayerClock(fps: framesPerSecond)
        lastError = nil
        canvas.engine = loaded
        canvas.sceneSize = CGSize(width: Int(loaded.width), height: Int(loaded.height))
        canvas.inputEnabled = window != nil
        if let frame = preparedFrame {
            try canvas.present(frame.bytes, width: frame.width, height: frame.height)
        }
    }

    public func play() throws {
        guard !disposed, let engine else { throw LittleAError.apiFailure("No scene is loaded") }
        guard !isPlaying else { return }
        guard lastError == nil else { throw LittleAError.apiFailure("Reload the scene after a playback failure") }
        try media?.resume()
        engine.play()
        isPlaying = true
        canvas.inputEnabled = window != nil
        clock.reset()
        let link = CADisplayLink(target: displayTarget, selector: #selector(DisplayTarget.step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        onPlaybackChanged?(true)
    }

    public func pause() {
        displayLink?.invalidate()
        displayLink = nil
        cancelInput()
        engine?.pause()
        media?.pause()
        clock.reset()
        let changed = isPlaying
        isPlaying = false
        if changed { onPlaybackChanged?(false) }
    }

    public func cancelInput() {
        for key in heldKeys { engine?.keyUp(key) }
        heldKeys.removeAll()
        canvas.releaseInput()
        resignFirstResponder()
        guard !disposed, lastError == nil, let engine, let media else { return }
        do {
            if let frame = try makeFrame(engine: engine, media: media) {
                try canvas.present(frame.bytes, width: frame.width, height: frame.height)
            }
        } catch { report(error) }
    }

    public func seek(frame: Float) throws {
        guard !disposed, let engine, frame.isFinite, frame >= 0 else {
            throw LittleAError.apiFailure("Expected a loaded scene and a nonnegative finite frame")
        }
        engine.seek(frame: frame)
        clock.reset()
        try refresh()
    }

    public func refresh() throws {
        guard !disposed, let engine, let media else { throw LittleAError.apiFailure("No scene is loaded") }
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        _ = engine.refreshDataBindings()
        if try canvas.prepareInput() { _ = engine.refreshDataBindings() }
        if let message = try engine.scriptError() { throw LittleAError.apiFailure(message) }
        try media.update(frame: engine.playhead)
        if let frame = try makeFrame(engine: engine, media: media) {
            try canvas.present(frame.bytes, width: frame.width, height: frame.height)
        }
        if let onEvents {
            let events = try engine.drainEvents()
            if !events.isEmpty { onEvents(events) }
        }
    }

    public func dispose() {
        guard !disposed else { return }
        disposed = true
        pause()
        canvas.inputEnabled = false
        canvas.clear()
        media = nil
        engine = nil
        NotificationCenter.default.removeObserver(self)
        onEvents = nil
        onPlaybackChanged = nil
        onError = nil
    }

    public func keyDown(_ key: String) {
        guard !disposed, canvas.inputEnabled, heldKeys.insert(key).inserted else { return }
        engine?.keyDown(key)
        refreshReportingErrors()
    }

    public func keyUp(_ key: String) {
        guard heldKeys.remove(key) != nil else { return }
        engine?.keyUp(key)
        refreshReportingErrors()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        canvas.frame = bounds
        refreshReportingErrors()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { pause() }
        canvas.inputEnabled = window != nil && engine != nil && lastError == nil && !disposed
    }

    @objc private func interrupted() {
        pause()
        canvas.inputEnabled = false
    }

    @objc private func reducedMotionChanged() {
        _ = engine?.setReducedMotion(UIAccessibility.isReduceMotionEnabled)
        refreshReportingErrors()
    }

    fileprivate func step(_ link: CADisplayLink) {
        guard isPlaying, let engine else { return }
        for _ in 0..<clock.steps(at: link.timestamp) {
            engine.tick(deltaSeconds: Float(1 / clock.fps))
        }
        refreshReportingErrors()
    }

    private func refreshReportingErrors() {
        guard engine != nil, !disposed, lastError == nil else { return }
        do {
            try refresh()
        } catch {
            report(error)
        }
    }

    private func report(_ error: Error) {
        guard !disposed, lastError == nil else { return }
        lastError = error
        pause()
        canvas.inputEnabled = false
        if let onError { onError(error) } else { NSLog("[LittleA] %@", error.localizedDescription) }
    }

    private func makeFrame(engine: LittleAEngine, media: NativeMedia) throws
        -> (bytes: Data, width: UInt32, height: UInt32)? {
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        guard bounds.width.isFinite, bounds.height.isFinite else {
            throw LittleAError.apiFailure("Invalid view dimensions")
        }
        let scale = min(1, min(4096 / max(bounds.width, bounds.height),
                              sqrt(4_000_000 / bounds.width / bounds.height)))
        let width = UInt32(max(1, floor(bounds.width * scale)))
        let height = UInt32(max(1, floor(bounds.height * scale)))
        try media.prepareVideoFrames(width: width, height: height)
        guard let bytes = engine.renderRGBA(width: width, height: height, fit: .contain) else {
            throw LittleAError.apiFailure("Native rendering failed")
        }
        return (bytes, width, height)
    }

    private func keyName(_ press: UIPress) -> String? {
        guard let key = press.key else { return nil }
        switch key.keyCode {
        case .keyboardLeftArrow: return "ArrowLeft"
        case .keyboardRightArrow: return "ArrowRight"
        case .keyboardUpArrow: return "ArrowUp"
        case .keyboardDownArrow: return "ArrowDown"
        case .keyboardSpacebar: return "Space"
        case .keyboardEscape: return "Escape"
        default: return key.charactersIgnoringModifiers
        }
    }

    public override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if canvas.isEditingText { super.pressesBegan(presses, with: event); return }
        for press in presses { if let key = keyName(press) { keyDown(key) } }
    }

    public override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses { if let key = keyName(press) { keyUp(key) } }
        super.pressesEnded(presses, with: event)
    }

    public override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses { if let key = keyName(press) { keyUp(key) } }
        super.pressesCancelled(presses, with: event)
    }
}

@MainActor
private final class DisplayTarget: NSObject {
    weak var view: LittleAView?

    init(view: LittleAView) { self.view = view }

    @objc func step(_ link: CADisplayLink) { view?.step(link) }
}