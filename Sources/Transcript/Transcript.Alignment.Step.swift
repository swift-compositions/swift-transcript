extension Transcript.Alignment {
    /// One step of the least-cost path through a script and a transcript.
    struct Step: Hashable, Sendable {
        /// How many words of each it takes.
        var move: Transcript.Alignment.Step.Move
        /// Whether the keys compared by the move are the same.
        var exact: Bool
    }
}
