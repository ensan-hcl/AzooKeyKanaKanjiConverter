import KanaKanjiConverterModuleWithDefaultDictionary
import ArgumentParser
import Foundation

extension Subcommands {
    struct ExperimentalEvaluate: ParsableCommand {
        @Argument(help: "入力")
        var input: String = ""

        @Option(name: [.customLong("gpt2")], help: "ggml format model weight for gpt2.")
        var gpt2ModelWeightPath: String = ""

        static var configuration = CommandConfiguration(commandName: "experimental_evaluate", abstract: "Evaluate input with gpt-2.")

        @MainActor func run() throws {
            let converter = KanaKanjiConverter()
            guard !self.gpt2ModelWeightPath.isEmpty else {
                fatalError("gpt2ModelWeightPath must not be empty")
            }
            guard let modelURL = URL(string: self.gpt2ModelWeightPath) else {
                fatalError("invalid url")
            }
            let result = converter._gpt2_evaluate(input: [input], modelURL: modelURL)
            print(result)
        }
    }

    struct ExperimentalReview: ParsableCommand {
        @Argument(help: "入力")
        var input: String = ""
        @Argument(help: "変換")
        var candidate: String = ""

        @Option(name: [.customLong("gpt2")], help: "ggml format model weight for gpt2.")
        var gpt2ModelWeightPath: String = ""

        static var configuration = CommandConfiguration(commandName: "experimental_review", abstract: "Evaluate input with gpt-2.")

        @MainActor func run() throws {
            let converter = KanaKanjiConverter()
            guard !self.gpt2ModelWeightPath.isEmpty else {
                fatalError("gpt2ModelWeightPath must not be empty")
            }
            guard let modelURL = URL(string: self.gpt2ModelWeightPath) else {
                fatalError("invalid url")
            }
            converter._gpt2_candidate_evaluate(input: input.toKatakana(), candidate: candidate, modelURL: modelURL)
        }
    }


    struct ExperimentalRun: ParsableCommand {
        @Argument(help: "入力")
        var input: String = ""

        @Option(name: [.customLong("gpt2")], help: "ggml format model weight for gpt2.")
        var gpt2ModelWeightPath: String = ""

        static var configuration = CommandConfiguration(commandName: "experimental_run", abstract: "Run conversion with gpt-2.")

        @MainActor func run() throws {
            let converter = KanaKanjiConverter()
            guard !self.gpt2ModelWeightPath.isEmpty else {
                fatalError("gpt2ModelWeightPath must not be empty")
            }
            guard let modelURL = URL(string: self.gpt2ModelWeightPath) else {
                fatalError("invalid url")
            }
            let result = converter._gpt2_candidate_run(input: input.toKatakana(), modelURL: modelURL, options: requestOptions())
            for candidate in result {
                print(candidate.text)
            }
        }

        func requestOptions() -> ConvertRequestOptions {
            var option: ConvertRequestOptions = .withDefaultDictionary(
                N_best: 1,
                requireJapanesePrediction: false,
                requireEnglishPrediction: false,
                keyboardLanguage: .ja_JP,
                typographyLetterCandidate: false,
                unicodeCandidate: true,
                englishCandidateInRoman2KanaInput: false,
                fullWidthRomanCandidate: false,
                halfWidthKanaCandidate: false,
                learningType: .nothing,
                maxMemoryCount: 0,
                shouldResetMemory: false,
                memoryDirectoryURL: URL(fileURLWithPath: ""),
                sharedContainerURL: URL(fileURLWithPath: ""),
                gpt2WeightURL: URL(string: self.gpt2ModelWeightPath),
                metadata: .init(versionString: "anco for debugging")
            )
            return option
        }
    }
}
