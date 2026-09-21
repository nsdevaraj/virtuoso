import UIKit
import LittleA

@MainActor
final class NativeTextInput: UITextView, UITextViewDelegate {
    private weak var engine: LittleAEngine?
    private(set) var handle: UInt32?
    var onInteraction: (() -> Void)?
    var onError: ((Error) -> Void)?
    private var synchronizing = false
    private var editingDepth = 0
    private var multiline = false
    private var originalSelection: (anchor: Int, focus: Int)?

    init() {
        super.init(frame: .zero, textContainer: nil)
        delegate = self
        isHidden = true
        backgroundColor = .systemBackground
        textColor = .label
        autocorrectionType = .no
        autocapitalizationType = .none
        smartQuotesType = .no
        smartDashesType = .no
    }

    required init?(coder: NSCoder) { fatalError("Use init()") }

    func synchronize(_ state: LittleATextInputState, engine: LittleAEngine,
                     viewport: PlayerViewport, label: String?) throws {
        let sameField = self.engine === engine && handle == state.handle
        if !sameField { dismiss() }
        synchronizing = true
        defer { synchronizing = false }
        self.engine = engine
        handle = state.handle
        multiline = state.isMultiline
        frame = viewport.viewRect(state.bounds)
        font = .systemFont(ofSize: max(1, 14 * viewport.scale))
        textContainerInset = UIEdgeInsets(top: 3 * viewport.scale, left: 4 * viewport.scale,
                                         bottom: 3 * viewport.scale, right: 4 * viewport.scale)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = multiline ? 0 : 1
        accessibilityLabel = label
        isHidden = false

        // Never replace UIKit's marked storage during its own transaction.
        if !sameField || !text.utf8.elementsEqual(state.text.utf8)
            || (!state.isComposing && markedTextRange != nil) {
            super.unmarkText()
            text = state.text
            originalSelection = nil
        }
        if !state.isComposing || markedTextRange == nil {
            let selection = try TextInputSelection(text: state.text, anchor: state.anchor,
                                                   focus: state.focus).range
            if selectedRange != selection { selectedRange = selection }
        }
        if window != nil && !isFirstResponder { becomeFirstResponder() }
    }

    func cancelComposition() throws {
        guard let engine, let state = try engine.textInputState(), state.handle == handle else { return }
        if state.isComposing {
            try engine.cancelComposition()
            if let originalSelection {
                try engine.setTextSelection(anchor: originalSelection.anchor, focus: originalSelection.focus)
            }
        }
        originalSelection = nil
    }

    func commitDisplayedText() {
        publish()
    }

    func dismiss() {
        synchronizing = true
        defer { synchronizing = false }
        engine = nil
        handle = nil
        originalSelection = nil
        super.unmarkText()
        super.resignFirstResponder()
        text = ""
        isHidden = true
    }

    override func resignFirstResponder() -> Bool {
        if synchronizing { return super.resignFirstResponder() }
        do {
            try cancelComposition()
            if let engine, let state = try engine.textInputState(), state.handle == handle {
                try engine.focusText(id: nil)
            }
            dismiss()
            onInteraction?()
        } catch { report(error) }
        return !isFirstResponder
    }

    override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        edit { super.setMarkedText(markedText, selectedRange: selectedRange) }
    }

    override func unmarkText() {
        edit { super.unmarkText() }
    }

    override func insertText(_ text: String) {
        if !multiline && text == "\n" {
            _ = resignFirstResponder()
            return
        }
        edit { super.insertText(text) }
    }

    override func deleteBackward() {
        edit { super.deleteBackward() }
    }

    override func replace(_ range: UITextRange, withText text: String) {
        edit { super.replace(range, withText: text) }
    }

    private func edit(_ operation: () -> Void) {
        if synchronizing { operation(); return }
        guard !isHidden, engine != nil else { return }
        editingDepth += 1
        operation()
        editingDepth -= 1
        if editingDepth == 0 { publish() }
    }

    func textViewDidChange(_ textView: UITextView) { publish() }
    func textViewDidChangeSelection(_ textView: UITextView) { publish() }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange,
                  replacementText text: String) -> Bool {
        if !multiline && text.contains("\n") {
            if text == "\n" { _ = resignFirstResponder() }
            return false
        }
        return true
    }

    private func publish() {
        guard !synchronizing, editingDepth == 0, let engine, let handle else { return }
        synchronizing = true
        do {
            guard let state = try engine.textInputState(), state.handle == handle else {
                synchronizing = false
                dismiss()
                return
            }
            if let marked = markedTextRange {
                let range = NSRange(location: offset(from: beginningOfDocument, to: marked.start),
                                    length: offset(from: marked.start, to: marked.end))
                let composition = try TextInputSelection.composition(
                    committed: state.committedText, displayed: text, marked: range)
                if originalSelection == nil && !state.isComposing {
                    originalSelection = (state.anchor, state.focus)
                }
                if state.isComposing { try engine.cancelComposition() }
                try engine.setTextSelection(anchor: composition.selection.anchor, focus: composition.selection.focus)
                try engine.startComposition()
                try engine.updateComposition(composition.text)
            } else {
                let selection = try TextInputSelection(text: text, range: selectedRange)
                if state.isComposing { try engine.cancelComposition() }
                try engine.replaceText(text, anchor: selection.anchor, focus: selection.focus)
                selectedRange = selection.range
                originalSelection = nil
            }
            synchronizing = false
            onInteraction?()
        } catch {
            synchronizing = false
            report(error)
        }
    }

    private func report(_ error: Error) {
        if let onError { onError(error) } else { NSLog("[LittleA] %@", error.localizedDescription) }
    }
}
