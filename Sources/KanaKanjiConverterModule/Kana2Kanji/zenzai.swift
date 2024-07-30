import Foundation
import SwiftUtils

extension Kana2Kanji {
    struct ZenzaiCache: Sendable {
        init(_ inputData: ComposingText, constraint: PrefixConstraint, satisfyingCandidate: Candidate?) {
            self.inputData = inputData
            self.prefixConstraint = constraint
            self.satisfyingCandidate = satisfyingCandidate
        }
        
        private var prefixConstraint: PrefixConstraint
        private var satisfyingCandidate: Candidate?
        private var inputData: ComposingText

        func getNewConstraint(for newInputData: ComposingText) -> PrefixConstraint {
            if let satisfyingCandidate {
                var current = newInputData.convertTarget.toKatakana()[...]
                var constraint = [UInt8]()
                for item in satisfyingCandidate.data {
                    if current.hasPrefix(item.ruby) {
                        constraint += item.word.utf8
                        current = current.dropFirst(item.ruby.count)
                    }
                }
                return PrefixConstraint(constraint)
            } else if newInputData.convertTarget.hasPrefix(inputData.convertTarget) {
                return self.prefixConstraint
            } else {
                return PrefixConstraint([])
            }
        }
    }

    struct PrefixConstraint: Sendable, Equatable, Hashable, CustomStringConvertible {
        init(_ constraint: [UInt8], hasEOS: Bool = false) {
            self.constraint = constraint
            self.hasEOS = hasEOS
        }
        
        var constraint: [UInt8]
        var hasEOS: Bool

        var description: String {
            "PrefixConstraint(constraint: \"\(String(cString: self.constraint + [0]))\", hasEOS: \(self.hasEOS))"
        }
    }

    /// zenzaiシステムによる完全変換。
    @MainActor func all_zenzai(
        _ inputData: ComposingText,
        zenz: Zenz,
        zenzaiCache: ZenzaiCache?,
        inferenceLimit: Int,
        versionDependentConfig: ConvertRequestOptions.ZenzaiVersionDependentMode
    ) -> (result: LatticeNode, nodes: Nodes, cache: ZenzaiCache) {
        var constraint = zenzaiCache?.getNewConstraint(for: inputData) ?? PrefixConstraint([])
        print("initial constraint", constraint)
        let eosNode = LatticeNode.EOSNode
        var nodes: Kana2Kanji.Nodes = []
        var inferenceLimit = inferenceLimit
        while true {
            // 実験の結果、ここは2-bestを取ると平均的な速度が最良になることがわかったので、そうしている。
            let start = Date()
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
            guard var (index, candidate) = best else {
                print("best was not found!")
                // Emptyの場合
                // 制約が満たせない場合は無視する
                return (eosNode, nodes, ZenzaiCache(inputData, constraint: PrefixConstraint([]), satisfyingCandidate: nil))
            }
            print("Constrained draft modeling", -start.timeIntervalSinceNow)
            reviewLoop: while true {
                // resultsを更新
                eosNode.prevs.insert(draftResult.result.prevs[index], at: 0)
                if inferenceLimit == 0 {
                    print("inference limit! \(candidate.text) is used for excuse")
                    // When inference occurs more than maximum times, then just return result at this point
                    return (eosNode, nodes, ZenzaiCache(inputData, constraint: constraint, satisfyingCandidate: candidate))
                }
                let reviewResult = zenz.candidateEvaluate(convertTarget: inputData.convertTarget, candidates: [candidate], versionDependentConfig: versionDependentConfig)
                inferenceLimit -= 1
                let nextAction = self.review(
                    candidateIndex: index,
                    candidates: candidates,
                    reviewResult: reviewResult,
                    constraint: &constraint
                )
                switch nextAction {
                case .return(let constraint, let satisfied):
                    if satisfied {
                        return (eosNode, nodes, ZenzaiCache(inputData, constraint: constraint, satisfyingCandidate: candidate))
                    } else {
                        return (eosNode, nodes, ZenzaiCache(inputData, constraint: constraint, satisfyingCandidate: nil))
                    }
                case .continue:
                    break reviewLoop
                case .retry(let candidateIndex):
                    index = candidateIndex
                    candidate = candidates[candidateIndex]
                }
            }
        }
    }

    private enum NextAction {
        case `return`(constraint: PrefixConstraint, satisfied: Bool)
        case `continue`
        case `retry`(candidateIndex: Int)
    }

    private func review(
        candidateIndex: Int,
        candidates: [Candidate],
        reviewResult: consuming ZenzContext.CandidateEvaluationResult,
        constraint: inout PrefixConstraint
    ) -> NextAction {
        switch reviewResult {
        case .error:
            // 何らかのエラーが発生
            print("error")
            return .return(constraint: constraint, satisfied: false)
        case .pass(let score):
            // 合格
            print("passed:", score)
            return .return(constraint: constraint, satisfied: true)
        case .fixRequired(let prefixConstraint):
            // 同じ制約が2回連続で出てきたら諦める
            if constraint.constraint == prefixConstraint {
                print("same constraint:", prefixConstraint)
                return .return(constraint: PrefixConstraint([]), satisfied: false)
            }
            // 制約が得られたので、更新する
            constraint = PrefixConstraint(prefixConstraint)
            print("update constraint:", constraint)
            // もし制約を満たす候補があるならそれを使って再レビューチャレンジを戦うことで、推論を減らせる
            for i in candidates.indices where i != candidateIndex {
                if candidates[i].text.utf8.hasPrefix(prefixConstraint) {
                    print("found \(candidates[i].text) as another retry")
                    return .retry(candidateIndex: i)
                }
            }
            return .continue
        case .wholeResult(let wholeConstraint):
            let newConstraint = PrefixConstraint(Array(wholeConstraint.utf8), hasEOS: true)
            // 同じ制約が2回連続で出てきたら諦める
            if constraint == newConstraint {
                print("same constraint:", constraint)
                return .return(constraint: PrefixConstraint([]), satisfied: false)
            }
            // 制約が得られたので、更新する
            print("update whole constraint:", wholeConstraint)
            constraint = PrefixConstraint(Array(wholeConstraint.utf8), hasEOS: true)
            // もし制約を満たす候補があるならそれを使って再レビューチャレンジを戦うことで、推論を減らせる
            for i in candidates.indices where i != candidateIndex {
                if candidates[i].text == wholeConstraint {
                    print("found \(candidates[i].text) as another retry")
                    return .retry(candidateIndex: i)
                }
            }
            return .continue
        }
    }
}
