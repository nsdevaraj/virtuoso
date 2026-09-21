import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

import LittleAFFI

public enum LittleAError: Error, Equatable {
    case loadFailed
    case sceneLoadFailed(String)
    case loadDiagnostic(String)
    case globalScopeDiagnostic(String)
    case apiFailure(String)
    case invalidUTF8(String)
    case shortRead(api: String, expected: Int, actual: Int)
}

extension LittleAError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "LittleA could not load the bundle."
        case .sceneLoadFailed(let scene):
            return "LittleA could not load scene '\(scene)'."
        case .loadDiagnostic(let message), .globalScopeDiagnostic(let message):
            return message
        case .apiFailure(let api):
            return "\(api) failed."
        case .invalidUTF8(let api):
            return "\(api) returned invalid UTF-8."
        case .shortRead(let api, let expected, let actual):
            return "\(api) returned \(actual) bytes; expected \(expected)."
        }
    }
}

public enum LittleAFit: String, CaseIterable, Sendable {
    case contain
    case cover
    case fill
    case fitWidth = "fit-width"
    case fitHeight = "fit-height"
    case none
    case scaleDown = "scale-down"
}

public enum LittleAAssetKind: Int32, Sendable {
    case image = 0
    case video = 1
    case audio = 2
    case font = 3
}

public enum LittleADataKind: Int32, Sendable {
    case number = 0
    case text = 1
    case boolean = 2
    case color = 3
}

public enum LittleAAudioEventKind: Int32, Sendable {
    case sfx = 0
    case bgm = 1
}

public enum LittleASemanticRole: Int32, Sendable {
    case text = 0
    case button = 1
    case checkbox = 2
    case radio = 3
    case slider = 4
    case stepper = 5
    case textField = 6
    case listBox = 7
    case comboBox = 8
    case tabList = 9
    case image = 10
    case group = 11
}

public enum LittleASemanticState: Sendable, Equatable {
    case none
    case toggle(checked: Bool)
    case range(value: Float, min: Float, max: Float)
    case text
    case choice(selected: Int, count: Int, expanded: Bool)
}

public enum LittleASemanticAction: Sendable, Equatable {
    case focus, activate, increment, decrement
    case setValue(Float)
    case selectIndex(Int32)
}

public struct LittleATextInputState: Sendable {
    public let handle: UInt32
    public let text: String
    public let committedText: String
    public let anchor: Int
    public let focus: Int
    public let isComposing: Bool
    public let isMultiline: Bool
    public let bounds: LittleASemanticNode.Bounds
}

public struct LittleAAsset: Sendable, Equatable {
    public let name: String
    public let kind: LittleAAssetKind
    public let isResolved: Bool
}

public struct LittleADataPath: Sendable, Equatable {
    public let path: String
    public let kind: LittleADataKind
}

public struct LittleAAudioEvent: Sendable, Equatable {
    public let frame: UInt32
    public let gain: Float
    public let isLooping: Bool
    public let kind: LittleAAudioEventKind
    public let clip: String
}

public struct LittleAVideoFrameRequest: Sendable, Equatable {
    public let index: UInt32
    public let source: String
    public let sourceTime: Float
    public let width: UInt32
    public let height: UInt32
    public let isMuted: Bool
}

public struct LittleASemanticNode: Sendable, Equatable {
    #if canImport(CoreGraphics)
    public typealias Bounds = CGRect
    #else
    public typealias Bounds = (x: Float, y: Float, width: Float, height: Float)
    #endif

    public let handle: UInt32
    public let role: LittleASemanticRole
    public let label: String
    public let text: String?
    public let state: LittleASemanticState
    public let bounds: Bounds

    #if !canImport(CoreGraphics)
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.handle == rhs.handle && lhs.role == rhs.role && lhs.label == rhs.label && lhs.text == rhs.text
            && lhs.state == rhs.state && lhs.bounds == rhs.bounds
    }
    #endif
}

public final class LittleADrainedEvent {
    public let name: String

    private let engine: LittleAEngine
    private let index: UInt32

    fileprivate init(engine: LittleAEngine, index: UInt32, name: String) {
        self.engine = engine
        self.index = index
        self.name = name
    }

    public func property(_ key: String) throws -> String? {
        try engine.drainedEventProperty(at: index, key: key)
    }
}

