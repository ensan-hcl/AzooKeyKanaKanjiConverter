import Foundation
import SwiftUtils

extension Kana2Kanji {
    struct ZenzaiCache: Sendable {
        init(_ inputData: ComposingText, constraint: String, satisfyingCandidate: Candidate?) {
            self.inputData = inputData
            self.prefixConstraint = constraint
            self.satisfyingCandidate = satisfyingCandidate
        }
        
        private var prefixConstraint: String
        private var satisfyingCandidate: Candidate?
        private var inputData: ComposingText

        func getNewConstraint(for newInputData: ComposingText) -> String {
            if let satisfyingCandidate {
                var current = newInputData.convertTarget.toKatakana()[...]
                var constraint = ""
                for item in satisfyingCandidate.data {
                    if current.hasPrefix(item.ruby) {
                        constraint += item.word
                        current = current.dropFirst(item.ruby.count)
                    }
                }
                return constraint
            } else if newInputData.convertTarget.hasPrefix(inputData.convertTarget) {
                return self.prefixConstraint
            } else {
                return ""
            }
        }
    }

    /// zenzaiシステムによる完全変換。
    @MainActor func all_zenzai(_ inputData: ComposingText, zenz: Zenz, zenzaiCache: ZenzaiCache?) -> (result: LatticeNode, nodes: Nodes, cache: ZenzaiCache) {
        var constraint = zenzaiCache?.getNewConstraint(for: inputData) ?? ""
        print("initial constraint", constraint)
        let eosNode = LatticeNode.EOSNode
        var nodes: Kana2Kanji.Nodes = []
        while true {
            // 実験の結果、ここは2-bestを取ると平均的な速度が最良になることがわかったので、そうしている。
            let draftResult = self.kana2lattice_all_with_prefix_constraint(inputData, N_best: 2, constraint: constraint)
            if nodes.isEmpty {
                // 初回のみ
                nodes = draftResult.nodes
            }
            let candidates = draftResult.result.getCandidateData().map(self.processClauseCandidate)
            var best: (Int, Candidate)? = nil
            for (i, cand) in candidates.enumerated() {
                if let (_, c) = best, cand.value > c.value {
                    best = (i, cand)
                } else if best == nil {
                    best = (i, cand)
                }
            }
            guard let (index, candidate) = best else {
                print("best was not found!")
                // Emptyの場合
                // 制約が満たせない場合は無視する
                return (eosNode, nodes, ZenzaiCache(inputData, constraint: "", satisfyingCandidate: nil))
            }
            // resultsを更新
            eosNode.prevs.insert(draftResult.result.prevs[index], at: 0)
            let reviewResult = zenz.candidateEvaluate(convertTarget: inputData.convertTarget, candidates: [candidate])
            switch reviewResult {
            case .error:
                // 何らかのエラーが発生
                print("error")
                return (eosNode, nodes, ZenzaiCache(inputData, constraint: constraint, satisfyingCandidate: nil))
            case .pass(let score):
                // 合格
                print("passed:", score)
                return (eosNode, nodes, ZenzaiCache(inputData, constraint: constraint, satisfyingCandidate: candidate))
            case .fixRequired(let prefixConstraint):
                // 同じ制約が2回連続で出てきたら諦める
                if constraint == prefixConstraint {
                    print("same constraint:", prefixConstraint)
                    return (eosNode, nodes, ZenzaiCache(inputData, constraint: "", satisfyingCandidate: nil))
                }
                // TODO: もし制約を満たす候補があるならそれを使って再レビューチャレンジを戦うことで、推論を減らせそう
                // 制約が得られたので、更新する
                print("update constraint:", prefixConstraint)
                constraint = prefixConstraint
            }
        }
    }
}
