public import Rational

extension Transcript.Alignment {
    /// How a script word was heard.
    public struct Heard: Hashable, Sendable {
        /// The spoken words it was heard as: one, or two when it was heard as two words. When two script words
        /// were heard as one spoken word, each holds that word.
        public var words: [Transcript.Word]
        /// When the script word was spoken. Two script words heard as one spoken word share its span, divided in
        /// proportion to the characters of their keys; a script word heard as two runs from the start of the first
        /// to the end of the second.
        public var span: Range<Rational>
        /// Whether the keys are the same; otherwise the word was a slip.
        public var exact: Bool
    }
}
