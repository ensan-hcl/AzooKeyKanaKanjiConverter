//
//  ConvertGraph.swift
//
//
//  Created by miwa on 2024/02/23.
//

import XCTest
import Foundation
@testable import KanaKanjiConverterModule

struct ConvertGraph {
    struct Node {
        var value: Character
        var latticeNodes: [LatticeNode]
        var inputElementsRange: InputGraphRange
        var correction: CorrectGraph.Correction = .none
    }

    var nodes: [Node] = [
        // root node
        Node(value: "\0", latticeNodes: [], inputElementsRange: .endIndex(0))
    ]

    /// 許可されたNextIndex
    var allowedNextIndex: [Int: IndexSet] = [:]
    /// 許可されたprevIndex
    var allowedPrevIndex: [Int: IndexSet] = [:]

    init(input: LookupGraph, nodeIndex2LatticeNode: [Int: [LatticeNode]]) {
        let nodes = input.nodes.enumerated().map { (index, node) in
            Node(
                value: node.character,
                latticeNodes: nodeIndex2LatticeNode[index, default: []],
                inputElementsRange: node.inputElementsRange,
                correction: node.correction
            )
        }
        self.nodes = nodes
        self.allowedPrevIndex = input.allowedPrevIndex
        self.allowedNextIndex = input.allowedNextIndex
    }
}

extension ConvertGraph {
    /// ラティスのノード。これを用いて計算する。
    final class LatticeNode: CustomStringConvertible {
        /// このノードが保持する辞書データ
        public let data: DicdataElement
        /// このDicdataElementを作った際、終端に対応したConvertGraphのノードのindex
        var endNodeIndex: Int
        /// このノードの前に来ているノード。`N_best`の分だけ保存する
        var prevs: [RegisteredNode] = []
        /// `prevs`の各要素に対応するスコアのデータ
        var values: [PValue] = []
        var inputElementsRange: InputGraphRange

        /// `EOS`に対応するノード。
        static var EOSNode: LatticeNode {
            LatticeNode(data: DicdataElement.EOSData, endNodeIndex: 0, inputElementsRange: .unknown)
        }

        init(data: DicdataElement, endNodeIndex: Int, inputElementsRange: InputGraphRange, prevs: [RegisteredNode] = []) {
            self.data = data
            self.values = []
            self.endNodeIndex = endNodeIndex
            self.inputElementsRange = inputElementsRange
            self.prevs = prevs
        }

        /// `LatticeNode`の持っている情報を反映した`RegisteredNode`を作成する
        /// `LatticeNode`は複数の過去のノードを持つことができるが、`RegisteredNode`は1つしか持たない。
        func getRegisteredNode(_ index: Int, value: PValue) -> RegisteredNode {
            // FIXME: 適当に実装した
            RegisteredNode(
                data: self.data,
                registered: self.prevs[index],
                totalValue: value,
                inputElementsRange: self.inputElementsRange
            )
        }

        var description: String {
            "LatticeNode(data: \(data), ...)"
        }
    }
    struct RegisteredNode: RegisteredNodeProtocol {
        /// このノードが保持する辞書データ
        let data: DicdataElement
        /// 1つ前のノードのデータ
        let prev: (any RegisteredNodeProtocol)?
        /// 始点からこのノードまでのコスト
        let totalValue: PValue
        /// inputData.input内のrange
        var inputElementsRange: InputGraphRange

        init(data: DicdataElement, registered: RegisteredNode?, totalValue: PValue, inputElementsRange: InputGraphRange) {
            self.data = data
            self.prev = registered
            self.totalValue = totalValue
            self.inputElementsRange = inputElementsRange
        }

        /// 始点ノードを生成する関数
        /// - Returns: 始点ノードのデータ
        static func BOSNode() -> RegisteredNode {
            RegisteredNode(data: DicdataElement.BOSData, registered: nil, totalValue: 0, inputElementsRange: .endIndex(0))
        }
    }

}

