#if Dictation && canImport(Speech) && canImport(AVFAudio)
    import AVFAudio
    import CoreMedia
    public import Rational
    public import Sound
    import Speech
    public import Transcript

    extension Transcript {
        /// A recording heard on the device by the system's dictation.
        public enum Dictation {}
    }

    extension Transcript.Dictation {
        /// The longest piece the dictation is handed where a silence allows: 9 seconds.
        ///
        /// Measured on macOS 27.2 with nl-NL: on a minute of read Dutch the dictation returned no words without an
        /// error, and a 14-second piece of it failed with `RecogFailed`; over 30 pieces of up to 9 seconds cut in
        /// silences, every one was heard.
        public static let longest = Rational(9)

        /// The pieces a sound is heard in, in order and together the whole sound.
        ///
        /// The sound is cut in the middle of each of its silences under −40 dBFS longer than a quarter of a second
        /// (`silences(below:longerThan:)` of swift-sound), and neighbouring stretches are joined while a piece
        /// stays within `longest`. A stretch with no such silence for longer than `longest` stays one piece.
        public static func pieces(of sound: Signal<Float>) -> [Range<Rational>] {
            let quarter: Rational
            do throws(Rational.Error) {
                quarter = try Rational(numerator: 1, denominator: 4)
            } catch {
                quarter = .half
            }
            let cuts = sound.silences(longerThan: quarter).map { ($0.lowerBound + $0.upperBound) * .half }
            var pieces: [Range<Rational>] = []
            var start = Rational.zero
            var last = Rational.zero
            for cut in cuts + [sound.duration] {
                if cut - start > longest, last > start {
                    pieces.append(start..<last)
                    start = last
                }
                last = cut
            }
            if sound.duration > start { pieces.append(start..<sound.duration) }
            return pieces
        }

        /// The words heard in one piece of a sound, at their time in the sound.
        static func words(in sound: Signal<Float>, over piece: Range<Rational>, locale: Locale, expecting: [Swift.String]) async throws(Transcript.Dictation.Error) -> [Transcript.Word] {
            let module = DictationTranscriber(
                locale: locale,
                contentHints: [],
                transcriptionOptions: [],
                reportingOptions: [],
                attributeOptions: [.audioTimeRange, .transcriptionConfidence]
            )
            // swift-linter:disable:next do throws for typed catch
            // REASON: AssetInventory, AVAudioConverter and SpeechAnalyzer throw untyped; their errors become Error.unreadable.
            do {
                if let installation = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                    try await installation.downloadAndInstall()
                }
                let buffer = try await Self.buffer(of: sound, over: piece, for: module)
                let analyzer = SpeechAnalyzer(modules: [module])
                let context = AnalysisContext()
                context.contextualStrings[.general] = expecting
                try await analyzer.setContext(context)
                let collecting = Task {
                    var words: [Transcript.Word] = []
                    for try await result in module.results where result.isFinal {
                        words += Self.words(in: result.text, after: piece.lowerBound)
                    }
                    return words
                }
                let (input, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
                continuation.yield(AnalyzerInput(buffer: buffer))
                continuation.finish()
                if let last = try await analyzer.analyzeSequence(input) {
                    try await analyzer.finalizeAndFinish(through: last)
                } else {
                    await analyzer.cancelAndFinishNow()
                }
                return try await collecting.value
            } catch {
                throw .unreadable("\(piece.lowerBound.approximation(as: Double.self)) s: \(error)")
            }
        }

        /// One piece of a sound as a buffer in the format the dictation hears best.
        static func buffer(of sound: Signal<Float>, over piece: Range<Rational>, for module: DictationTranscriber) async throws(Transcript.Dictation.Error) -> AVAudioPCMBuffer {
            let hertz = sound.rate.frequency.approximation(as: Double.self)
            let channels = Int(bitPattern: sound.channels)
            let ticks = sound.samples.count / max(1, channels)
            let first = min(ticks, Int((piece.lowerBound.approximation(as: Double.self) * hertz).rounded()))
            let end = min(ticks, Int((piece.upperBound.approximation(as: Double.self) * hertz).rounded()))
            guard
                let format = AVAudioFormat(standardFormatWithSampleRate: hertz, channels: AVAudioChannelCount(channels)),
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(max(1, end - first))),
                let data = unsafe buffer.floatChannelData
            else { throw .unreadable("a piece could not be laid in a buffer") }
            buffer.frameLength = AVAudioFrameCount(end - first)
            let samples = sound.samples
            (first..<end).forEach { tick in
                (0..<channels).forEach { channel in
                    unsafe data[channel][tick - first] = samples[tick * channels + channel]
                }
            }
            guard let best = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module], considering: format), best != format else {
                return buffer
            }
            guard best.sampleRate == hertz else {
                throw .unreadable("the dictation hears sound at \(best.sampleRate) ticks a second, not \(hertz)")
            }
            guard
                let converter = AVAudioConverter(from: format, to: best),
                let output = AVAudioPCMBuffer(pcmFormat: best, frameCapacity: buffer.frameLength)
            else { throw .unreadable("no conversion to \(best)") }
            converter.downmix = true
            // swift-linter:disable:next do throws for typed catch
            // REASON: AVAudioConverter throws untyped; its error becomes Error.unreadable.
            do {
                try converter.convert(to: output, from: buffer)
            } catch {
                throw .unreadable("conversion to \(best) failed: \(error)")
            }
            return output
        }

        /// The words of a result, `offset` seconds later: runs joined up to whitespace, each spanning its first
        /// run's start to its last run's end, as sure as its least sure run. Runs with no time are left out.
        static func words(in text: AttributedString, after offset: Rational) -> [Transcript.Word] {
            var words: [Transcript.Word] = []
            var pending: (text: Swift.String, start: Rational, end: Rational, confidence: Double?)?
            func flush() {
                if let word = pending {
                    let trimmed = Swift.String(word.text.filter { !$0.isWhitespace })
                    if !trimmed.isEmpty {
                        let span = (offset + word.start)..<(offset + max(word.start, word.end))
                        words.append(.init(trimmed, over: span, confidence: word.confidence.map { Interval.Unit(clamping: $0) }))
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
