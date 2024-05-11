import KanaKanjiConverterModuleWithDefaultDictionary
import ArgumentParser
import Foundation

extension Subcommands {
    struct ExperimentalEvaluate: ParsableCommand {
        @Argument(help: "入力")
        var input: String = ""

        @Option(name: [.customLong("zenz")], help: "gguf format model weight for zenz.")
        var zenzWeightPath: String = ""

        static var configuration = CommandConfiguration(commandName: "experimental_evaluate", abstract: "Evaluate input with gpt-2.")

        @MainActor func run() throws {
            let converter = KanaKanjiConverter()
            guard !self.zenzWeightPath.isEmpty else {
                fatalError("zenzWeightPath must not be empty")
            }
            guard let modelURL = URL(string: self.zenzWeightPath) else {
                fatalError("invalid url")
            }
            let result = converter._zenz_evaluate(input: [input], modelURL: modelURL)
            print(result)
        }
    }

    struct ExperimentalReview: ParsableCommand {
        @Argument(help: "入力")
        var input: String = ""
        @Argument(help: "変換")
        var candidate: String = ""

        @Option(name: [.customLong("zenz")], help: "gguf format model weight for zenz.")
        var zenzWeightPath: String = ""

        static var configuration = CommandConfiguration(commandName: "experimental_review", abstract: "Evaluate input with gpt-2.")

        @MainActor func run() throws {
            let converter = KanaKanjiConverter()
            guard !self.zenzWeightPath.isEmpty else {
                fatalError("zenzWeightPath must not be empty")
            }
            guard let modelURL = URL(string: self.zenzWeightPath) else {
                fatalError("invalid url")
            }
            converter._zenz_candidate_evaluate(input: input.toKatakana(), candidate: candidate, modelURL: modelURL)
        }
    }


    struct ExperimentalRun: ParsableCommand {
        @Argument(help: "入力")
        var input: String = ""

        @Option(name: [.customLong("zenz")], help: "gguf format model weight for zenz.")
        var zenzWeightPath: String = ""

        static var configuration = CommandConfiguration(commandName: "experimental_run", abstract: "Run conversion with gpt-2.")

        @MainActor func run() throws {
            let converter = KanaKanjiConverter()
            guard !self.zenzWeightPath.isEmpty else {
                fatalError("zenzWeightPath must not be empty")
            }
            guard let modelURL = URL(string: self.zenzWeightPath) else {
                fatalError("invalid url")
            }
            let result = converter._zenz_candidate_run(input: input.toKatakana(), modelURL: modelURL, options: requestOptions())
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
                zenzWeightURL: URL(string: self.zenzWeightPath),
                metadata: .init(versionString: "anco for debugging")
            )
            return option
        }
    }
}
