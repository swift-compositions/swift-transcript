import Ordinal
import Rational

extension Transcript {
    /// A script set against a transcript of it being spoken: for each script word whether it was heard and when, and
    /// each spoken word the script does not hold.
    ///
    /// The alignment is the one of least cost over the whole script, a word at a time. A script word and a spoken
    /// word whose keys are the same cost nothing; a pair more than half alike costs one less their likeness and is
    /// a slip, heard but not exactly. A script word not heard costs 1, and so does a spoken word not in the script.
    /// Two script words heard as one spoken word, or one heard as two, cost 0.8 plus one less the likeness of the
    /// joined keys, and are taken only when the joined keys are more than nine tenths alike. Where two
    /// alignments cost the same, a script word is matched to the later of the spoken words, so a line read twice is
    /// timed by its last reading and the first is extra.
    public struct Alignment: Hashable, Sendable {
        /// One entry for each word of the script, in its order.
        public var words: [Transcript.Alignment.Word]
        /// The spoken words that match no word of the script, in the order spoken.
        public var extras: [Transcript.Alignment.Extra]
        /// The transcript the script was set against.
        public var transcript: Transcript

        /// The alignment of `script` to `transcript`.
        public init(_ script: Transcript.Script, to transcript: Transcript) {
            var words: [Transcript.Alignment.Word] = []
            var extras: [Transcript.Alignment.Extra] = []
            var i = 0
            var j = 0
            for step in Transcript.Alignment.path(script.words.map(\.key), transcript.words.map { Transcript.key(of: $0.text) }) {
                switch step.move {
                case .both:
                    let heard = transcript.words[j]
                    words.append(.init(script.words[i], heard: .init(words: [heard], span: heard.span, exact: step.exact), spoken: [j]))

                case .missing:
                    words.append(.init(script.words[i], heard: nil, spoken: []))

                case .extra:
                    extras.append(.init(transcript.words[j], after: words.indices.last.map { Ordinal(UInt($0)) }, spoken: j))

                case .joined:
                    let heard = transcript.words[j]
                    let first = script.words[i]
                    let second = script.words[i + 1]
                    let middle = Transcript.Alignment.divide(heard.span, first.key.count, second.key.count)
                    words.append(.init(first, heard: .init(words: [heard], span: heard.span.lowerBound..<middle, exact: step.exact), spoken: [j]))
                    words.append(.init(second, heard: .init(words: [heard], span: middle..<heard.span.upperBound, exact: step.exact), spoken: [j]))

                case .split:
                    let heard = [transcript.words[j], transcript.words[j + 1]]
                    let span = min(heard[0].span.lowerBound, heard[1].span.lowerBound)..<max(heard[0].span.upperBound, heard[1].span.upperBound)
                    words.append(.init(script.words[i], heard: .init(words: heard, span: span, exact: step.exact), spoken: [j, j + 1]))
                }
                i += step.move.script
                j += step.move.spoken
            }
            self.words = words
            self.extras = extras
            self.transcript = transcript
        }
    }
}

extension Transcript.Alignment {
    /// The script words that were not heard.
    public var missing: [Transcript.Alignment.Word] {
        words.filter { $0.heard == nil }
    }

    /// What was spoken for the words of a paragraph, as a transcript: the spoken words its script words were heard
    /// as, and the extras that follow one of its words, each once, in the order spoken.
    public func transcript(ofParagraph paragraph: Ordinal) -> Transcript {
        var indices = Set<Int>()
        for word in words where word.script.paragraph == paragraph {
            indices.formUnion(word.spoken)
        }
        for extra in extras {
            guard let after = extra.after, words[after].script.paragraph == paragraph else { continue }
            indices.insert(extra.spoken)
        }
        return Transcript(indices.sorted().map { transcript.words[$0] })
    }
}

extension Transcript.Alignment {
    /// The cost of a script word not heard, or of a spoken word not in the script.
    static let gap = 1.0
    /// What a join or a split costs on top of one less the likeness of the joined keys.
    static let joining = 0.8

    /// The instant that divides `span` in the proportion of `first` to `second`.
    static func divide(_ span: Range<Rational>, _ first: Int, _ second: Int) -> Rational {
        let share: Rational
        do throws(Rational.Error) {
            share = try Rational(numerator: first, denominator: first + second)
        } catch {
            share = .half
        }
        return span.lowerBound + (span.upperBound - span.lowerBound) * share
    }

    /// The least-cost path through script keys `s` and spoken keys `t`; of equal costs it prefers, at each word from
    /// the end, matching over joining, splitting, a missing script word and an extra spoken word, in that order.
    static func path(_ s: [Swift.String], _ t: [Swift.String]) -> [Transcript.Alignment.Step] {
        let width = t.count + 1
        var cost = Array(repeating: Double.infinity, count: (s.count + 1) * width)
        var back = Array(repeating: Step(move: .extra, exact: false), count: (s.count + 1) * width)
        cost[0] = 0
        (0..<cost.count).dropFirst().forEach { cell in
            let i = cell / width
            let j = cell % width
            var best = Double.infinity
            var choice = Step(move: .extra, exact: false)
            func consider(_ candidate: Double, _ step: Step) {
                if candidate < best {
                    best = candidate
                    choice = step
                }
            }
            if i > 0, j > 0 {
                let likeness = Transcript.likeness(s[i - 1], t[j - 1])
                if likeness > 0.5 { consider(cost[cell - width - 1] + 1 - likeness, Step(move: .both, exact: likeness == 1)) }
            }
            if i > 1, j > 0 {
                let likeness = Transcript.likeness(s[i - 2] + s[i - 1], t[j - 1])
                if likeness > 0.9 { consider(cost[cell - 2 * width - 1] + joining + 1 - likeness, Step(move: .joined, exact: likeness == 1)) }
            }
            if i > 0, j > 1 {
                let likeness = Transcript.likeness(s[i - 1], t[j - 2] + t[j - 1])
                if likeness > 0.9 { consider(cost[cell - width - 2] + joining + 1 - likeness, Step(move: .split, exact: likeness == 1)) }
            }
            if i > 0 { consider(cost[cell - width] + gap, Step(move: .missing, exact: false)) }
            if j > 0 { consider(cost[cell - 1] + gap, Step(move: .extra, exact: false)) }
            cost[cell] = best
            back[cell] = choice
        }
        var steps: [Step] = []
        var cell = cost.indices.last ?? 0
        while cell > 0 {
            let step = back[cell]
            steps.append(step)
            cell -= step.move.script * width + step.move.spoken
        }
        return steps.reversed()
    }
}
