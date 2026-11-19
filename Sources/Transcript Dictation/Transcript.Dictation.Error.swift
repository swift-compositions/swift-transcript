#if Dictation && canImport(Speech) && canImport(AVFAudio)
    public import Transcript

    extension Transcript.Dictation {
        /// Why a recording could not be heard.
        public enum Error: Swift.Error, Hashable, Sendable {
            /// The device has no dictation for the language.
            case language(Swift.String)
            /// The recording could not be read or heard, with the reason.
            case unreadable(Swift.String)
        }
    }
#endif
