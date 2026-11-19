import Testing
import Transcript

@Suite struct `Alignment Tests` {
    /// A transcript of words a third of a second each, one after the other from 0, with a gap after any word
    /// followed by `|`.
    static let third: Rational = {
        do throws(Rational.Error) { return try Rational(numerator: 1, denominator: 3) } catch { preconditionFailure("1/3 is a fraction") }
    }()

    static func spoken(_ text: Swift.String) -> Transcript {
        var words: [Transcript.Word] = []
        var at = Rational.zero
        let third = Self.third
        for token in text.split(separator: " ") {
            if token == "|" {
                at += 1
                continue
            }
            words.append(.init(Swift.String(token), over: at..<(at + third)))
            at += third
        }
        return Transcript(words)
    }

    @Test func `a script read as written is heard word for word, exactly`() {
        let alignment = Transcript.Alignment(.init("De kat sliep op de mat."), to: Self.spoken("de kat sliep op de mat"))
        #expect(alignment.words.count == 6)
        #expect(alignment.words.allSatisfy { $0.heard?.exact == true })
        #expect(alignment.extras.isEmpty)
        #expect(alignment.words[5].heard?.span.lowerBound == Rational(5) * Self.third)
    }

    @Test func `Dutch quotes, a dash and capitals do not count`() {
        let script = Transcript.Script("‘Zou het — ooit — lukken?’ vroeg ze.\n„Ja!” zei hij.")
        #expect(script.words.map(\.text) == ["‘Zou", "het", "ooit", "lukken?’", "vroeg", "ze.", "„Ja!”", "zei", "hij."])
        let alignment = Transcript.Alignment(script, to: Self.spoken("zou het ooit lukken vroeg ze ja zei hij"))
        #expect(alignment.words.allSatisfy { $0.heard?.exact == true })
    }

    @Test func `a slip is heard but not exact`() {
        let alignment = Transcript.Alignment(.init("de molen draaide"), to: Self.spoken("de molens draaide"))
        #expect(alignment.words[1].heard?.exact == false)
        #expect(alignment.words[1].heard?.words.map(\.text) == ["molens"])
        #expect(alignment.extras.isEmpty)
    }

    @Test func `a word left out is missing, and a word added is extra after the word it follows`() {
        let alignment = Transcript.Alignment(.init("de oude kat sliep"), to: Self.spoken("de kat sliep heel lang"))
        #expect(alignment.missing.map(\.script.text) == ["oude"])
        #expect(alignment.extras.map(\.word.text) == ["heel", "lang"])
        #expect(alignment.extras.map(\.after) == [3, 3])
    }

    @Test func `a word heard as something else entirely is missing, and what was heard extra`() {
        let alignment = Transcript.Alignment(.init("de kat sliep"), to: Self.spoken("de hond sliep"))
        #expect(alignment.missing.map(\.script.text) == ["kat"])
        #expect(alignment.extras.map(\.word.text) == ["hond"])
    }

    @Test func `a compound heard as two words is one word spanning both`() {
        let alignment = Transcript.Alignment(.init("de donderwolken kwamen"), to: Self.spoken("de donder wolken kwamen"))
        #expect(alignment.words.count == 3)
        #expect(alignment.words[1].heard?.words.map(\.text) == ["donder", "wolken"])
        #expect(alignment.words[1].heard?.exact == true)
        let third = Self.third
        #expect(alignment.words[1].heard?.span == third..<(third * 3))
        #expect(alignment.extras.isEmpty)
    }

    @Test func `two words heard as one share its time by their letters`() throws {
        let alignment = Transcript.Alignment(.init("hij keek over het dorp"), to: Self.spoken("hij keek overhet dorp"))
        let over = alignment.words[2].heard
        let het = alignment.words[3].heard
        let third = Self.third
        #expect(over?.span.lowerBound == third * 2)
        #expect(over?.span.upperBound == het?.span.lowerBound)
        #expect(het?.span.upperBound == third * 3)
        // "over" has four of the seven letters.
        #expect(over.map { $0.span.upperBound - $0.span.lowerBound } == third * (try Rational(numerator: 4, denominator: 7)))
    }

    @Test func `a line read twice is timed by its last reading`() {
        let alignment = Transcript.Alignment(.init("het lampje brandde"), to: Self.spoken("het lampje | het lampje brandde"))
        #expect(alignment.extras.map(\.word.text) == ["het", "lampje"])
        #expect(alignment.extras.map(\.after) == [nil, nil])
        let second = alignment.transcript.words[2].span
        #expect(alignment.words[0].heard?.span == second)
    }

    @Test func `an accent for stress does not count`() {
        let alignment = Transcript.Alignment(.init("Dat was één idee, dát wél."), to: Self.spoken("dat was een idee dat wel"))
        #expect(alignment.words.allSatisfy { $0.heard?.exact == true })
        let decomposed = Transcript.Alignment(.init("ide\u{65}\u{308}en"), to: Self.spoken("ideeen"))
        #expect(decomposed.words.allSatisfy { $0.heard?.exact == true })
    }

    @Test func `a word heard as itself is not joined into its neighbour's slip`() {
        let alignment = Transcript.Alignment(.init("ging verder. De brandstof"), to: Self.spoken("ging ver De brandstof"))
        #expect(alignment.words[2].heard?.words.map(\.text) == ["De"])
        #expect(alignment.words[3].heard?.words.map(\.text) == ["brandstof"])
        #expect(alignment.words[2].heard?.exact == true)
        #expect(alignment.words[3].heard?.exact == true)
    }

    @Test func `numbers count by their digits`() {
        let alignment = Transcript.Alignment(.init("In 2009 schreef hij"), to: Self.spoken("in 2009 schreef hij"))
        #expect(alignment.words.allSatisfy { $0.heard?.exact == true })
        let words = Transcript.Alignment(.init("In 2009 schreef hij"), to: Self.spoken("in tweeduizendnegen schreef hij"))
        #expect(words.missing.map(\.script.text) == ["2009"])
    }

    @Test func `paragraphs end at a blank line and lines count within them`() {
        let script = Transcript.Script("Een twee\ndrie\n\n —\n\nvier")
        #expect(script.words.map(\.paragraph) == [0, 0, 0, 1])
        #expect(script.words.map(\.line) == [0, 0, 1, 0])
        #expect(script.paragraphs == [0, 1])
    }

    @Test func `a paragraph's transcript holds its heard words and the extras that follow them`() {
        let script = Transcript.Script("een twee\n\ndrie vier")
        let alignment = Transcript.Alignment(script, to: Self.spoken("een twee eh | drie vier"))
        #expect(alignment.transcript(ofParagraph: 0).words.map(\.text) == ["een", "twee", "eh"])
        #expect(alignment.transcript(ofParagraph: 1).words.map(\.text) == ["drie", "vier"])
    }
}
