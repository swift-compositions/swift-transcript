import Testing
import Transcript

@Suite struct `Measures Tests` {
    @Test func `pace is words over the span`() throws {
        let transcript = `Alignment Tests`.spoken("een twee drie | vier vijf zes")
        // Three thirds, a second of silence, three thirds: three seconds for six words.
        #expect(transcript.span == .zero..<Rational(3))
        #expect(transcript.pace == (try Rate(2)))
    }

    @Test func `no words have no pace`() {
        #expect(Transcript([]).pace == nil)
        #expect(Transcript([]).span == nil)
    }

    @Test func `pauses are the gaps longer than the least asked for`() {
        let transcript = `Alignment Tests`.spoken("een twee | drie vier")
        let third = `Alignment Tests`.third
        let start = third * 2
        #expect(transcript.pauses(longerThan: .half) == [start..<(start + 1)])
        #expect(transcript.pauses(longerThan: Rational(1)).isEmpty)
    }
}
