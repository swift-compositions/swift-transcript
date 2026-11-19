public import Ordinal

extension Transcript.Script {
    /// One word of a script, with where it stands.
    public struct Word: Hashable, Sendable {
        /// The word as the script writes it, punctuation and quotes included.
        public var text: Swift.String
        /// The paragraph it stands in, counted from 0 over the paragraphs that hold a word.
        public var paragraph: Ordinal
        /// The line it stands on, counted from 0 within its paragraph over the lines that hold a word.
        public var line: Ordinal

        /// A word of the script.
        public init(_ text: Swift.String, paragraph: Ordinal, line: Ordinal) {
            self.text = text
            self.paragraph = paragraph
            self.line = line
        }
    }
}

extension Transcript.Script.Word {
    /// What of the word counts when it is compared with a spoken word.
    var key: Swift.String { Transcript.key(of: text) }
}
