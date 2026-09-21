import Foundation

enum NativeTextInputError: LocalizedError {
    case invalidSelection
    case invalidComposition

    var errorDescription: String? {
        switch self {
        case .invalidSelection: return "The text selection is outside the document or splits a grapheme."
        case .invalidComposition: return "The marked text does not match the native editing transaction."
        }
    }
}

struct TextInputSelection {
    let range: NSRange
    let anchor: Int
    let focus: Int

    init(text: String, range: NSRange) throws {
        let offsets = Self.offsets(text)
        let length = text.utf16.count
        guard range.location >= 0, range.length >= 0,
              range.location <= length, range.length <= length - range.location,
              let start = offsets.last(where: { $0.utf16 <= range.location }),
              let end = offsets.first(where: { $0.utf16 >= range.location + range.length }) else {
            throw NativeTextInputError.invalidSelection
        }
        let finish = range.length == 0 ? start : end
        self.range = NSRange(location: start.utf16, length: finish.utf16 - start.utf16)
        anchor = start.utf8
        focus = finish.utf8
    }

    init(text: String, anchor: Int, focus: Int) throws {
        let offsets = Self.offsets(text)
        guard let start = offsets.first(where: { $0.utf8 == anchor }),
              let end = offsets.first(where: { $0.utf8 == focus }) else {
            throw NativeTextInputError.invalidSelection
        }
        self.anchor = anchor
        self.focus = focus
        range = NSRange(location: min(start.utf16, end.utf16), length: abs(end.utf16 - start.utf16))
    }

    private static func offsets(_ text: String) -> [(utf16: Int, utf8: Int)] {
        var result = [(utf16: 0, utf8: 0)]
        var utf16 = 0
        var utf8 = 0
        for character in text {
            let value = String(character)
            utf16 += value.utf16.count
            utf8 += value.utf8.count
            result.append((utf16, utf8))
        }
        return result
    }

    static func composition(committed: String, displayed: String, marked: NSRange)
        throws -> (selection: TextInputSelection, text: String) {
        guard let markedRange = Range(marked, in: displayed) else {
            throw NativeTextInputError.invalidComposition
        }
        let replacedLength = committed.utf16.count - displayed.utf16.count + marked.length
        guard replacedLength >= 0 else { throw NativeTextInputError.invalidComposition }
        let replaced = NSRange(location: marked.location, length: replacedLength)
        let selection = try TextInputSelection(text: committed, range: replaced)
        guard selection.range == replaced, let originalRange = Range(replaced, in: committed),
              committed[..<originalRange.lowerBound].utf8.elementsEqual(displayed[..<markedRange.lowerBound].utf8),
              committed[originalRange.upperBound...].utf8.elementsEqual(displayed[markedRange.upperBound...].utf8) else {
            throw NativeTextInputError.invalidComposition
        }
        return (selection, String(displayed[markedRange]))
    }
}