/// An owned C handle to shared global data. Clone aliases; fork isolates.
/// Create, use and release every alias and attached engine on the same thread.
/// ARC releases only the handle; `dispose()` explicitly invalidates shared data.
public final class LittleAGlobalDataScope {
    /// Borrowed pointer. Do not free it separately from this Swift object.
    public let rawHandle: OpaquePointer

    public convenience init() throws {
        try self.init(ownedHandle: littlea_global_scope_new(), api: "littlea_global_scope_new")
    }

    private init(ownedHandle: OpaquePointer?, api: String) throws {
        guard let ownedHandle else {
            throw try Self.failure(api: api)
        }
        self.rawHandle = ownedHandle
    }

    deinit {
        littlea_global_scope_free(rawHandle)
    }

    public var isDisposed: Bool { littlea_global_scope_is_disposed(rawHandle) == 1 }

    public func clone() throws -> LittleAGlobalDataScope {
        try LittleAGlobalDataScope(
            ownedHandle: littlea_global_scope_clone(rawHandle), api: "littlea_global_scope_clone"
        )
    }

    public func fork() throws -> LittleAGlobalDataScope {
        try LittleAGlobalDataScope(
            ownedHandle: littlea_global_scope_fork(rawHandle), api: "littlea_global_scope_fork"
        )
    }

    public func reset() throws {
        try check(littlea_global_scope_reset(rawHandle), api: "littlea_global_scope_reset")
    }

    public func dispose() throws {
        try check(littlea_global_scope_dispose(rawHandle), api: "littlea_global_scope_dispose")
    }

    public func snapshot() throws -> String {
        let api = "littlea_global_scope_snapshot"
        guard let snapshot = try LittleAEngine.readString(api: api, body: { out, count in
            littlea_global_scope_snapshot(rawHandle, out, count)
        }) else {
            throw try Self.failure(api: api)
        }
        return snapshot
    }

    public func restore(_ snapshot: String) throws {
        let result = LittleAEngine.withUTF8(snapshot) { bytes, count in
            littlea_global_scope_restore(rawHandle, bytes, count)
        }
        try check(result, api: "littlea_global_scope_restore")
    }

    /// Read on the same thread as the failed scope operation.
    public static func lastError() throws -> String? {
        try LittleAEngine.readString(api: "littlea_last_global_scope_error") { out, count in
            littlea_last_global_scope_error(out, count)
        }
    }

    private func check(_ result: Int32, api: String) throws {
        guard result == 1 else {
            throw try Self.failure(api: api)
        }
    }

    private static func failure(api: String) throws -> LittleAError {
        if let message = try lastError() {
            return .globalScopeDiagnostic(message)
        }
        return .apiFailure(api)
    }
}

public final class LittleAEngine {
    public static let version: UInt32 = littlea_version()

    /// Read on the same thread as the failed initializer, before another load.
    public static func lastLoadError() throws -> String? {
        try readString(api: "littlea_last_load_error") { out, outLen in
            littlea_last_load_error(out, outLen)
        }
    }

    public let rawHandle: OpaquePointer
    private var cachedDataKinds: [String: LittleADataKind]?

    public convenience init(bundleData: Data) throws {
        let handle = Self.withDataBytes(bundleData) { bytes, count in
            littlea_load(bytes, count)
        }
        try self.init(loadedHandle: handle)
    }

    public convenience init(bundleData: Data, scene: String) throws {
        let handle = Self.withDataBytes(bundleData) { bytes, count in
            Self.withUTF8(scene) { sceneBytes, sceneCount in
                littlea_load_scene(bytes, count, sceneBytes, sceneCount)
            }
        }
        try self.init(loadedHandle: handle, scene: scene)
    }

    public convenience init(bundleData: Data, globalScope: LittleAGlobalDataScope) throws {
        let handle = Self.withDataBytes(bundleData) { bytes, count in
            littlea_load_with_global_scope(bytes, count, globalScope.rawHandle)
        }
        try self.init(loadedHandle: handle)
    }

    public convenience init(
        bundleData: Data, scene: String, globalScope: LittleAGlobalDataScope
    ) throws {
        let handle = Self.withDataBytes(bundleData) { bytes, count in
            Self.withUTF8(scene) { sceneBytes, sceneCount in
                littlea_load_scene_with_global_scope(
                    bytes, count, sceneBytes, sceneCount, globalScope.rawHandle
                )
            }
        }
        try self.init(loadedHandle: handle, scene: scene)
    }

