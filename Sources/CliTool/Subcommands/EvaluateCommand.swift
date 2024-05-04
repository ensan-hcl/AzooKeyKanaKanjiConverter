import KanaKanjiConverterModuleWithDefaultDictionary
import ArgumentParser
import Foundation

extension Subcommands {
    struct Evaluate: ParsableCommand {
        @Argument(help: "ひらがな\\t正解1\\t正解2\\t...形式のTSVファイルへのパス")
        var inputFile: String = ""

        @Option(name: [.customLong("output")], help: "Output file path.")
        var outputFilePath: String? = nil
        @Option(name: [.customLong("config_n_best")], help: "The parameter n (n best parameter) for internal viterbi search.")
        var configNBest: Int = 10
        @Flag(name: [.customLong("stable")], help: "Report only stable properties; timestamps and values will not be reported.")
        var stable: Bool = false

        static var configuration = CommandConfiguration(commandName: "evaluate", abstract: "Evaluate quality of Conversion for input data.")

        func parseInputFile() throws -> [InputItem] {
            let url = URL(fileURLWithPath: self.inputFile)
            let lines = (try String(contentsOf: url)).split(separator: "\n", omittingEmptySubsequences: false)
            return lines.enumerated().compactMap { (index, line) -> InputItem? in
                if line.isEmpty || line.hasPrefix("#") {
                    return nil
                }
                let items = line.split(separator: "\t").map(String.init)
                if items.count < 2 {
                    fatalError("Failed to parse input file of line #\(index) in \(url.absoluteString)")
                }
                return .init(query: items[0], answers: Array(items[1...]))
            }
        }

        @MainActor mutating func run() throws {
            let inputItems = try parseInputFile()

            let converter = KanaKanjiConverter()
            let start = Date()
            var resultItems: [EvaluateItem] = []
            for item in inputItems {
                var composingText = ComposingText()
                composingText.insertAtCursorPosition(item.query, inputStyle: .direct)
                let result = converter.requestCandidates(composingText, options: requestOptions())
                let mainResults = result.mainResults.filter {
                    $0.data.reduce(into: "", {$0.append(contentsOf: $1.ruby)}) == item.query.toKatakana()
                }
                resultItems.append(
                    EvaluateItem(
                        query: item.query,
                        answers: item.answers,
                        outputs: mainResults.prefix(self.configNBest).map {
                            EvaluateItemOutput(text: $0.text, score: Double($0.value))
                        }
                    )
                )
            }
            let end = Date()
            var result = EvaluateResult(n_best: self.configNBest, execution_time: end.timeIntervalSince(start), items: resultItems)
            if stable {
                result.execution_time = 0
                result.timestamp = 0
                result.items.mutatingForeach {
                    $0.entropy = Double(Int($0.entropy * 10)) / 10
                    $0.outputs.mutatingForeach {
                        $0.score = Double(Int($0.score))
                    }
                }
            }
            let json = try JSONEncoder().encode(result)

            if let outputFilePath {
                try json.write(to: URL(fileURLWithPath: outputFilePath))
            } else {
                let string = String(data: json, encoding: .utf8)!
                print(string)
            }
        }

        func requestOptions() -> ConvertRequestOptions {
            var option: ConvertRequestOptions = .withDefaultDictionary(
                N_best: self.configNBest,
                requireJapanesePrediction: false,
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
                metadata: .init(versionString: "anco for debugging")
            )
            option.requestQuery = .完全一致
            return option
        }
    }

    struct InputItem {
        /// 入力クエリ
        var query: String

        /// 正解データ（優先度順）
        var answers: [String]
    }

    struct EvaluateResult: Codable {
        internal init(n_best: Int, timestamp: TimeInterval = Date().timeIntervalSince1970, execution_time: TimeInterval, items: [Subcommands.EvaluateItem]) {
            self.n_best = n_best
            self.timestamp = timestamp
            self.execution_time = execution_time
            self.items = items

            var stat = EvaluateStat(query_count: items.count, ranks: [:])
            for item in items {
                stat.ranks[item.max_rank, default: 0] += 1
            }
            self.stat = stat
        }
        
        /// `N_Best`クエリ
        var n_best: Int

        /// タイムスタンプ
        var timestamp = Date().timeIntervalSince1970

        /// タイムスタンプ
        var execution_time: TimeInterval

        /// 統計情報
        var stat: EvaluateStat

        /// クエリと結果
        var items: [EvaluateItem]
    }

    struct EvaluateStat: Codable {
        var query_count: Int
        var ranks: [Int: Int]
    }

    struct EvaluateItem: Codable {
        init(query: String, answers: [String], outputs: [Subcommands.EvaluateItemOutput]) {
            self.query = query
            self.answers = answers
            self.outputs = outputs
            do {
                // entropyを示す
                let expValues = outputs.map { exp(Double($0.score)) }
                let sumOfExpValues = expValues.reduce(into: 0, +=)
                // 確率値に補正
                let probs = expValues.map { $0 / sumOfExpValues }
                let entropy = -probs.reduce(into: 0) { $0 += $1 * log($1) }
                self.entropy = entropy
            }
            do {
                self.max_rank = outputs.firstIndex {
                    answers.contains($0.text)
                } ?? -1
            }
        }
        
        /// 入力クエリ
        var query: String

        /// 正解データ（順序無し）
        var answers: [String]

        /// 出力
        var outputs: [EvaluateItemOutput]

        /// エントロピー
        var entropy: Double

        /// 正解と判定出来たものの最高の順位（-1は見つからなかったことを示す）
        var max_rank: Int
    }

    struct EvaluateItemOutput: Codable {
        var text: String
        var score: Double
    }
}
