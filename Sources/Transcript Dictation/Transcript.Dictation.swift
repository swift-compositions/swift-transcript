#if Dictation && canImport(Speech) && canImport(AVFAudio)
    import CoreMedia
    import Speech
    public import Transcript

    extension Transcript {
        /// A recording heard on the device by the system's dictation.
        public enum Dictation {}
    }

    extension Transcript.Dictation {
        /// The words of a result: runs joined up to whitespace, each spanning its first run's start to its last
        /// run's end, as sure as its least sure run. Runs with no time are left out.
        static func words(in text: AttributedString) -> [Transcript.Word] {
            var words: [Transcript.Word] = []
            var pending: (text: Swift.String, start: Rational, end: Rational, confidence: Double?)?
            func flush() {
                if let word = pending {
                    let trimmed = Swift.String(word.text.filter { !$0.isWhitespace })
                    if !trimmed.isEmpty {
                        words.append(.init(trimmed, over: word.start..<max(word.start, word.end), confidence: word.confidence.map { Interval.Unit(clamping: $0) }))
                    }
                }
                pending = nil
            }
            for run in text.runs {
                let piece = Swift.String(text[run.range].characters)
                guard let range = run.audioTimeRange, let start = seconds(range.start), let end = seconds(range.end) else { continue }
                if piece.first?.isWhitespace == true { flush() }
                let confidence = run.transcriptionConfidence
                if var word = pending {
                    word.text += piece
                    word.end = end
                    word.confidence = [word.confidence, confidence].compactMap(\.self).min()
                    pending = word
                } else {
                    pending = (piece, start, end, confidence)
                }
                if piece.last?.isWhitespace == true { flush() }
            }
            flush()
            return words
        }

        /// A time as exact seconds, or `nil` when it is not a number.
        static func seconds(_ time: CMTime) -> Rational? {
            guard time.isNumeric else { return nil }
            do throws(Rational.Error) {
                return try Rational(numerator: time.value, denominator: time.timescale)
            } catch {
                return nil
            }
        }
    }
#endif