    private init(loadedHandle handle: OpaquePointer?, scene: String? = nil) throws {
        guard let handle else {
            if let message = try Self.lastLoadError() {
                throw LittleAError.loadDiagnostic(
                    scene.map { "Scene '\($0)': \(message)" } ?? message
                )
            }
            if let scene {
                throw LittleAError.sceneLoadFailed(scene)
            }
            throw LittleAError.loadFailed
        }
        self.rawHandle = handle
    }

    deinit {
        littlea_free(rawHandle)
    }

    public var width: UInt32 { littlea_width(rawHandle) }
    public var height: UInt32 { littlea_height(rawHandle) }
    public var renderRGBALength: Int { littlea_render_rgba_required_len(rawHandle) }
    public var playhead: Float { littlea_playhead(rawHandle) }
    public var reducedMotionEnabled: Bool { littlea_reduced_motion(rawHandle) == 1 }
    public var audioSignature: UInt64 { littlea_audio_signature(rawHandle) }

    public func tick(deltaSeconds: Float) {
        littlea_tick(rawHandle, deltaSeconds)
    }

    /// Apply local/shared bindings without ticking. Check `lastError()` for
    /// script failures, as after input or ticks. Returns whether bindings changed.
    @discardableResult
    public func refreshDataBindings() -> Bool {
        littlea_refresh_data_bindings(rawHandle) == 1
    }

    /// Retained script diagnostic; fatal errors freeze ticks and input.
    public func lastError() throws -> String? {
        try readOptionalString(api: "littlea_last_error") { out, outLen in
            littlea_last_error(rawHandle, out, outLen)
        }
    }

    public func scriptError() throws -> String? {
        try lastError()
    }

    public func play() {
        littlea_play(rawHandle)
    }

    public func stop() {
        littlea_stop(rawHandle)
    }

    public func pause() {
        littlea_pause(rawHandle)
    }

    public func seek(frame: Float) {
        littlea_seek(rawHandle, frame)
    }

    public func setReducedMotion(_ reduced: Bool) -> Bool {
        littlea_set_reduced_motion(rawHandle, reduced ? 1 : 0) == 1
    }

    public func sceneName(at index: UInt32) throws -> String? {
        try readOptionalString(api: "littlea_scene_name") { out, outLen in
            littlea_scene_name(rawHandle, index, out, outLen)
        }
    }

    public func sceneNames() throws -> [String] {
        try (0..<littlea_scene_count(rawHandle)).map { index in
            guard let name = try sceneName(at: index) else {
                throw LittleAError.apiFailure("littlea_scene_name(\(index))")
            }
            return name
        }
    }

    public func asset(at index: UInt32) throws -> LittleAAsset? {
        guard
            let name = try readOptionalString(api: "littlea_asset_name", body: { out, outLen in
                littlea_asset_name(rawHandle, index, out, outLen)
            }),
            let kind = LittleAAssetKind(rawValue: littlea_asset_kind(rawHandle, index))
        else {
            return nil
        }
        let resolved = littlea_asset_is_resolved(rawHandle, index)
        return LittleAAsset(name: name, kind: kind, isResolved: resolved == 1)
    }

    public func assets() throws -> [LittleAAsset] {
        try (0..<littlea_asset_count(rawHandle)).map { index in
            guard let asset = try asset(at: index) else {
                throw LittleAError.apiFailure("asset enumeration failed at index \(index)")
            }
            return asset
        }
    }

    /// Original encoded bundle bytes by path, not a scene sound id. The returned
    /// copy outlives this engine. Missing/non-embedded assets return nil.
    public func assetData(named name: String) throws -> Data? {
        try Self.withUTF8(name) { nameBytes, nameCount in
            let length = littlea_asset_data(rawHandle, nameBytes, nameCount, nil, 0)
            guard length >= 0 else { return nil }
            var data = Data(count: length)
            let written = data.withUnsafeMutableBytes { buffer in
                littlea_asset_data(
                    rawHandle, nameBytes, nameCount,
                    buffer.bindMemory(to: UInt8.self).baseAddress, buffer.count
                )
            }
            guard written == length else {
                throw LittleAError.shortRead(
                    api: "littlea_asset_data", expected: length, actual: written
                )
            }
            return data
        }
    }

    /// Resolve an audio cue or sound-request id to its declared asset path.
    public func soundSource(id: String) throws -> String? {
        try Self.withUTF8(id) { bytes, count in
            try readOptionalString(api: "littlea_sound_source") { out, outLen in
                littlea_sound_source(rawHandle, bytes, count, out, outLen)
            }
        }
    }

