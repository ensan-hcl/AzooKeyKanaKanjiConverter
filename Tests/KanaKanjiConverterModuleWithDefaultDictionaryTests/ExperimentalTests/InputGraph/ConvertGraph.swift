//
//  ConvertGraph.swift
//
//
//  Created by miwa on 2024/02/23.
//

import XCTest
import Foundation
@testable import KanaKanjiConverterModule

struct ConvertGraph: InputGraphProtocol {
    struct Node: InputGraphNodeProtocol {
        var latticeNodes: [LatticeNode]
        var displayedTextRange: InputGraphStructure.Range
        var inputElementsRange: InputGraphStructure.Range
        var correction: InputGraph.Correction = .none
    }

    var nodes: [Node] = [
        // root node
        Node(latticeNodes: [], displayedTextRange: .endIndex(0), inputElementsRange: .endIndex(0))
    ]

    var structure: InputGraphStructure = InputGraphStructure()

    static func build(input: LookupGraph, nodeIndex2LatticeNode: [Int: [LatticeNode]]) -> Self {
        let nodes = input.nodes.enumerated().map { (index, node) in
            Node(latticeNodes: nodeIndex2LatticeNode[index, default: []], displayedTextRange: node.displayedTextRange, inputElementsRange: node.inputElementsRange, correction: node.correction)
        }
        return Self(nodes: nodes, structure: input.structure)
    }
}
extension ConvertGraph {
    /// ラティスのノード。これを用いて計算する。
    final class LatticeNode: CustomStringConvertible {
        /// このノードが保持する辞書データ
        public let data: DicdataElement
        /// このノードの前に来ているノード。`N_best`の分だけ保存する
        var prevs: [RegisteredNode] = []
        /// `prevs`の各要素に対応するスコアのデータ
        var values: [PValue] = []
        /// inputData.input内のrange
        var displayedTextRange: InputGraphStructure.Range
        var inputElementsRange: InputGraphStructure.Range

        /// `EOS`に対応するノード。
        static var EOSNode: LatticeNode {
            LatticeNode(data: DicdataElement.EOSData, displayedTextRange: .unknown, inputElementsRange: .unknown)
        }

        init(data: DicdataElement, displayedTextRange: InputGraphStructure.Range, inputElementsRange: InputGraphStructure.Range, prevs: [RegisteredNode] = []) {
            self.data = data
            self.values = [data.value()]
            self.displayedTextRange = displayedTextRange
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
                displayedTextRange: self.displayedTextRange,
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
        var displayedTextRange: InputGraphStructure.Range
        var inputElementsRange: InputGraphStructure.Range

        init(data: DicdataElement, registered: RegisteredNode?, totalValue: PValue, displayedTextRange: InputGraphStructure.Range, inputElementsRange: InputGraphStructure.Range) {
            self.data = data
            self.prev = registered
            self.totalValue = totalValue
            self.displayedTextRange = displayedTextRange
            self.inputElementsRange = inputElementsRange
        }

        /// 始点ノードを生成する関数
        /// - Returns: 始点ノードのデータ
        static func BOSNode() -> RegisteredNode {
            RegisteredNode(data: DicdataElement.BOSData, registered: nil, totalValue: 0, displayedTextRange: .endIndex(0), inputElementsRange: .endIndex(0))
        }
    }

}

/// `struct`の`RegisteredNode`を再帰的に所持できるようにするため、Existential Typeで抽象化する。
/// - Note: `indirect enum`との比較はまだやっていない。
protocol RegisteredNodeProtocol {
    var data: DicdataElement {get}
    var prev: (any RegisteredNodeProtocol)? {get}
    var totalValue: PValue {get}
    /// inputData.input内のrange
    var displayedTextRange: InputGraphStructure.Range {get}
    var inputElementsRange: InputGraphStructure.Range {get}
}

extension ConvertGraph {
    func convertAll(option: borrowing ConvertRequestOptions, dicdataStore: DicdataStore) -> LatticeNode {
        let result: LatticeNode = LatticeNode.EOSNode
        result.displayedTextRange = .startIndex(self.structure.displayedTextEndIndexToNodeIndices.endIndex)
        result.inputElementsRange = .startIndex(self.structure.inputElementsEndIndexToNodeIndices.endIndex)
        var processStack = Array(self.nodes.enumerated().reversed())
        var processedIndices: IndexSet = [0] // root
        var invalidIndices: IndexSet = []
        // 「i文字目から始まるnodes」に対して
        while let (i, graphNode) = processStack.popLast() {
            // 処理済みなら無視する
            guard !processedIndices.contains(i), !invalidIndices.contains(i) else {
                continue
            }
            // 全てのprevNodeが処理済みか確かめる
            let prevIndices = self.structure.prevIndices(displayedTextStartIndex: graphNode.displayedTextRange.startIndex, inputElementsStartIndex: graphNode.inputElementsRange.startIndex)
            guard !prevIndices.isEmpty else {
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
            print(i, graphNode.displayedTextRange, graphNode.inputElementsRange)
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
                // このLatticeNodeに後続するグラフのノードを検索
                let nextIndices = self.structure.nextIndices(
                    displayedTextEndIndex: node.displayedTextRange.endIndex,
                    inputElementsEndIndex: node.inputElementsRange.endIndex
                )
                // 文字数がcountと等しい場合登録する
                if nextIndices.isEmpty {
                    for index in node.prevs.indices {
                        let newnode: RegisteredNode = node.getRegisteredNode(index, value: node.values[index])
                        result.prevs.append(newnode)
                    }
                } else {
                    for nextIndex in nextIndices {
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
}