/// `struct`の`RegisteredNode`を再帰的に所持できるようにするため、Existential Typeで抽象化する。
/// - Note: `indirect enum`との比較はまだやっていない。
protocol RegisteredNodeProtocol {
    var data: DicdataElement {get}
    var prev: (any RegisteredNodeProtocol)? {get}
    var totalValue: PValue {get}
    var inputElementsRange: InputGraphRange {get}
}

extension ConvertGraph {
    func convertAll(option: borrowing ConvertRequestOptions, dicdataStore: DicdataStore) -> LatticeNode {
        let result: LatticeNode = LatticeNode.EOSNode
        result.inputElementsRange = .init(startIndex: self.nodes.compactMap {$0.inputElementsRange.endIndex}.max(), endIndex: nil)
        var processStack = Array(self.nodes.enumerated().reversed())
        var processedIndices: IndexSet = [0] // root
        var invalidIndices: IndexSet = []
        while let (i, graphNode) = processStack.popLast() {
            // 処理済みなら無視する
            guard !processedIndices.contains(i), !invalidIndices.contains(i) else {
                continue
            }
            // 全てのprevNodeが処理済みか確かめる
            let prevIndices = self.allowedPrevIndex[i, default: []]
            guard !prevIndices.isEmpty else {
                // 空の場合は無視して次へ
                invalidIndices.insert(i)
                continue
            }

            var unprocessedPrevs: [(Int, Node)] = []
            for prevIndex in prevIndices {
                if !processedIndices.contains(prevIndex) && !invalidIndices.contains(prevIndex) {
                    unprocessedPrevs.append((prevIndex, self.nodes[prevIndex]))
                }
            }
            // 未処理のprevNodeがある場合、それらをstackの末尾に追加してもう一度やり直す
            guard unprocessedPrevs.isEmpty else {
                processStack.append((i, graphNode))
                processStack.append(contentsOf: unprocessedPrevs)
                continue
            }
            print(i, graphNode.inputElementsRange)
            processedIndices.insert(i)
            // 処理を実施する
            for node in graphNode.latticeNodes {
                if node.prevs.isEmpty {
                    continue
                }
                if dicdataStore.shouldBeRemoved(data: node.data) {
                    continue
                }
                // 生起確率を取得する。
                let wValue: PValue = node.data.value()
                if i == 0 {
                    // valuesを更新する
                    node.values = node.prevs.map {$0.totalValue + wValue + dicdataStore.getCCValue($0.data.rcid, node.data.lcid)}
                } else {
                    // valuesを更新する
                    node.values = node.prevs.map {$0.totalValue + wValue}
                }
                // 終端の場合は終了
                if self.allowedNextIndex[node.endNodeIndex, default: []].isEmpty || result.inputElementsRange.startIndex == node.inputElementsRange.endIndex {
                    for index in node.prevs.indices {
                        let newnode: RegisteredNode = node.getRegisteredNode(index, value: node.values[index])
                        result.prevs.append(newnode)
                    }
                } else {
                    for nextIndex in self.allowedNextIndex[node.endNodeIndex, default: []] {
                        // nodeの繋がる次にあり得る全てのnextnodeに対して
                        for nextnode in self.nodes[nextIndex].latticeNodes {
                            // この関数はこの時点で呼び出して、後のnode.registered.isEmptyで最終的に弾くのが良い。
                            if dicdataStore.shouldBeRemoved(data: nextnode.data) {
                                continue
                            }
                            // クラスの連続確率を計算する。
                            let ccValue: PValue = dicdataStore.getCCValue(node.data.rcid, nextnode.data.lcid)
                            // nodeの持っている全てのprevnodeに対して
                            for (index, value) in node.values.enumerated() {
                                let newValue: PValue = ccValue + value
                                // 追加すべきindexを取得する
                                let lastindex: Int = (nextnode.prevs.lastIndex(where: {$0.totalValue >= newValue}) ?? -1) + 1
                                if lastindex == option.N_best {
                                    continue
                                }
                                let newnode: RegisteredNode = node.getRegisteredNode(index, value: newValue)
                                // カウントがオーバーしている場合は除去する
                                if nextnode.prevs.count >= option.N_best {
                                    nextnode.prevs.removeLast()
                                }
                                // removeしてからinsertした方が速い (insertはO(N)なので)
                                nextnode.prevs.insert(newnode, at: lastindex)
                            }
                        }
                    }
                }
            }
        }
        return result
    }