    public func supplyImage(named name: String, data: Data) -> Bool {
        Self.withUTF8(name) { nameBytes, nameCount in
            Self.withDataBytes(data) { encodedBytes, encodedCount in
                littlea_supply_image(rawHandle, nameBytes, nameCount, encodedBytes, encodedCount) == 1
            }
        }
    }

    public func prepareVideoFrames(
        width: UInt32,
        height: UInt32,
        fit: LittleAFit = .contain,
        alignX: Float = 0,
        alignY: Float = 0
    ) throws -> [LittleAVideoFrameRequest] {
        let count = Self.withUTF8(fit.rawValue) { fitBytes, fitCount in
            littlea_prepare_video_frames(
                rawHandle, width, height, fitBytes, fitCount, alignX, alignY
            )
        }
        guard count >= 0 else {
            throw LittleAError.apiFailure("littlea_prepare_video_frames")
        }
        return try (0..<UInt32(count)).map { index in
            guard let source = try readOptionalString(
                api: "littlea_video_frame_source",
                body: { out, outLen in
                    littlea_video_frame_source(rawHandle, index, out, outLen)
                }
            ) else {
                throw LittleAError.apiFailure("littlea_video_frame_source(\(index))")
            }
            return LittleAVideoFrameRequest(
                index: index,
                source: source,
                sourceTime: littlea_video_frame_time(rawHandle, index),
                width: littlea_video_frame_width(rawHandle, index),
                height: littlea_video_frame_height(rawHandle, index),
                isMuted: littlea_video_frame_muted(rawHandle, index) == 1
            )
        }
    }

    public func supplyVideoFrame(_ request: LittleAVideoFrameRequest, rgba: Data) -> Bool {
        Self.withDataBytes(rgba) { bytes, count in
            littlea_supply_video_frame(rawHandle, request.index, bytes, count) == 1
        }
    }

    public func clearVideoFrames() {
        littlea_clear_video_frames(rawHandle)
    }

    @available(*, deprecated, renamed: "supplyImage(named:data:)")
    public func supplyImage(named name: String, pngData: Data) -> Bool {
        supplyImage(named: name, data: pngData)
    }

    public func warnings() throws -> [String] {
        try (0..<littlea_warning_count(rawHandle)).map { index in
            guard let warning = try readOptionalString(api: "littlea_warning", body: { out, outLen in
                littlea_warning(rawHandle, index, out, outLen)
            }) else {
                throw LittleAError.apiFailure("littlea_warning(\(index))")
            }
            return warning
        }
    }

    public func renderRGBA() -> Data? {
        let len = renderRGBALength
        guard len > 0 else {
            return nil
        }
        var data = Data(count: len)
        let ok = data.withUnsafeMutableBytes { rawBuffer in
            littlea_render_rgba(rawHandle, rawBuffer.bindMemory(to: UInt8.self).baseAddress, rawBuffer.count)
        }
        return ok == 1 ? data : nil
    }

    public func renderRGBA(into buffer: UnsafeMutableRawBufferPointer) -> Bool {
        littlea_render_rgba(rawHandle, buffer.bindMemory(to: UInt8.self).baseAddress, buffer.count) == 1
    }

    public func renderRGBA(
        width: UInt32,
        height: UInt32,
        fit: LittleAFit,
        alignX: Float = 0,
        alignY: Float = 0
    ) -> Data? {
        let len = Int(width) * Int(height) * 4
        guard len > 0 else {
            return nil
        }
        var data = Data(count: len)
        let ok = data.withUnsafeMutableBytes { rawBuffer in
            Self.withUTF8(fit.rawValue) { fitBytes, fitCount in
                littlea_render_rgba_fit(
                    rawHandle,
                    rawBuffer.bindMemory(to: UInt8.self).baseAddress,
                    rawBuffer.count,
                    width,
                    height,
                    fitBytes,
                    fitCount,
                    alignX,
                    alignY
                )
            }
        }
        return ok == 1 ? data : nil
    }

    public func pointerDown(x: Float, y: Float) {
        littlea_pointer_down(rawHandle, x, y)
    }

    public func pointerMove(x: Float, y: Float) -> Bool {
        littlea_pointer_move(rawHandle, x, y) == 1
    }

