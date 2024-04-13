import KanaKanjiConverterModuleWithDefaultDictionary
import ArgumentParser
import Foundation

extension Subcommands {
    struct Run: AsyncParsableCommand {
        @Argument(help: "ひらがなで表記された入力")
        var input: String = ""

        @Option(name: [.customLong("config_n_best")], help: "The parameter n (n best parameter) for internal viterbi search.")
        var configNBest: Int = 10
        @Option(name: [.customShort("n"), .customLong("top_n")], help: "Display top n candidates.")
        var displayTopN: Int = 1
        @Option(name: [.customLong("gpt2")], help: "ggml format model weight for gpt2.")
        var gpt2ModelWeightPath: String = ""


        @Flag(name: [.customLong("disable_prediction")], help: "Disable producing prediction candidates.")
        var disablePrediction = false

        static var configuration = CommandConfiguration(commandName: "run", abstract: "Show help for this utility.")

        @MainActor mutating func run() async {
            let converter = KanaKanjiConverter()
            var composingText = ComposingText()
            composingText.insertAtCursorPosition(input, inputStyle: .direct)
            let result = await converter.requestCandidates(composingText, options: requestOptions())
            for (i, candidate) in zip(0 ..< self.displayTopN, result.mainResults.prefix(self.displayTopN)) {
                print(i, candidate.text)
            }
        }

        func requestOptions() -> ConvertRequestOptions {
            .withDefaultDictionary(
                N_best: configNBest,
                requireJapanesePrediction: !disablePrediction,
                requireEnglishPrediction: false,
                keyboardLanguage: .ja_JP,
                typographyLetterCandidate: false,
                unicodeCandidate: true,
                englishCandidateInRoman2KanaInput: true,
                fullWidthRomanCandidate: false,
                halfWidthKanaCandidate: false,
                learningType: .nothing,
                maxMemoryCount: 0,
                shouldResetMemory: false,
                memoryDirectoryURL: URL(fileURLWithPath: ""),
                sharedContainerURL: URL(fileURLWithPath: ""),
                gpt2WeightURL: self.gpt2ModelWeightPath.isEmpty ? nil : URL(string: self.gpt2ModelWeightPath),
                metadata: .init(appVersionString: "anco")
            )
        }
    }
}
