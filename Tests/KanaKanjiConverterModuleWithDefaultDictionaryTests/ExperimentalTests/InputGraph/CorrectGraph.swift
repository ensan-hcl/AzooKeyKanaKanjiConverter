//
//  CorrectGraph.swift
//
//
//  Created by miwa on 2024/02/25.
//

import Foundation
import KanaKanjiConverterModule

struct CorrectGraph {
    enum Correction: CustomStringConvertible {
        /// 訂正ではない
        case none
        /// 訂正である
        case typo

        var isTypo: Bool {
            self == .typo
        }

        var description: String {
            switch self {
            case .none: "none"
            case .typo: "typo"
            }
        }
    }

    var nodes: [Node] = [
        // BOSノードは最初から追加
        .init(inputElementsRange: .endIndex(0), inputStyle: .all, correction: .none, value: "\0")
    ]
    /// 許可されたNextIndex
    var allowedNextIndex: [Int: IndexSet] = [:]
    /// 許可されたprevIndex
    var allowedPrevIndex: [Int: IndexSet] = [:]
    /// `ComposingText`の`inputs`に対して、それをendIndexとするノードインデックスの集合を返す
    var inputIndexToEndNodeIndices: [Int: IndexSet] = [0: IndexSet(integer: 0)]

    struct Node: Equatable, Sendable {
        var inputElementsRange: InputGraphRange
        var inputStyle: InputGraphInputStyle.ID
        var correction: CorrectGraph.Correction
        var value: Character
    }

    @discardableResult
    mutating func insert(_ node: consuming Node, nextTo prevNodeIndexSet: IndexSet) -> Int {
        let index = nodes.count
        for prevNodeIndex in prevNodeIndexSet {
            self.allowedNextIndex[prevNodeIndex, default: IndexSet()].insert(index)
        }
        self.allowedPrevIndex[index, default: IndexSet()].formUnion(prevNodeIndexSet)
        self.nodes.append(consume node)
        return index
    }

    private mutating func insertConnectedTypoNodes(values: [Character], startIndex: Int, endIndex: Int, inputStyle: InputGraphInputStyle.ID, lastIndexSet: IndexSet) -> (lastIndex: Int, insertedIndexSet: IndexSet) {
        guard !values.isEmpty else {
            fatalError("values must not be empty")
        }
        var insertedIndexSet = IndexSet()
        var lastIndexSet = lastIndexSet
        for (i, c) in zip(values.indices, values) {
            let inputElementRange: InputGraphRange = if i == values.startIndex && i+1 == values.endIndex {
                .range(startIndex, endIndex)
            } else if i == values.startIndex {
                .init(startIndex: startIndex, endIndex: nil)
            } else if i+1 == values.endIndex {
                .init(startIndex: nil, endIndex: endIndex)
            } else {
                .unknown
            }
            let node = Node(
                inputElementsRange: inputElementRange,
                inputStyle: inputStyle,
                correction: .typo,
                value: c
            )
            let nodeIndex = self.insert(node, nextTo: lastIndexSet)
            lastIndexSet = IndexSet(integer: nodeIndex)
            insertedIndexSet.insert(nodeIndex)
        }
        return (lastIndexSet.first!, insertedIndexSet)
    }

    @discardableResult
    mutating func update(with item: ComposingTextV2.InputElement, index: Int, input: [ComposingTextV2.InputElement]) -> IndexSet {
        var insertedIndexSet = IndexSet()
        // 訂正のない候補を追加
        do {
            let nodeIndex = self.insert(
                Node(
                    inputElementsRange: .range(index, index + 1),
                    inputStyle: input[index].inputStyle,
                    correction: .none,
                    value: item.value
                ),
                nextTo: self.inputIndexToEndNodeIndices[index, default: IndexSet()]
            )
            self.inputIndexToEndNodeIndices[index + 1, default: IndexSet()].insert(nodeIndex)
            insertedIndexSet.insert(nodeIndex)
        }

        // 訂正候補を追加
        let correctSuffixTree = InputGraphInputStyle(from: item.inputStyle).correctSuffixTree
        typealias SearchItem = (
            node: CorrectSuffixTree.Node,
            nextIndex: Int,
            routeCount: Int,
            inputStyleId: InputGraphInputStyle.ID
        )
        var stack: [SearchItem] = [
            (correctSuffixTree, index, 1, .all)
        ]
        // backward search
        while let (cNode, cIndex, cRouteCount, cInputStyleId) = stack.popLast() {
            guard cIndex >= input.startIndex else {
                continue
            }
            let inputStyleId = InputGraphInputStyle(from: input[cIndex].inputStyle).id
            guard cInputStyleId.isCompatible(with: inputStyleId) else {
                continue
            }
            if let nNode = cNode.find(key: input[cIndex].value) {
                stack.append((nNode, cIndex - 1, cRouteCount + 1, inputStyleId))
                for value in nNode.value {
                    if value.isEmpty {
                        continue
                    } else if value.count > 1 {
                        let (nodeIndex, indexSet) = self.insertConnectedTypoNodes(
                            values: Array(value),
                            startIndex: index - cRouteCount + 1,
                            endIndex: index + 1,
                            inputStyle: inputStyleId,
                            lastIndexSet: self.inputIndexToEndNodeIndices[index - cRouteCount + 1, default: IndexSet()]
                        )
                        self.inputIndexToEndNodeIndices[index + 1, default: IndexSet()].insert(nodeIndex)
                        insertedIndexSet.formUnion(indexSet)
                    } else {
                        let nodeIndex = self.insert(
                            Node(
                                inputElementsRange: .range(index - cRouteCount + 1, index + 1),
                                inputStyle: inputStyleId,
                                correction: .typo,
                                value: value.first!
                            ),
                            nextTo: self.inputIndexToEndNodeIndices[index - cRouteCount + 1, default: IndexSet()]
                        )
                        self.inputIndexToEndNodeIndices[index + 1, default: IndexSet()].insert(nodeIndex)
                        insertedIndexSet.insert(nodeIndex)
                    }
                }
            }
        }
        return insertedIndexSet
    }

    static func build(input: [ComposingTextV2.InputElement]) -> Self {
        var correctGraph = Self()
        for (index, item) in zip(input.indices, input) {
            correctGraph.update(with: item, index: index, input: input)
        }
        return correctGraph
    }
}
