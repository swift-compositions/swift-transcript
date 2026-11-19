extension Transcript.Alignment {
    /// A word of the script and how it was heard, or that it was not.
    public struct Word: Hashable, Sendable {
        /// The word of the script.
        public var script: Transcript.Script.Word
        /// How it was heard, or `nil` when it was not.
        public var heard: Transcript.Alignment.Heard?
        /// The positions in the transcript of the spoken words it was heard as.
        var spoken: [Int]

        init(_ script: Transcript.Script.Word, heard: Transcript.Alignment.Heard?, spoken: [Int]) {
            self.script = script
            self.heard = heard
            self.spoken = spoken
        }
    }
}
