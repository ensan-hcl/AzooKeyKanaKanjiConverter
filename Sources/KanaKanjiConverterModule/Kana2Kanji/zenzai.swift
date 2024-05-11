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
            let (del, add) = newInputData.differenceSuffix(to: self.inputData)
            if del == 0 {
                return self.prefixConstraint
            } else {
                if let satisfyingCandidate {
                    var current = newInputData.convertTarget[...]
                    var constraint = ""
                    for item in satisfyingCandidate.data {
                        if current.hasPrefix(item.ruby) {
                            constraint += item.ruby
                            current = current.dropFirst(item.ruby.count)
                        }
                    }
                    return constraint
                } else {
                    return ""
                }
            }
        }
    }

    /// zenzaiシステムによる完全変換。
    @MainActor func all_zenzai(_ inputData: ComposingText, zenz: Zenz, zenzaiCache: ZenzaiCache?) -> (result: LatticeNode, nodes: Nodes, cache: ZenzaiCache) {
        var constraint = zenzaiCache?.getNewConstraint(for: inputData) ?? ""
        let eosNode = LatticeNode.EOSNode
        var nodes: Kana2Kanji.Nodes = []
        while true {
            let draftResult = self.kana2lattice_all_with_prefix_constraint(inputData, N_best: 1, constraint: constraint)
            if nodes.isEmpty {
                // 初回のみ
                nodes = draftResult.nodes
            }
            let clauseResult = draftResult.result.getCandidateData()
            let sums: [Candidate] = clauseResult.map {self.processClauseCandidate($0)}
            if sums.isEmpty {
                print("sums was empty!")
                // Emptyの場合
                return (eosNode, nodes, ZenzaiCache(inputData, constraint: constraint, satisfyingCandidate: nil))
            }
            // resultsを更新
            eosNode.prevs.insert(draftResult.result.prevs[0], at: 0)
            let reviewResult = zenz.candidateEvaluate(candidates: sums)
            switch reviewResult {
            case .error:
                // 何らかのエラーが発生
                print("error")
                return (eosNode, nodes, ZenzaiCache(inputData, constraint: constraint, satisfyingCandidate: nil))
            case .pass(let score):
                // 合格
                print("passed:", score)
                return (eosNode, nodes, ZenzaiCache(inputData, constraint: constraint, satisfyingCandidate: sums[0]))
            case .fixRequired(let prefixConstraint):
                // 同じ制約が2回連続で出てきたら諦める
                if constraint == prefixConstraint {
                    print("same constraint:", prefixConstraint)
                    return (eosNode, nodes, ZenzaiCache(inputData, constraint: constraint, satisfyingCandidate: nil))
                }
                // 制約が得られたので、更新する
                print("update constraint:", prefixConstraint)
                constraint = prefixConstraint
            }
        }
    }
}
