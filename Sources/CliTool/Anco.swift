import KanaKanjiConverterModuleWithDefaultDictionary
import ArgumentParser

@main
public struct Anco: ParsableCommand {
    public static var configuration = CommandConfiguration(
        abstract: "Anco is A(zooKey) Kana-Ka(n)ji (co)nverter",
        subcommands: [Subcommands.Run.self],
        defaultSubcommand: Subcommands.Run.self
    )

    public init() {}
}
