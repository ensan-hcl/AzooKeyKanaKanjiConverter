import KanaKanjiConverterModuleWithDefaultDictionary
import ArgumentParser
import Foundation

extension Subcommands {
    struct Session: AsyncParsableCommand {
        @Argument(help: "ひらがなで表記された入力")
        var input: String = ""

        @Option(name: [.customLong("config_n_best")], help: "The parameter n (n best parameter) for internal viterbi search.")
        var configNBest: Int = 10
        @Option(name: [.customShort("n"), .customLong("top_n")], help: "Display top n candidates.")
        var displayTopN: Int = 1
        @Option(name: [.customLong("zenz")], help: "gguf format model weight for zenz.")
        var zenzWeightPath: String = ""
        @Flag(name: [.customLong("disable_prediction")], help: "Disable producing prediction candidates.")
        var disablePrediction = false
        @Flag(name: [.customLong("only_whole_conversion")], help: "Show only whole conversion (完全一致変換).")
        var onlyWholeConversion = false
        @Flag(name: [.customLong("report_score")], help: "Show internal score for the candidate.")
        var reportScore = false
        @Flag(name: [.customLong("roman2kana")], help: "Use roman2kana input.")
        var roman2kana = false


        static var configuration = CommandConfiguration(commandName: "session", abstract: "Start session for incremental input.")

        @MainActor mutating func run() async {
            let converter = KanaKanjiConverter()
            var composingText = ComposingText()
            let inputStyle: InputStyle = self.roman2kana ? .roman2kana : .direct
            while true {
                print()
                print("\(bold: "== type :q to end session, type :d to delete character, type any other text to input ==")")
                let input = readLine(strippingNewline: true) ?? ""
                switch input {
                case ":q": return
                case ":d":
                    composingText.deleteBackwardFromCursorPosition(count: 1)
                default:
                    composingText.insertAtCursorPosition(input, inputStyle: inputStyle)
                }
                print(composingText.convertTarget)
                let start = Date()
                let result = converter.requestCandidates(composingText, options: requestOptions())
                let mainResults = result.mainResults.filter {
                    !self.onlyWholeConversion || $0.data.reduce(into: "", {$0.append(contentsOf: $1.ruby)}) == input.toKatakana()
                }
                for candidate in mainResults.prefix(self.displayTopN) {
                    if self.reportScore {
                        print("\(candidate.text) \(bold: "score:") \(candidate.value)")
                    } else {
                        print(candidate.text)
                    }
                }
                if self.onlyWholeConversion {
                    // entropyを示す
                    let mean = mainResults.reduce(into: 0) { $0 += Double($1.value) } / Double(mainResults.count)
                    let expValues = mainResults.map { exp(Double($0.value) - mean) }
                    let sumOfExpValues = expValues.reduce(into: 0, +=)
                    // 確率値に補正
                    let probs = mainResults.map { exp(Double($0.value) - mean) / sumOfExpValues }
                    let entropy = -probs.reduce(into: 0) { $0 += $1 * log($1) }
                    print("\(bold: "Entropy:") \(entropy)")
                }
                print("\(bold: "Time:") \(-start.timeIntervalSinceNow)")
            }
        }

        func requestOptions() -> ConvertRequestOptions {
            var option: ConvertRequestOptions = .withDefaultDictionary(
                N_best: self.onlyWholeConversion ? max(self.configNBest, self.displayTopN) : self.configNBest,
                requireJapanesePrediction: !self.onlyWholeConversion && !self.disablePrediction,
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
                zenzaiMode: self.zenzWeightPath.isEmpty ? .off : .on(weight: URL(string: self.zenzWeightPath)!),
                metadata: .init(versionString: "anco for debugging")
            )
            if self.onlyWholeConversion {
                option.requestQuery = .完全一致
            }
            return option
        }
    }
}
