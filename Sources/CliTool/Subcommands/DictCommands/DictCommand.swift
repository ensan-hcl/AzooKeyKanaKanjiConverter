import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary
import ArgumentParser

extension Subcommands {
    struct Dict: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "dict",
            abstract: "Show dict information", 
            subcommands: [Self.Read.self]
        )
    }
}
