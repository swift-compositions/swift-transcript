public import Ordinal

extension Transcript.Alignment {
    /// A spoken word that matches no word of the script.
    public struct Extra: Hashable, Sendable {
        /// The spoken word.
        public var word: Transcript.Word
        /// The position in `words` of the script word it follows, or `nil` when it comes before the first.
        public var after: Ordinal?
        /// Its position in the transcript.
        var spoken: Int

        init(_ word: Transcript.Word, after: Ordinal?, spoken: Int) {
            self.word = word
            self.after = after
            self.spoken = spoken
        }
    }
}
