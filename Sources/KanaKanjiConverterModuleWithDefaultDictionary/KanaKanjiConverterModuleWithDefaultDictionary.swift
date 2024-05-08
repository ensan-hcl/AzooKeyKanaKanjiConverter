@_exported import KanaKanjiConverterModule
import Foundation

public extension ConvertRequestOptions {
    static func withDefaultDictionary(
        N_best: Int = 10,
        requireJapanesePrediction: Bool,
        requireEnglishPrediction: Bool,
        keyboardLanguage: KeyboardLanguage,
        typographyLetterCandidate: Bool = false,
        unicodeCandidate: Bool = true,
        englishCandidateInRoman2KanaInput: Bool = false,
        fullWidthRomanCandidate: Bool = false,
        halfWidthKanaCandidate: Bool = false,
        learningType: LearningType,
        maxMemoryCount: Int = 65536,
        shouldResetMemory: Bool = false,
        memoryDirectoryURL: URL,
        sharedContainerURL: URL,
        gpt2WeightURL: URL? = nil,
        textReplacer: TextReplacer = TextReplacer(),
        metadata: ConvertRequestOptions.Metadata?
    ) -> Self {
        #if os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
        let dictionaryDirectory = Bundle.module.bundleURL.appendingPathComponent("Dictionary", isDirectory: true)
        #elseif os(macOS)
        let dictionaryDirectory = Bundle.module.resourceURL!.appendingPathComponent("Dictionary", isDirectory: true)
        #else
        let dictionaryDirectory = Bundle.module.resourceURL!.appendingPathComponent("Dictionary", isDirectory: true)
        #endif
        return Self(
            N_best: N_best,
            requireJapanesePrediction: requireJapanesePrediction,
            requireEnglishPrediction: requireEnglishPrediction,
            keyboardLanguage: keyboardLanguage,
            typographyLetterCandidate: typographyLetterCandidate,
            unicodeCandidate: unicodeCandidate,
            englishCandidateInRoman2KanaInput: englishCandidateInRoman2KanaInput,
            fullWidthRomanCandidate: fullWidthRomanCandidate,
            halfWidthKanaCandidate: halfWidthKanaCandidate,
            learningType: learningType,
            maxMemoryCount: maxMemoryCount,
            shouldResetMemory: shouldResetMemory,
            dictionaryResourceURL: dictionaryDirectory,
            memoryDirectoryURL: memoryDirectoryURL,
            sharedContainerURL: sharedContainerURL,
            textReplacer: textReplacer,
            gpt2WeightURL: gpt2WeightURL,
            metadata: metadata
        )
    }
}
