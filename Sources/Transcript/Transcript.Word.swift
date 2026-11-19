public import Interval
public import Rational

extension Transcript {
    /// One spoken word: its text as written down, when it was spoken in seconds from the start of the recording, and
    /// how sure the listener was of it, where the listener says.
    public struct Word: Hashable, Sendable {
        /// The word as the listener wrote it.
        public var text: Swift.String
        /// When the word was spoken, in seconds from the start of the recording.
        public var span: Range<Rational>
        /// How sure the listener was of the word, from 0 to 1, or `nil` when it does not say.
        public var confidence: Interval.Unit<Double>?

        /// A word spoken over `span`.
        public init(_ text: Swift.String, over span: Range<Rational>, confidence: Interval.Unit<Double>? = nil) {
            self.text = text
            self.span = span
            self.confidence = confidence
        }
    }
}
