import UIKit
import LittleA

final class NativeSceneView: UIView {
    weak var engine: LittleAEngine?
    var sceneSize = CGSize(width: 1, height: 1)
    var onInteraction: (() -> Void)?
    var onError: ((Error) -> Void)?
    var inputEnabled = false
    private var activeTouch: UITouch?
    private var semanticSnapshot: [LittleASemanticNode] = []
    private var semanticBounds = CGRect.zero
    private var semanticElements: [UInt32: SceneAccessibilityElement] = [:]
    private let textInput = NativeTextInput()
    private var semanticTextHandle: UInt32?

    var viewport: PlayerViewport { PlayerViewport(sceneSize: sceneSize, bounds: bounds) }
    var isEditingText: Bool { textInput.isFirstResponder }

    func prepareInput() throws -> Bool {
        guard textInput.handle != nil, let engine, try engine.textInputState() == nil else { return false }
        try engine.focusText(id: nil)
        textInput.dismiss()
        return true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.contentsGravity = .resize
        backgroundColor = .clear
        isAccessibilityElement = false
        addSubview(textInput)
        textInput.onInteraction = { [weak self] in self?.onInteraction?() }
        textInput.onError = { [weak self] error in self?.report(error) }
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    func present(_ rgba: Data, width: UInt32, height: UInt32) throws {
        guard rgba.count == Int(width) * Int(height) * 4,
              let provider = CGDataProvider(data: rgba as CFData),
              let image = CGImage(width: Int(width), height: Int(height), bitsPerComponent: 8,
                                  bitsPerPixel: 32, bytesPerRow: Int(width) * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue
                                      | CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: true,
                                  intent: .defaultIntent) else {
            throw LittleAError.apiFailure("Cannot create native scene image")
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.contents = image
        CATransaction.commit()
        try updateAccessibility()
    }

    func clear() {
        releaseInput()
        engine = nil
        layer.contents = nil
        semanticSnapshot = []
        semanticBounds = .zero
        semanticElements = [:]
        semanticTextHandle = nil
        accessibilityElements = nil
    }

    func releaseInput() {
        engine?.pointerCancel()
        activeTouch = nil
        do {
            try textInput.cancelComposition()
            try engine?.focusText(id: nil)
        } catch { report(error) }
        textInput.dismiss()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard inputEnabled, activeTouch == nil, let touch = touches.first,
              viewport.contentRect.contains(touch.location(in: self)) else { return }
        activeTouch = touch
        activate(viewport.scenePoint(touch.location(in: self)), release: false)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        let point = viewport.scenePoint(touch.location(in: self))
        _ = engine?.pointerDrag(x: Float(point.x), y: Float(point.y))
        onInteraction?()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        let point = viewport.scenePoint(touch.location(in: self))
        _ = engine?.pointerDrag(x: Float(point.x), y: Float(point.y))
        engine?.pointerUp()
        activeTouch = nil
        onInteraction?()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        releaseInput()
        onInteraction?()
    }

    func activate(_ point: CGPoint, release: Bool = true) {
        guard inputEnabled, let engine else { return }
        textInput.commitDisplayedText()
        engine.pointerDown(x: Float(point.x), y: Float(point.y))
        if release { engine.pointerUp() }
        onInteraction?()
    }

    override func accessibilityPerformEscape() -> Bool {
        guard isEditingText else { return false }
        releaseInput()
        onInteraction?()
        return true
    }

    fileprivate func perform(_ action: LittleASemanticAction, handle: UInt32,
                             engine: LittleAEngine) -> Bool {
        guard inputEnabled, self.engine === engine else { return false }
        do {
            guard try engine.semanticNodes().contains(where: { $0.handle == handle }) else { return false }
            textInput.commitDisplayedText()
            try engine.semanticAction(handle: handle, action: action)
            onInteraction?()
            return true
        } catch {
            report(error)
            return false
        }
    }

    private func report(_ error: Error) {
        if let onError { onError(error) } else { NSLog("[LittleA] %@", error.localizedDescription) }
    }

    private func updateAccessibility() throws {
        guard let engine else { return }
        let nodes = try engine.semanticNodes()
        if inputEnabled, let state = try engine.textInputState() {
            try textInput.synchronize(state, engine: engine, viewport: viewport,
                                      label: nodes.first(where: { $0.handle == state.handle })?.label)
        } else {
            textInput.dismiss()
        }
        guard nodes != semanticSnapshot || bounds != semanticBounds
                || semanticTextHandle != textInput.handle else { return }
        semanticSnapshot = nodes
        semanticBounds = bounds
        semanticTextHandle = textInput.handle
        var current: [UInt32: SceneAccessibilityElement] = [:]
        accessibilityElements = nodes.map { node -> NSObject in
            if node.handle == textInput.handle { return textInput }
            let element = semanticElements[node.handle] ?? SceneAccessibilityElement(accessibilityContainer: self)
            current[node.handle] = element
            element.scene = self
            element.engine = engine
            element.handle = node.handle
            element.role = node.role
            element.accessibilityLabel = node.label
            element.accessibilityValue = node.text
            element.accessibilityFrameInContainerSpace = viewport.viewRect(node.bounds)
            element.accessibilityTraits = []
            switch node.role {
            case .button, .checkbox, .radio, .comboBox:
                element.accessibilityTraits = .button
            case .text: element.accessibilityTraits = .staticText
            case .image: element.accessibilityTraits = .image
            default: break
            }
            switch node.state {
            case .toggle(let checked):
                if checked { element.accessibilityTraits.insert(.selected) }
            case .range(let value, let min, let max):
                element.accessibilityValue = String(value)
                if min < max { element.accessibilityTraits.insert(.adjustable) }
            case .choice(let selected, let count, _):
                element.accessibilityValue = selected < 0
                    ? NSLocalizedString("No selection", comment: "Unselected LittleA choice control")
                    : "\(selected + 1) / \(count)"
                if count > 0 { element.accessibilityTraits.insert(.adjustable) }
            default: break
            }
            return element
        }
        semanticElements = current
    }
}

private final class SceneAccessibilityElement: UIAccessibilityElement {
    weak var scene: NativeSceneView?
    weak var engine: LittleAEngine?
    var handle: UInt32 = 0
    var role: LittleASemanticRole = .group

    override func accessibilityActivate() -> Bool {
        switch role {
        case .button, .checkbox, .radio, .comboBox, .textField:
            return perform(.activate)
        case .slider, .stepper, .listBox, .tabList:
            return perform(.focus)
        default:
            return false
        }
    }

    override func accessibilityIncrement() {
        if accessibilityTraits.contains(.adjustable) { _ = perform(.increment) }
    }

    override func accessibilityDecrement() {
        if accessibilityTraits.contains(.adjustable) { _ = perform(.decrement) }
    }

    private func perform(_ action: LittleASemanticAction) -> Bool {
        guard let scene, let engine else { return false }
        return scene.perform(action, handle: handle, engine: engine)
    }
}