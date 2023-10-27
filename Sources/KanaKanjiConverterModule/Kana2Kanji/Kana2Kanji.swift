//
//  kana2kanji.swift
//  Kana2KajiProject
//
//  Created by ensan on 2020/09/02.
//  Copyright © 2020 ensan. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS)
public typealias PValue = Float16
#else
public typealias PValue = Float32
#endif

struct Kana2Kanji {
    var dicdataStore = DicdataStore()

    /// CandidateDataの状態からCandidateに変更する関数
    /// - parameters:
    ///   - data: CandidateData
    /// - returns:
    ///    Candidateとなった値を返す。
    /// - note:
    ///     この関数の役割は意味連接の考慮にある。
    func processClauseCandidate(_ data: CandidateData) async -> Candidate {
        let mmValue = await self.dicdataStore.getMMInfoSum(clauses: data.clauses)
        let text = data.clauses.map {$0.clause.text}.joined()
        let value = data.clauses.last!.value + mmValue.value
        let lastMid = data.clauses.last!.clause.mid
        let correspondingCount = data.clauses.reduce(into: 0) {$0 += $1.clause.inputRange.count}
        return Candidate(
            text: text,
            value: value,
            correspondingCount: correspondingCount,
            lastMid: lastMid,
            data: data.data
        )
    }

    func processCandidateData(_ clauseResult: [CandidateData]) async -> [(CandidateData, Candidate)] {
        var result = [(CandidateData, Candidate)]()
        for data in clauseResult {
            result.append((data, await self.processClauseCandidate(data)))
        }
        return result
    }
}

private extension DicdataStore {
    func getMMInfoSum(clauses: [CandidateData.ClausesUnit]) -> (value: PValue, mid: Int) {
        clauses.reduce((value: .zero, mid: MIDData.EOS.mid)) { result, data in
            (
                value: result.value + self.getMMValue(result.mid, data.clause.mid),
                mid: data.clause.mid
            )
        }
    }
}
