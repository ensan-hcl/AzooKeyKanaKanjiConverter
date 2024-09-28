import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary
import ArgumentParser

extension Subcommands {
    struct Dict: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "dict",
            abstract: "Show dict information", 
            subcommands: [Self.Read.self]
        )
    }
}
