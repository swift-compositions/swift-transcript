#if Dictation && canImport(Speech) && canImport(AVFAudio)
    import AVFAudio
    public import Path
    import Path_Foundation_Integration
    public import RFC_5646
    import Speech
    public import Transcript

    extension Transcript {
        /// The words spoken in the recording at a path, heard on the device by the system's dictation in `language`,
        /// with when each was spoken and how sure the dictation was of it. `expecting` are handed to the analyzer as
        /// contextual strings, as given. The first call for a language may download the dictation's assets. A
        /// language the device has no dictation for fails with `.language`, and a recording that cannot be read or
        /// heard with `.unreadable`. The path becomes a URL only where the Speech framework takes one.
        public init(dictating path: Path, in language: RFC_5646.LanguageTag, expecting: [Swift.String] = []) async throws(Transcript.Dictation.Error) {
            let url = URL(path)
            guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: language.value)) else {
                throw .language(language.value)
            }
            let module = DictationTranscriber(
                locale: locale,
                contentHints: [],
                transcriptionOptions: [],
                reportingOptions: [],
                attributeOptions: [.audioTimeRange, .transcriptionConfidence]
            )
            // swift-linter:disable:next do throws for typed catch
            // REASON: AssetInventory, AVAudioFile and SpeechAnalyzer throw untyped; their errors become Error.unreadable.
            do {
                if let installation = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
                    try await installation.downloadAndInstall()
                }
                let file = try AVAudioFile(forReading: url)
                let analyzer = SpeechAnalyzer(modules: [module])
                let context = AnalysisContext()
                context.contextualStrings[.general] = expecting
                try await analyzer.setContext(context)
                let collecting = Task {
                    var words: [Transcript.Word] = []
                    for try await result in module.results where result.isFinal {
                        words += Transcript.Dictation.words(in: result.text)
                    }
                    return words
                }
                if let last = try await analyzer.analyzeSequence(from: file) {
                    try await analyzer.finalizeAndFinish(through: last)
                } else {
                    await analyzer.cancelAndFinishNow()
                }
                self.init(try await collecting.value)
            } catch {
                throw .unreadable("\(url.lastPathComponent): \(error)")
            }
        }
    }
#endif