    public func pointerDrag(x: Float, y: Float) -> Bool {
        littlea_pointer_drag(rawHandle, x, y) == 1
    }

    public func pointerUp() {
        littlea_pointer_up(rawHandle)
    }

    public func pointerCancel() {
        littlea_pointer_cancel(rawHandle)
    }

    /// Browser-style key name, e.g. "ArrowUp", "w", or " ". Does not insert text.
    @discardableResult
    public func keyDown(_ key: String) -> Bool {
        Self.withUTF8(key) { bytes, count in
            littlea_key_down(rawHandle, bytes, count) == 1
        }
    }

    @discardableResult
    public func keyUp(_ key: String) -> Bool {
        Self.withUTF8(key) { bytes, count in
            littlea_key_up(rawHandle, bytes, count) == 1
        }
    }

    public func scrollBy(id: String, delta: Float) -> Bool {
        Self.withUTF8(id) { bytes, count in
            littlea_scroll_by(rawHandle, bytes, count, delta) == 1
        }
    }

    public func fling(id: String, velocity: Float) -> Bool {
        Self.withUTF8(id) { bytes, count in
            littlea_fling(rawHandle, bytes, count, velocity) == 1
        }
    }

    public func widgetValue(id: String) -> Float {
        Self.withUTF8(id) { bytes, count in
            littlea_widget_value(rawHandle, bytes, count)
        }
    }

    public func widgetSelected(id: String) -> Bool? {
        let value = Self.withUTF8(id) { bytes, count in
            littlea_widget_selected(rawHandle, bytes, count)
        }
        guard value >= 0 else {
            return nil
        }
        return value == 1
    }

    public func widgetText(id: String) throws -> String? {
        try Self.withUTF8(id) { bytes, count in
            try readOptionalString(api: "littlea_widget_text") { out, outLen in
                littlea_widget_text(rawHandle, bytes, count, out, outLen)
            }
        }
    }

    public func typeText(_ text: String) -> Bool {
        Self.withUTF8(text) { bytes, count in
            littlea_type_text(rawHandle, bytes, count) == 1
        }
    }

    public func backspace() -> Bool {
        littlea_backspace(rawHandle) == 1
    }

    public func newline() -> Bool {
        littlea_newline(rawHandle) == 1
    }

    public func textInputState() throws -> LittleATextInputState? {
        var info = LittleATextInputInfo()
        let status = littlea_text_input_info(rawHandle, &info)
        if status == 0 { return nil }
        guard status == 1,
              let text = try readOptionalString(api: "littlea_text_input_text", body: {
                  littlea_text_input_text(rawHandle, 1, $0, $1)
              }),
              let committed = try readOptionalString(api: "littlea_text_input_text", body: {
                  littlea_text_input_text(rawHandle, 0, $0, $1)
              }) else {
            throw LittleAError.apiFailure("littlea_text_input_info/text")
        }
        #if canImport(CoreGraphics)
        let bounds = CGRect(x: CGFloat(info.x), y: CGFloat(info.y),
                            width: CGFloat(info.width), height: CGFloat(info.height))
        #else
        let bounds = (x: info.x, y: info.y, width: info.width, height: info.height)
        #endif
        return LittleATextInputState(handle: info.handle, text: text, committedText: committed,
            anchor: info.anchor, focus: info.focus, isComposing: info.composing != 0,
            isMultiline: info.multiline != 0, bounds: bounds)
    }

    @discardableResult
    public func focusText(id: String?) throws -> Bool {
        try Self.withUTF8(id ?? "") {
            try checkTextStatus(littlea_focus_text(rawHandle, $0, $1), api: "littlea_focus_text")
        }
    }

    public func setTextSelection(anchor: Int, focus: Int) throws {
        guard anchor >= 0, focus >= 0 else {
            throw LittleAError.apiFailure("Text selection offsets must be nonnegative UTF-8 boundaries")
        }
        _ = try checkTextStatus(littlea_set_text_selection(rawHandle, anchor, focus),
                               api: "littlea_set_text_selection")
    }

    @discardableResult
    public func replaceText(_ text: String, anchor: Int, focus: Int) throws -> Bool {
        guard anchor >= 0, focus >= 0 else {
            throw LittleAError.apiFailure("Text selection offsets must be nonnegative UTF-8 boundaries")
        }
        return try Self.withUTF8(text) {
            try checkTextStatus(littlea_replace_text(rawHandle, $0, $1, anchor, focus),
                                api: "littlea_replace_text")
        }
    }

