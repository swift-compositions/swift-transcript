public import Rate
public import Rational

/// Speech written down as timed words, in the order they were spoken.
public struct Transcript: Hashable, Sendable {
    /// The words, in the order they were spoken.
    public var words: [Transcript.Word]

    /// A transcript of `words`, kept in the order given.
    public init(_ words: [Transcript.Word]) {
        self.words = words
    }
}

extension Transcript {
    /// From the earliest start of a word to the latest end, or `nil` when there are no words.
    public var span: Range<Rational>? {
        guard let start = words.map(\.span.lowerBound).min(), let end = words.map(\.span.upperBound).max() else { return nil }
        return start..<end
    }

    /// Words a second over the transcript's span, or `nil` when it has no words or its span lasts no time.
    public var pace: Rate? {
        guard let span, span.upperBound > span.lowerBound else { return nil }
        let frequency: Rational
        do throws(Rational.Error) {
            frequency = try Rational(words.count).divided(by: span.upperBound - span.lowerBound)
        } catch {
            return nil
        }
        do throws(Rate.Error) {
            return try Rate(frequency)
        } catch {
            return nil
        }
    }

    /// The silences between one word's end and the next word's start, in the order spoken, that last longer than
    /// `least` seconds.
    public func pauses(longerThan least: Rational) -> [Range<Rational>] {
        zip(words, words.dropFirst()).compactMap { word, next in
            let gap = word.span.upperBound..<max(word.span.upperBound, next.span.lowerBound)
            return gap.upperBound - gap.lowerBound > least ? gap : nil
        }
    }
}

extension Transcript {
    /// What of a word counts when two are compared: its letters and digits, lowercased, with the accents of Latin
    /// vowels, ñ and ç taken off, and nothing else, so punctuation, quotes, dashes, apostrophes and hyphens fall
    /// away and a word of none of these has no key.
    static func key(of text: Swift.String) -> Swift.String {
        Swift.String(text.lowercased().map { Transcript.plain[$0] ?? $0 }.filter { $0.isLetter || $0.isNumber })
    }

    /// The lowercase Latin letters with an accent, each to its letter without; a letter and its accent written as
    /// two scalars is the same character as the one written as one.
    static let plain: [Character: Character] = {
        let groups: [(Swift.String, Character)] = [
            ("àáâãäåā", "a"), ("èéêëē", "e"), ("ìíîïī", "i"), ("òóôõöøō", "o"), ("ùúûüū", "u"), ("ýÿ", "y"), ("ñ", "n"), ("ç", "c"),
        ]
        var table: [Character: Character] = [:]
        for (accented, letter) in groups {
            for character in accented { table[character] = letter }
        }
        return table
    }()

    /// How alike two keys are, from 0 to 1: one less their edit distance over the longer one's characters.
    static func likeness(_ a: Swift.String, _ b: Swift.String) -> Double {
        let a = Array(a)
        let b = Array(b)
        let longer = max(a.count, b.count)
        guard longer > 0 else { return 1 }
        var previous = Array(0...b.count)
        for i in a.indices {
            var current = [i + 1]
            for j in b.indices {
                current.append(min(previous[j] + (a[i] == b[j] ? 0 : 1), previous[j + 1] + 1, current[j] + 1))
            }
            previous = current
        }
        return 1 - Double(previous[b.count]) / Double(longer)
    }
}
