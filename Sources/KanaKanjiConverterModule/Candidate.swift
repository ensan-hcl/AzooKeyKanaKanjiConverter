//
//  Candidate.swift
//  Keyboard
//
//  Created by ensan on 2020/10/26.
//  Copyright © 2020 ensan. All rights reserved.
//

import Foundation

/// Data of clause.
final class ClauseDataUnit {
    /// The MID of the clause.
    var mid: Int = MIDData.EOS.mid
    /// The LCID in the next clause.
    var nextLcid = CIDData.EOS.cid
    /// The text of the unit.
    var text: String = ""
    /// The range of the unit in input text.
    var inputRange: Range<Int> = 0 ..< 0

    /// Merge the given unit to this unit.
    /// - Parameter:
    ///   - unit: The unit to merge.
    func merge(with unit: ClauseDataUnit) {
        self.text.append(unit.text)
        self.inputRange = self.inputRange.startIndex ..< unit.inputRange.endIndex
        self.nextLcid = unit.nextLcid
    }
}

extension ClauseDataUnit: Equatable {
    static func == (lhs: ClauseDataUnit, rhs: ClauseDataUnit) -> Bool {
        lhs.mid == rhs.mid && lhs.nextLcid == rhs.nextLcid && lhs.text == rhs.text && lhs.inputRange == rhs.inputRange
    }
}

#if DEBUG
extension ClauseDataUnit: CustomDebugStringConvertible {
    var debugDescription: String {
        "ClauseDataUnit(mid: \(mid), nextLcid: \(nextLcid), text: \(text), inputRange: \(inputRange))"
    }
}
#endif

struct CandidateData {
    typealias ClausesUnit = (clause: ClauseDataUnit, value: PValue)
    var clauses: [ClausesUnit]
    var data: [DicdataElement]

    init(clauses: [ClausesUnit], data: [DicdataElement]) {
        self.clauses = clauses
        self.data = data
    }

    var lastClause: ClauseDataUnit? {
        self.clauses.last?.clause
    }

    var isEmpty: Bool {
        clauses.isEmpty
    }
}

public enum CompleteAction: Equatable, Sendable {
    /// カーソルを調整する
    case moveCursor(Int)
}

/// 変換候補のデータ
public struct Candidate: Sendable {
    /// 入力となるテキスト
    public var text: String
    /// 評価値
    public let value: PValue
    /// composingText.inputにおいて対応する文字数。
    public var correspondingCount: Int
    /// 最後のmid(予測変換に利用)
    public let lastMid: Int
    /// DicdataElement列
    public let data: [DicdataElement]
    /// 変換として選択した際に実行する`action`。
    /// - note: 括弧を入力した際にカーソルを移動するために追加した変数
    public var actions: [CompleteAction]
    /// 入力できるものか
    /// - note: 文字数表示のために追加したフラグ
    public let inputable: Bool

    public init(text: String, value: PValue, correspondingCount: Int, lastMid: Int, data: [DicdataElement], actions: [CompleteAction] = [], inputable: Bool = true) {
        self.text = text
        self.value = value
        self.correspondingCount = correspondingCount
        self.lastMid = lastMid
        self.data = data
        self.actions = actions
        self.inputable = inputable
    }
    /// 後から`action`を追加した形を生成する関数
    /// - parameters:
    ///  - actions: 実行する`action`
    @inlinable public mutating func withActions(_ actions: [CompleteAction]) {
        self.actions = actions
    }

    private static let dateExpression = "<date format=\".*?\" type=\".*?\" language=\".*?\" delta=\".*?\" deltaunit=\".*?\">"
    private static let randomExpression = "<random type=\".*?\" value=\".*?\">"

    /// テンプレートをパースして、変換候補のテキストを生成する。
    public static func parseTemplate(_ text: consuming String) -> String {
        var newText = consume text
        while let range = newText.range(of: Self.dateExpression, options: .regularExpression) {
            let templateString = String(newText[range])
            let template = DateTemplateLiteral.import(from: templateString)
            let value = template.previewString()
            newText.replaceSubrange(range, with: value)
        }
        while let range = newText.range(of: Self.randomExpression, options: .regularExpression) {
            let templateString = String(newText[range])
            let template = RandomTemplateLiteral.import(from: templateString)
            let value = template.previewString()
            newText.replaceSubrange(range, with: value)
        }
        return newText
    }

    /// テンプレートをパースして、変換候補のテキストを生成し、反映する。
    @inlinable public mutating func parseTemplate() {
        // ここでCandidate.textとdata.map(\.word).join("")の整合性が壊れることに注意
        // ただし、dataの方を加工するのは望ましい挙動ではない。
        self.text = Self.parseTemplate(text)
    }

    /// 入力を文としたとき、prefixになる文節に対応するCandidateを作る
    public static func makePrefixClauseCandidate(data: some Collection<DicdataElement>) -> Candidate {
        var text = ""
        var correspondingCount = 0
        var lastRcid = CIDData.BOS.cid
        var lastMid = 501
        var candidateData: [DicdataElement] = []
        for item in data {
            // 文節だったら
            if DicdataStore.isClause(lastRcid, item.lcid) {
                break
            }
            text.append(item.word)
            correspondingCount += item.ruby.count
            lastRcid = item.rcid
            // 最初だった場合を想定している
            if item.mid != 500 && DicdataStore.includeMMValueCalculation(item) {
                lastMid = item.mid
            }
            candidateData.append(item)
        }
        return Candidate(
            text: text,
            value: -5,
            correspondingCount: correspondingCount,
            lastMid: lastMid,
            data: candidateData
        )
    }

}
