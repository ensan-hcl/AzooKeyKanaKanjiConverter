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
}