    public func startComposition() throws {
        _ = try composition(phase: 0, text: "")
    }

    public func updateComposition(_ text: String) throws {
        _ = try composition(phase: 1, text: text)
    }

    @discardableResult
    public func commitComposition(_ text: String) throws -> Bool {
        try composition(phase: 2, text: text)
    }

    @discardableResult
    public func cancelComposition() throws -> Bool {
        try composition(phase: 3, text: "")
    }

    private func composition(phase: UInt32, text: String) throws -> Bool {
        try Self.withUTF8(text) {
            try checkTextStatus(littlea_composition(rawHandle, phase, $0, $1),
                                api: "littlea_composition")
        }
    }

    private func checkTextStatus(_ status: Int32, api: String) throws -> Bool {
        guard status >= 0 else {
            let reason: String
            switch status {
            case -2: reason = "no focused text field"
            case -3: reason = "not a text field"
            case -4: reason = "selection is not on a UTF-8 grapheme boundary"
            case -5: reason = "invalid text or control character"
            case -6: reason = "composition is active"
            case -7: reason = "no active composition"
            default: reason = "invalid argument"
            }
            throw LittleAError.apiFailure("\(api): \(reason)")
        }
        return status == 1
    }

    public func setBool(name: String, value: Bool) -> Bool {
        Self.withUTF8(name) { bytes, count in
            littlea_set_bool(rawHandle, bytes, count, value ? 1 : 0) == 1
        }
    }

    public func setNumber(name: String, value: Float) -> Bool {
        Self.withUTF8(name) { bytes, count in
            littlea_set_number(rawHandle, bytes, count, value) == 1
        }
    }

    public func fireTrigger(name: String) -> Bool {
        Self.withUTF8(name) { bytes, count in
            littlea_fire_trigger(rawHandle, bytes, count) == 1
        }
    }

    public func boolInput(name: String) -> Bool? {
        let value = Self.withUTF8(name) { bytes, count in
            littlea_bool_input(rawHandle, bytes, count)
        }
        guard value >= 0 else {
            return nil
        }
        return value == 1
    }

    public func numberInput(name: String) -> Float? {
        let value = Self.withUTF8(name) { bytes, count in
            littlea_number_input(rawHandle, bytes, count)
        }
        return value.isNaN ? nil : value
    }

    public func drainEvents() throws -> [LittleADrainedEvent] {
        let count = littlea_drain_events(rawHandle)
        return try (0..<count).map { index in
            guard let name = try readOptionalString(api: "littlea_event_name", body: { out, outLen in
                littlea_event_name(rawHandle, index, out, outLen)
            }) else {
                throw LittleAError.apiFailure("littlea_event_name(\(index))")
            }
            return LittleADrainedEvent(engine: self, index: index, name: name)
        }
    }

    public func drainedEventProperty(at index: UInt32, key: String) throws -> String? {
        try Self.withUTF8(key) { bytes, count in
            try readOptionalString(api: "littlea_event_property") { out, outLen in
                littlea_event_property(rawHandle, index, bytes, count, out, outLen)
            }
        }
    }

    public func setDataNumber(path: String, value: Float) -> Bool {
        Self.withUTF8(path) { bytes, count in
            littlea_set_data_number(rawHandle, bytes, count, value) == 1
        }
    }

    public func setDataText(path: String, value: String) -> Bool {
        Self.withUTF8(path) { pathBytes, pathCount in
            Self.withUTF8(value) { valueBytes, valueCount in
                littlea_set_data_text(rawHandle, pathBytes, pathCount, valueBytes, valueCount) == 1
            }
        }
    }

    public func setDataBoolean(path: String, value: Bool) -> Bool {
        Self.withUTF8(path) { bytes, count in
            littlea_set_data_boolean(rawHandle, bytes, count, value ? 1 : 0) == 1
        }
    }

    public func setDataColor(path: String, rgba: UInt32) -> Bool {
        Self.withUTF8(path) { bytes, count in
            littlea_set_data_color(rawHandle, bytes, count, rgba) == 1
        }
    }

    public func setDataEnum(path: String, value: String) -> Bool {
        Self.withUTF8(path) { pathBytes, pathCount in
            Self.withUTF8(value) { valueBytes, valueCount in
                littlea_set_data_enum(rawHandle, pathBytes, pathCount, valueBytes, valueCount) == 1
            }
        }
    }

