//
//  PredictionCandidate.swift
//
//
//  Created by miwa on 2023/09/19.
//

import Foundation

public enum PredictionCandidate: Sendable, Hashable {
    case additional(AdditionalPredictionCandidate)
    case replacement(ReplacementPredictionCandidate)
    
    public struct AdditionalPredictionCandidate: Sendable, Hashable {
        public var text: String
        public var data: [DicdataElement]
        public var value: PValue
    }
    public struct ReplacementPredictionCandidate: Sendable, Hashable {
        /// 予測変換として表示するデータ
        public var text: String
        /// 置換対象のデータ
        public var targetData: [DicdataElement]
        /// 置換後のデータ
        public var replacementData: [DicdataElement]
        /// 重み
        public var value: PValue
    }

    public var value: PValue {
        switch self {
        case .additional(let c):
            c.value
        case .replacement(let c):
            c.value
        }
    }
    
    public var text: String {
        switch self {
        case .additional(let c):
            c.text
        case .replacement(let c):
            c.text
        }
    }

    public func join(to candidate: consuming Candidate) -> Candidate {
        switch self {
        case .additional(let c):
            for data in c.data {
                candidate.text.append(contentsOf: data.word)
                candidate.data.append(data)
            }
            candidate.value = c.value
            candidate.correspondingCount = candidate.data.reduce(into: 0) { $0 += $1.ruby.count }
            candidate.lastMid = c.data.last(where: DicdataStore.includeMMValueCalculation)?.mid ?? candidate.lastMid
            return candidate
        case .replacement(let c):
            candidate.data.removeLast(c.targetData.count)
            candidate.data.append(contentsOf: c.replacementData)
            candidate.text = candidate.data.reduce(into: "") {$0 += $1.word}
            candidate.value = c.value
            candidate.lastMid = candidate.data.last(where: DicdataStore.includeMMValueCalculation)?.mid ?? MIDData.BOS.mid
            candidate.correspondingCount = candidate.data.reduce(into: 0) { $0 += $1.ruby.count }
            return candidate
        }
    }
}
