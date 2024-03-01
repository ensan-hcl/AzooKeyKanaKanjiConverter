import KanaKanjiConverterModuleWithDefaultDictionary
import ArgumentParser
import Foundation

extension Subcommands {
    struct Evaluate: AsyncParsableCommand {
        @Argument(help: "入力")
        var input: String = ""

        static var configuration = CommandConfiguration(commandName: "evaluate", abstract: "Evaluate input with gpt-2.")

        @MainActor func run() async throws {
            let converter = KanaKanjiConverter()
            let result = await converter._gpt2_evaluate(input: [input])
            print(result)
        }
    }
}
