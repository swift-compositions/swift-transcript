#if Dictation && canImport(Speech) && canImport(AVFAudio)
    import Foundation
    import Path
    import RFC_5646
    import Testing
    import Transcript_Dictation

    @Suite struct `Dictation Tests` {
        static let dutch: RFC_5646.LanguageTag = {
            do { return try RFC_5646.LanguageTag("nl-NL") } catch { preconditionFailure("nl-NL is a language tag") }
        }()

        /// `text` spoken by the system's Dutch voice into a recording of its own.
        static func spoken(_ text: Swift.String) throws -> Swift.String {
            let path = FileManager.default.temporaryDirectory.appendingPathComponent("spoken-\(UUID().uuidString).aiff").path
            let say = Process()
            say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            say.arguments = ["-v", "Xander", "-o", path, text]
            try say.run()
            say.waitUntilExit()
            #expect(say.terminationStatus == 0)
            return path
        }

        @Test func `Dutch speech is heard as timed words that align to its script, with its pause`() async throws {
            let script = Transcript.Script("De kat sliep op de mat.\n\nDaarna viel de sneeuw, en de molen draaide langzaam boven het veld.")
            let path = try Self.spoken("De kat sliep op de mat. [[slnc 1500]] Daarna viel de sneeuw, en de molen draaide langzaam boven het veld.")
            defer { try? FileManager.default.removeItem(atPath: path) }
            let transcript = try await Transcript(dictating: try Path(validating: path), in: Self.dutch)
            let alignment = Transcript.Alignment(script, to: transcript)
            #expect(alignment.missing.isEmpty, "\(transcript.words.map(\.text))")
            let starts = alignment.words.compactMap { $0.heard?.span.lowerBound }
            #expect(starts == starts.sorted())
            #expect(transcript.words.allSatisfy { $0.confidence != nil })
            let pauses = transcript.pauses(longerThan: Rational(1))
            #expect(pauses.count == 1)
            let mat = alignment.words[5].heard?.span.upperBound
            #expect(pauses.first?.lowerBound == mat)
        }

        @Test func `a file that is not audio cannot be heard`() async throws {
            let path = FileManager.default.temporaryDirectory.appendingPathComponent("not-\(UUID().uuidString).m4a").path
            try Data("not audio".utf8).write(to: URL(fileURLWithPath: path))
            defer { try? FileManager.default.removeItem(atPath: path) }
            await #expect(throws: Transcript.Dictation.Error.self) {
                try await Transcript(dictating: try Path(validating: path), in: Self.dutch)
            }
        }
    }
#endif
