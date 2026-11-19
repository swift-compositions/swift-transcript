public import Ordinal

extension Transcript {
    /// A known text that is to be spoken, as words in paragraphs and lines.
    ///
    /// A paragraph ends at a line with nothing but whitespace on it, and a word is a run of characters between
    /// whitespace. A word with no letters or digits, such as a lone dash, is not a word of the script.
    public struct Script: Hashable, Sendable {
        /// The words, in the order of the text.
        public var words: [Transcript.Script.Word]

        /// The script of a text.
        public init(_ text: Swift.String) {
            var words: [Transcript.Script.Word] = []
            var paragraph: UInt = 0
            var line: UInt = 0
            var blank = true
            for row in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let tokens = row.split(whereSeparator: \.isWhitespace)
                    .map { Transcript.Script.Word(Swift.String($0), paragraph: Ordinal(paragraph), line: Ordinal(line)) }
                    .filter { !$0.key.isEmpty }
                if tokens.isEmpty {
                    if row.allSatisfy(\.isWhitespace), !blank {
                        paragraph += 1
                        line = 0
                        blank = true
                    }
                    continue
                }
                words += tokens
                line += 1
                blank = false
            }
            self.words = words
        }
    }
}

extension Transcript.Script {
    /// The paragraphs that hold a word, in order.
    public var paragraphs: [Ordinal] {
        Swift.Set(words.map(\.paragraph)).sorted()
    }
}
