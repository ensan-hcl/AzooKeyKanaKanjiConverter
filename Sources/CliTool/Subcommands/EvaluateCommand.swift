import KanaKanjiConverterModuleWithDefaultDictionary
import ArgumentParser
import Foundation

extension Subcommands {
    struct Evaluate: ParsableCommand {
        @Argument(help: "query, answer, tagを備えたjsonファイルへのパス")
        var inputFile: String = ""

        @Option(name: [.customLong("output")], help: "Output file path.")
        var outputFilePath: String? = nil
        @Option(name: [.customLong("config_n_best")], help: "The parameter n (n best parameter) for internal viterbi search.")
        var configNBest: Int = 10
        @Flag(name: [.customLong("stable")], help: "Report only stable properties; timestamps and values will not be reported.")
        var stable: Bool = false
        @Option(name: [.customLong("zenz")], help: "gguf format model weight for zenz.")
        var zenzWeightPath: String = ""
        @Option(name: [.customLong("config_zenzai_inference_limit")], help: "inference limit for zenzai.")
        var configZenzaiInferenceLimit: Int = .max

        static var configuration = CommandConfiguration(commandName: "evaluate", abstract: "Evaluate quality of Conversion for input data.")

        private func parseInputFile() throws -> [InputItem] {
            let url = URL(fileURLWithPath: self.inputFile)
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([InputItem].self, from: data)
        }

        @MainActor mutating func run() throws {
            let inputItems = try parseInputFile()
            let requestOptions = requestOptions()
            let converter = KanaKanjiConverter()
            let start = Date()
            var resultItems: [EvaluateItem] = []
            for item in inputItems {
                // セットアップ
                converter.sendToDicdataStore(.importDynamicUserDict(
                    (item.user_dictionary ?? []).map {
                        DicdataElement(word: $0.word, ruby: $0.reading.toKatakana(), cid: CIDData.固有名詞.cid, mid: MIDData.一般.mid, value: -10)
                    }
                ))
                // 変換
                var composingText = ComposingText()
                composingText.insertAtCursorPosition(item.query, inputStyle: .direct)

                let result = converter.requestCandidates(composingText, options: requestOptions)
                let mainResults = result.mainResults.filter {
                    $0.data.reduce(into: "", {$0.append(contentsOf: $1.ruby)}) == item.query.toKatakana()
                }
                resultItems.append(
                    EvaluateItem(
                        query: item.query,
                        answers: item.answer,
                        outputs: mainResults.prefix(self.configNBest).map {
                            EvaluateItemOutput(text: $0.text, score: Double($0.value))
                        }
                    )
                )
                // Explictly reset state
                converter.stopComposition()
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
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let json = try encoder.encode(result)

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
                zenzaiMode: self.zenzWeightPath.isEmpty ? .off : .on(weight: URL(string: self.zenzWeightPath)!, inferenceLimit: self.configZenzaiInferenceLimit),
                metadata: .init(versionString: "anco for debugging")
            )
            option.requestQuery = .完全一致
            return option
        }
    }

    private struct InputItem: Codable {
        /// 入力クエリ
        var query: String

        /// 正解データ（優先度順）
        var answer: [String]

        /// タグ
        var tag: [String] = []

        /// ユーザ辞書
        var user_dictionary: [InputUserDictionaryItem]? = nil
    }

    private struct InputUserDictionaryItem: Codable {
        /// 漢字
        var word: String
        /// 読み
        var reading: String
        /// ヒント
        var hint: String? = nil
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
                let mean = outputs.reduce(into: 0) { $0 += Double($1.score) } / Double(outputs.count)
                let expValues = outputs.map { exp(Double($0.score) - mean) }
                let sumOfExpValues = expValues.reduce(into: 0, +=)
                // 確率値に補正
                let probs = outputs.map { exp(Double($0.score) - mean) / sumOfExpValues }
                self.entropy = -probs.reduce(into: 0) { $0 += $1 * log($1) }
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