    public func dataNumber(path: String) -> Float? {
        let value = Self.withUTF8(path) { bytes, count in
            littlea_data_number(rawHandle, bytes, count)
        }
        return value.isNaN ? nil : value
    }

    public func dataText(path: String) throws -> String? {
        try Self.withUTF8(path) { bytes, count in
            try readOptionalString(api: "littlea_data_text") { out, outLen in
                littlea_data_text(rawHandle, bytes, count, out, outLen)
            }
        }
    }

    public func dataBoolean(path: String) throws -> Bool? {
        guard try dataKind(forPath: path) == .boolean else {
            return nil
        }
        return Self.withUTF8(path) { bytes, count in
            littlea_data_boolean(rawHandle, bytes, count) == 1
        }
    }

    public func dataColor(path: String) throws -> UInt32? {
        guard try dataKind(forPath: path) == .color else {
            return nil
        }
        return Self.withUTF8(path) { bytes, count in
            littlea_data_color(rawHandle, bytes, count)
        }
    }

    public func dataPaths() throws -> [LittleADataPath] {
        let paths = try (0..<littlea_data_path_count(rawHandle)).map { index in
            guard
                let path = try readOptionalString(api: "littlea_data_path_name", body: { out, outLen in
                    littlea_data_path_name(rawHandle, index, out, outLen)
                }),
                let kind = LittleADataKind(rawValue: littlea_data_path_kind(rawHandle, index))
            else {
                throw LittleAError.apiFailure("data path enumeration failed at index \(index)")
            }
            return LittleADataPath(path: path, kind: kind)
        }
        cachedDataKinds = Dictionary(uniqueKeysWithValues: paths.map { ($0.path, $0.kind) })
        return paths
    }

    public func dataKind(forPath path: String) throws -> LittleADataKind? {
        if let cached = cachedDataKinds?[path] {
            return cached
        }
        _ = try dataPaths()
        return cachedDataKinds?[path]
    }

    public func dataEnumValues(path: String) throws -> [String] {
        var values: [String] = []
        var index: UInt32 = 0
        while let value = try Self.withUTF8(path, { bytes, count in
            try readOptionalString(api: "littlea_data_enum_value") { out, outLen in
                littlea_data_enum_value(rawHandle, bytes, count, index, out, outLen)
            }
        }) {
            values.append(value)
            index += 1
        }
        return values
    }

    public func audioEvents() throws -> [LittleAAudioEvent] {
        try (0..<littlea_audio_event_count(rawHandle)).map { index in
            guard
                let kind = LittleAAudioEventKind(rawValue: littlea_audio_event_kind(rawHandle, index)),
                let clip = try readOptionalString(api: "littlea_audio_event_clip", body: { out, outLen in
                    littlea_audio_event_clip(rawHandle, index, out, outLen)
                })
            else {
                throw LittleAError.apiFailure("audio event enumeration failed at index \(index)")
            }
            return LittleAAudioEvent(
                frame: littlea_audio_event_frame(rawHandle, index),
                gain: littlea_audio_event_gain(rawHandle, index),
                isLooping: littlea_audio_event_looping(rawHandle, index) == 1,
                kind: kind,
                clip: clip
            )
        }
    }

    public func semanticNodes() throws -> [LittleASemanticNode] {
        let count = littlea_semantics_count(rawHandle)
        return try (0..<count).map { index in
            var handle: UInt32 = 0
            guard
                littlea_semantics_handle(rawHandle, index, &handle) == 1,
                let role = LittleASemanticRole(rawValue: littlea_semantics_role(rawHandle, index)),
                let label = try readOptionalString(api: "littlea_semantics_label", body: { out, outLen in
                    littlea_semantics_label(rawHandle, index, out, outLen)
                })
            else {
                throw LittleAError.apiFailure("semantics enumeration failed at index \(index)")
            }
            let text = try readSemanticText(at: index)
            let state = try readSemanticState(at: index)
            let bounds = try readSemanticBounds(at: index)
            return LittleASemanticNode(handle: handle, role: role, label: label, text: text,
                                       state: state, bounds: bounds)
        }
    }

