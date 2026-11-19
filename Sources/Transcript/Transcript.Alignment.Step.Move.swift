extension Transcript.Alignment.Step {
    /// How many script and spoken words a step takes.
    enum Move: Hashable, Sendable {
        /// One script word heard as one spoken word.
        case both
        /// Two script words heard as one spoken word.
        case joined
        /// One script word heard as two spoken words.
        case split
        /// A script word not heard.
        case missing
        /// A spoken word not in the script.
        case extra
    }
}

extension Transcript.Alignment.Step.Move {
    /// The script words the move takes.
    var script: Int {
        switch self {
        case .both, .split, .missing: 1

        case .joined: 2

        case .extra: 0
        }
    }

    /// The spoken words the move takes.
    var spoken: Int {
        switch self {
        case .both, .joined, .extra: 1

        case .split: 2

        case .missing: 0
        }
    }
}