    mutating func convertAllDifferential(cacheConvertGraph: ConvertGraph, option: borrowing ConvertRequestOptions, dicdataStore: DicdataStore, lookupGraphMatchInfo: [Int: Int]) -> LatticeNode {
        print(lookupGraphMatchInfo)
        // 最初にマッチチェックをする
        typealias MatchSearchItem = (
            curNodeIndex: Int,
            cacheNodeIndex: Int
        )
        // BOSはマッチする
        var stack: [MatchSearchItem] = [(0, 0)]
        var curNodeToCacheNode: [Int: Int] = [:]
        do {
            var processedIndices: IndexSet = []

            while let item = stack.popLast() {
                if processedIndices.contains(item.curNodeIndex) {
                    continue
                }
                let prevIndices = self.allowedPrevIndex[item.curNodeIndex, default: []]
                if prevIndices.allSatisfy(processedIndices.contains) {
                    if prevIndices.allSatisfy(curNodeToCacheNode.keys.contains) {
                        // マッチする
                        curNodeToCacheNode[item.curNodeIndex] = item.cacheNodeIndex
                        // 子ノードを足す
                        for nextNodeIndex in self.allowedNextIndex[item.curNodeIndex, default: []] {
                            let nextNode = self.nodes[nextNodeIndex]
                            if let cacheNodeIndex = cacheConvertGraph.allowedNextIndex[item.cacheNodeIndex, default: []].first(where: {
                                cacheConvertGraph.nodes[$0].value == nextNode.value
                            }) {
                                stack.append((nextNodeIndex, cacheNodeIndex))
                            }
                        }
                    } else {
                        // マッチしない
                        // この場合、このノードのnextNodeはどの道マッチしないので、探索済みとしても問題ない
                        processedIndices.formUnion(self.allowedNextIndex[item.curNodeIndex, default: []])
                    }
                    // 処理済み
                    processedIndices.insert(item.curNodeIndex)
                } else {
                    // prevNodeの直前に移動する
                    let restIndices = prevIndices.subtracting(IndexSet(processedIndices))
                    let firstIndex = stack.firstIndex(where: { restIndices.contains($0.curNodeIndex) }) ?? 0
                    stack.insert(item, at: firstIndex)
                }
            }
        }
        let lookupGraphCacheNodeToCurNode = Dictionary(lookupGraphMatchInfo.map {(k, v)  in (v, k)}, uniquingKeysWith: { (k1, _) in k1 })
        struct HashablePair<T1: Hashable, T2: Hashable>: Hashable {
            init(_ first: T1, _ second: T2) {
                self.first = first
                self.second = second
            }
            var first: T1
            var second: T2
        }
        // 得たマッチ情報を使ってselfを部分的に構築する
        print("curNodeToCacheNode", curNodeToCacheNode)
        for (curNodeIndex, cacheNodeIndex) in curNodeToCacheNode {
            self.nodes[curNodeIndex].latticeNodes.removeAll {
                lookupGraphMatchInfo.keys.contains($0.endNodeIndex)
            }
            cacheConvertGraph.nodes[cacheNodeIndex].latticeNodes.forEach {
                if let e = lookupGraphCacheNodeToCurNode[$0.endNodeIndex] {
                    $0.endNodeIndex = e
                    self.nodes[curNodeIndex].latticeNodes.append($0)
                }
            }
        }

        // 構築していない部分を触る
        let result: LatticeNode = LatticeNode.EOSNode
        result.inputElementsRange = .init(startIndex: self.nodes.compactMap {$0.inputElementsRange.endIndex}.max(), endIndex: nil)
        var processStack = Array(self.nodes.enumerated().reversed())
        var processedIndices: IndexSet = [0] // root
        var invalidIndices: IndexSet = []
        while let (i, graphNode) = processStack.popLast() {
            // 処理済みなら無視する
            guard !processedIndices.contains(i), !invalidIndices.contains(i) else {
                continue
            }
            // 全てのprevNodeが処理済みか確かめる
            let prevIndices = self.allowedPrevIndex[i, default: []]
            guard !prevIndices.isEmpty else {
                // 空の場合は無視して次へ
                invalidIndices.insert(i)
                continue
            }

            var unprocessedPrevs: Set<Int> = []
            for prevIndex in prevIndices {
                if !processedIndices.contains(prevIndex) && !invalidIndices.contains(prevIndex) {
                    unprocessedPrevs.insert(prevIndex)
                }
            }
            // 未処理のprevNodeがある場合、それらをstackの末尾に追加してもう一度やり直す
            guard unprocessedPrevs.isEmpty else {
                // prevNodeの直前に移動する
                let firstIndex = processStack.firstIndex(where: { unprocessedPrevs.contains($0.offset) }) ?? 0
                processStack.insert((i, graphNode), at: firstIndex)
                continue
            }
            print(i, graphNode.inputElementsRange)
            processedIndices.insert(i)
            let isMatchedGraphNode = curNodeToCacheNode.keys.contains(i)
            // 処理を実施する
            for node in graphNode.latticeNodes {
                if node.prevs.isEmpty {
                    continue
                }
                if dicdataStore.shouldBeRemoved(data: node.data) {
                    continue
                }
                let isMatched = isMatchedGraphNode && lookupGraphMatchInfo.keys.contains(node.endNodeIndex)
                if !isMatched {
                    // マッチしていない場合、チェックを走らせる
                    // 生起確率を取得する。
                    let wValue: PValue = node.data.value()
                    node.values = if i == 0 {
                        // valuesを更新する
                        node.prevs.map {$0.totalValue + wValue + dicdataStore.getCCValue($0.data.rcid, node.data.lcid)}
                    } else {
                        // valuesを更新する
                        node.prevs.map {$0.totalValue + wValue}
                    }
                }
                // 終端の場合は終了
                if self.allowedNextIndex[node.endNodeIndex, default: []].isEmpty || result.inputElementsRange.startIndex == node.inputElementsRange.endIndex {
                    for index in node.prevs.indices {
                        let newnode: RegisteredNode = node.getRegisteredNode(index, value: node.values[index])
                        result.prevs.append(newnode)
                    }
                } else {
                    for nextIndex in self.allowedNextIndex[node.endNodeIndex, default: []] {
                        // 次のノードがマッチしている場合、呼び出しの必要はない
                        let nextMatchable = curNodeToCacheNode.keys.contains(nextIndex)
                        // nodeの繋がる次にあり得る全てのnextnodeに対して
                        for nextnode in self.nodes[nextIndex].latticeNodes {
                            if nextMatchable && lookupGraphMatchInfo.keys.contains(nextnode.endNodeIndex) {
                                continue
                            }
                            // この関数はこの時点で呼び出して、後のnode.registered.isEmptyで最終的に弾くのが良い。
                            if dicdataStore.shouldBeRemoved(data: nextnode.data) {
                                continue
                            }
                            // クラスの連続確率を計算する。
                            let ccValue: PValue = dicdataStore.getCCValue(node.data.rcid, nextnode.data.lcid)
                            // nodeの持っている全てのprevnodeに対して
                            for (index, value) in node.values.enumerated() {
                                let newValue: PValue = ccValue + value
                                // 追加すべきindexを取得する
                                let lastindex: Int = (nextnode.prevs.lastIndex(where: {$0.totalValue >= newValue}) ?? -1) + 1
                                if lastindex == option.N_best {
                                    continue
                                }
                                let newnode: RegisteredNode = node.getRegisteredNode(index, value: newValue)
                                // カウントがオーバーしている場合は除去する
                                if nextnode.prevs.count >= option.N_best {
                                    nextnode.prevs.removeLast()
                                }
                                // removeしてからinsertした方が速い (insertはO(N)なので)
                                nextnode.prevs.insert(newnode, at: lastindex)
                            }
                        }
                    }
                }
            }
        }
        return result
    }

}