    public func semanticAction(handle: UInt32, action: LittleASemanticAction) throws {
        let operation: UInt32
        let value: Double
        switch action {
        case .focus: (operation, value) = (UInt32(LITTLEA_ACTION_FOCUS), 0)
        case .activate: (operation, value) = (UInt32(LITTLEA_ACTION_ACTIVATE), 0)
        case .increment: (operation, value) = (UInt32(LITTLEA_ACTION_INCREMENT), 0)
        case .decrement: (operation, value) = (UInt32(LITTLEA_ACTION_DECREMENT), 0)
        case .setValue(let number): (operation, value) = (UInt32(LITTLEA_ACTION_SET_VALUE), Double(number))
        case .selectIndex(let index): (operation, value) = (UInt32(LITTLEA_ACTION_SELECT_INDEX), Double(index))
        }
        let status = littlea_semantic_action(rawHandle, handle, operation, value)
        guard status == 1 else {
            throw LittleAError.apiFailure("littlea_semantic_action(\(handle)): status \(status)")
        }
    }

    private func readSemanticText(at index: UInt32) throws -> String? {
        let len = littlea_semantics_text(rawHandle, index, nil, 0)
        if len == -2 {
            return nil
        }
        return try readOptionalString(api: "littlea_semantics_text") { out, outLen in
            littlea_semantics_text(rawHandle, index, out, outLen)
        }
    }

    private func readSemanticState(at index: UInt32) throws -> LittleASemanticState {
        var values = [Float](repeating: 0, count: 3)
        let kind = values.withUnsafeMutableBufferPointer { buffer in
            littlea_semantics_state(rawHandle, index, buffer.baseAddress, buffer.count)
        }
        switch kind {
        case LITTLEA_STATE_NONE:
            return .none
        case LITTLEA_STATE_TOGGLE:
            return .toggle(checked: values[0] != 0)
        case LITTLEA_STATE_RANGE:
            return .range(value: values[0], min: values[1], max: values[2])
        case LITTLEA_STATE_TEXT:
            return .text
        case LITTLEA_STATE_CHOICE:
            return .choice(selected: Int(values[0]), count: Int(values[1]), expanded: values[2] != 0)
        default:
            throw LittleAError.apiFailure("littlea_semantics_state(\(index)) returned \(kind)")
        }
    }

    private func readSemanticBounds(at index: UInt32) throws -> LittleASemanticNode.Bounds {
        var values = [Float](repeating: 0, count: 4)
        let status = values.withUnsafeMutableBufferPointer { buffer in
            littlea_semantics_bounds(rawHandle, index, buffer.baseAddress, buffer.count)
        }
        guard status == 0 else {
            throw LittleAError.apiFailure("littlea_semantics_bounds(\(index))")
        }
        #if canImport(CoreGraphics)
        return CGRect(
            x: CGFloat(values[0]),
            y: CGFloat(values[1]),
            width: CGFloat(values[2]),
            height: CGFloat(values[3])
        )
        #else
        return (x: values[0], y: values[1], width: values[2], height: values[3])
        #endif
    }

    private func readOptionalString(
        api: String,
        body: (UnsafeMutablePointer<UInt8>?, Int) -> Int32
    ) throws -> String? {
        try Self.readString(api: api, body: body)
    }

    fileprivate static func readString(
        api: String,
        body: (UnsafeMutablePointer<UInt8>?, Int) -> Int32
    ) throws -> String? {
        let len = body(nil, 0)
        guard len >= 0 else {
            return nil
        }
        var buffer = [UInt8](repeating: 0, count: Int(len))
        let written = buffer.withUnsafeMutableBufferPointer { ptr in
            body(ptr.baseAddress, ptr.count)
        }
        guard written == len else {
            throw LittleAError.shortRead(api: api, expected: Int(len), actual: Int(written))
        }
        guard let string = String(bytes: buffer, encoding: .utf8) else {
            throw LittleAError.invalidUTF8(api)
        }
        return string
    }

    fileprivate static func withUTF8<R>(
        _ string: String,
        _ body: (UnsafePointer<UInt8>?, Int) throws -> R
    ) rethrows -> R {
        let bytes = Array(string.utf8)
        return try bytes.withUnsafeBufferPointer { buffer in
            try body(buffer.baseAddress, buffer.count)
        }
    }

    private static func withDataBytes<R>(_ data: Data, _ body: (UnsafePointer<UInt8>?, Int) -> R) -> R {
        data.withUnsafeBytes { rawBuffer in
            body(rawBuffer.bindMemory(to: UInt8.self).baseAddress, rawBuffer.count)
        }
    }
}
