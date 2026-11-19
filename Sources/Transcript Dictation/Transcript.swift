#if Dictation && canImport(Speech) && canImport(AVFAudio)
    import AVFAudio
    public import Path
    public import RFC_5646
    public import Sound_Decoding
    import Speech
    public import Transcript

    extension Transcript {
        /// The words spoken in the recording at a path, decoded at 16,000 ticks a second by swift-sound and heard as
        /// `Transcript(dictating:in:expecting:)` hears a sound. A recording that cannot be decoded fails with
        /// `.unreadable`.
        public init(dictating path: Path, in language: RFC_5646.LanguageTag, expecting: [Swift.String] = []) async throws(Transcript.Dictation.Error) {
            let rate: Rate
            do throws(Rate.Error) {
                rate = try Rate(16000)
            } catch {
                throw .unreadable("\(error)")
            }
            let sound: Signal<Float>
            do throws(Sound.Decoding.Error) {
                sound = try Signal(decoding: path, rate: rate)
            } catch {
                throw .unreadable("\(error)")
            }
            try await self.init(dictating: sound, in: language, expecting: expecting)
        }

        /// The words spoken in a sound, heard on the device by the system's dictation in `language`, with when each
        /// was spoken and how sure the dictation was of it.
        ///
        /// The sound is heard in pieces cut in its silences (`Transcript.Dictation.pieces(of:)`), each by an
        /// analyzer of its own, and the words of each are put back at their time in the sound. `expecting` are
        /// handed to each analyzer as contextual strings, as given. The first call for a language may download the
        /// dictation's assets. A language the device has no dictation for fails with `.language`, and a piece the
        /// dictation cannot hear with `.unreadable`.
        public init(dictating sound: Signal<Float>, in language: RFC_5646.LanguageTag, expecting: [Swift.String] = []) async throws(Transcript.Dictation.Error) {
            guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: language.value)) else {
                throw .language(language.value)
            }
            var words: [Transcript.Word] = []
            for piece in Transcript.Dictation.pieces(of: sound) {
                words += try await Transcript.Dictation.words(in: sound, over: piece, locale: locale, expecting: expecting)
            }
            self.init(words)
        }
    }
#endif
