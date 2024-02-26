//
//  InputGraph.swift
//
//
//  Created by miwa on 2024/02/21.
//

import Foundation
import DequeModule

@testable import KanaKanjiConverterModule
import XCTest

struct InputGraphStructure {
    enum Range: Equatable, Sendable {
        case unknown
        case startIndex(Int)
        case endIndex(Int)
        case range(Int, Int)

        init(startIndex: Int?, endIndex: Int?) {
            self = switch (startIndex, endIndex) {
            case let (s?, e?): .range(s, e)
            case (let s?, nil): .startIndex(s)
            case (nil, let e?): .endIndex(e)
            case (nil, nil): .unknown
            }
        }

        var startIndex: Int? {
            switch self {
            case .unknown, .endIndex: nil
            case .startIndex(let index), .range(let index, _): index
            }
        }

        var endIndex: Int? {
            switch self {
            case .unknown, .startIndex: nil
            case .endIndex(let index), .range(_, let index): index
            }
        }
    }

    /// `displayedTextStartIndexToNodeIndices[0]`は`displayedTextRange==.startIndex(0)`または`displayedTextRange==.range(0, k)`であるようなノードのindexのセットを返す
    var displayedTextStartIndexToNodeIndices: [IndexSet] = []
    var inputElementsStartIndexToNodeIndices: [IndexSet] = []
    var displayedTextEndIndexToNodeIndices: [IndexSet] = [IndexSet(integer: 0)]  // rootノードのindexで初期化
    var inputElementsEndIndexToNodeIndices: [IndexSet] = [IndexSet(integer: 0)]  // rootノードのindexで初期化
    /// 使用されなくなったインデックスの集合
    var deadNodeIndices: [Int] = []
    /// 許可されたNextIndex
    var allowedNextIndex: [Int: [Int]] = [:]
    /// 許可されたprevIndex
    var allowedPrevIndex: [Int: [Int]] = [:]
    /// id生成用
    var groupIdIota: Iota = Iota()

    func nextIndices(displayedTextEndIndex: Int?, inputElementsEndIndex: Int?) -> IndexSet {
        var indexSet = IndexSet()
        if let displayedTextEndIndex {
            if displayedTextEndIndex < self.displayedTextStartIndexToNodeIndices.endIndex {
                indexSet.formUnion(self.displayedTextStartIndexToNodeIndices[displayedTextEndIndex])
            }
        }
        if let inputElementsEndIndex {
            if inputElementsEndIndex < self.inputElementsStartIndexToNodeIndices.endIndex {
                indexSet.formUnion(self.inputElementsStartIndexToNodeIndices[inputElementsEndIndex])
            }
        }
        return indexSet
    }

    func prevIndices(displayedTextStartIndex: Int?, inputElementsStartIndex: Int?) -> IndexSet {
        var indexSet = IndexSet()
        if let displayedTextStartIndex {
            if displayedTextStartIndex < self.displayedTextEndIndexToNodeIndices.endIndex {
                indexSet.formUnion(self.displayedTextEndIndexToNodeIndices[displayedTextStartIndex])
            }
        }
        if let inputElementsStartIndex {
            if inputElementsStartIndex < self.inputElementsEndIndexToNodeIndices.endIndex {
                indexSet.formUnion(self.inputElementsEndIndexToNodeIndices[inputElementsStartIndex])
            }
        }
        return indexSet
    }

    enum Connection {
        case none
        case nextRestriction(Int)
        case restriction(prev: Int, next: Int)
        case prevRestriction(Int)
    }
    /// 戻り値は`index`
    mutating func insert<T>(_ node: T, nodes: inout [T], displayedTextRange: Range, inputElementsRange: Range, connection: Connection = .none) -> Int {
        // 可能ならdeadNodeIndicesを再利用する
        let index: Int
        if let deadIndex = self.deadNodeIndices.popLast() {
            nodes[deadIndex] = node
            index = deadIndex
        } else {
            nodes.append(node)
            index = nodes.count - 1
        }
        // このケースではここにだけ追加する
        if case let .restriction(prev, next) = connection {
            self.allowedPrevIndex[prev, default: []].append(index)
            self.allowedPrevIndex[index, default: []].append(prev)
            self.allowedNextIndex[next, default: []].append(index)
            self.allowedNextIndex[index, default: []].append(next)
            return index
        }
        if case let .nextRestriction(next) = connection {
            self.allowedNextIndex[index, default: []].append(next)
            self.allowedNextIndex[next, default: []].append(index)
        } else {
            // 出ているノードに特に制限はないので、endIndexは登録できる
            if let endIndex = displayedTextRange.endIndex {
                if self.displayedTextEndIndexToNodeIndices.endIndex <= endIndex {
                    self.displayedTextEndIndexToNodeIndices.append(contentsOf: Array(repeating: IndexSet(), count: endIndex - self.displayedTextEndIndexToNodeIndices.endIndex + 1))
                }
                self.displayedTextEndIndexToNodeIndices[endIndex].insert(index)
            }
            if let endIndex = inputElementsRange.endIndex {
                if self.inputElementsEndIndexToNodeIndices.endIndex <= endIndex {
                    self.inputElementsEndIndexToNodeIndices.append(contentsOf: Array(repeating: IndexSet(), count: endIndex - self.inputElementsEndIndexToNodeIndices.endIndex + 1))
                }
                self.inputElementsEndIndexToNodeIndices[endIndex].insert(index)
            }
        }
        if case let .prevRestriction(prev) = connection {
            self.allowedPrevIndex[index, default: []].append(prev)
            self.allowedPrevIndex[prev, default: []].append(index)
        } else {
            // 入ってくるノードに特に制限はないので、startIndexは登録できる
            // それ以外の場合は通常の通り追加する
            if let startIndex = displayedTextRange.startIndex {
                if self.displayedTextStartIndexToNodeIndices.endIndex <= startIndex {
                    self.displayedTextStartIndexToNodeIndices.append(contentsOf: Array(repeating: IndexSet(), count: startIndex - self.displayedTextStartIndexToNodeIndices.endIndex + 1))
                }
                self.displayedTextStartIndexToNodeIndices[startIndex].insert(index)
            }
            if let startIndex = inputElementsRange.startIndex {
                if self.inputElementsStartIndexToNodeIndices.endIndex <= startIndex {
                    self.inputElementsStartIndexToNodeIndices.append(contentsOf: Array(repeating: IndexSet(), count: startIndex - self.inputElementsStartIndexToNodeIndices.endIndex + 1))
                }
                self.inputElementsStartIndexToNodeIndices[startIndex].insert(index)
            }
        }
        return index
    }

    mutating func remove(at index: Int) {
        assert(index != 0, "Node at index 0 is root and must not be removed.")
        self.deadNodeIndices.append(index)
        // FIXME: 多分nodeの情報を使えばもっと効率的にremoveできる
        self.allowedPrevIndex.values.mutatingForeach {
            $0.removeAll(where: {$0 == index})
        }
        self.allowedPrevIndex.removeValue(forKey: index)
        self.allowedNextIndex.values.mutatingForeach {
            $0.removeAll(where: {$0 == index})
        }
        self.allowedNextIndex.removeValue(forKey: index)
        self.displayedTextStartIndexToNodeIndices.mutatingForeach {
            $0.remove(index)
        }
        self.displayedTextEndIndexToNodeIndices.mutatingForeach {
            $0.remove(index)
        }
        self.inputElementsStartIndexToNodeIndices.mutatingForeach {
            $0.remove(index)
        }
        self.inputElementsEndIndexToNodeIndices.mutatingForeach {
            $0.remove(index)
        }
    }
}

struct InputGraph: InputGraphProtocol {
    struct InputStyle: Identifiable {
        init(from deprecatedInputStyle: KanaKanjiConverterModule.InputStyle) {
            switch deprecatedInputStyle {
            case .direct:
                self = .systemFlickDirect
            case .roman2kana:
                self = .systemRomanKana
            }
        }

        init(id: InputGraph.InputStyle.ID, replacePrefixTree: ReplacePrefixTree.Node, correctPrefixTree: CorrectPrefixTree.Node) {
            self.id = id
            self.replacePrefixTree = replacePrefixTree
            self.correctPrefixTree = correctPrefixTree
        }

        struct ID: Equatable, Hashable, Sendable, CustomStringConvertible {
            init(id: UInt8) {
                self.id = id
            }
            init(from deprecatedInputStyle: KanaKanjiConverterModule.InputStyle) {
                switch deprecatedInputStyle {
                case .direct:
                    self = .systemFlickDirect
                case .roman2kana:
                    self = .systemRomanKana
                }
            }
            static let all = Self(id: 0x00)
            static let systemFlickDirect = Self(id: 0x01)
            static let systemRomanKana = Self(id: 0x02)
            var id: UInt8

            func isCompatible(with id: ID) -> Bool {
                if self == .all {
                    true
                } else {
                    self == id
                }
            }
            var description: String {
                "ID(\(id))"
            }
        }
        static let all: Self = InputStyle(
            id: .all,
            replacePrefixTree: ReplacePrefixTree.Node(),
            correctPrefixTree: CorrectPrefixTree.Node()
        )
        static let systemFlickDirect: Self = InputStyle(
            id: .systemFlickDirect,
            replacePrefixTree: ReplacePrefixTree.direct,
            correctPrefixTree: CorrectPrefixTree.direct
        )
        static let systemRomanKana: Self = InputStyle(
            id: .systemRomanKana,
            replacePrefixTree: ReplacePrefixTree.roman2kana,
            correctPrefixTree: CorrectPrefixTree.roman2kana
        )

        /// `id` for the input style.
        ///  - warning: value `0x00-0x7F` is reserved for system space.
        var id: ID
        var replacePrefixTree: ReplacePrefixTree.Node
        var correctPrefixTree: CorrectPrefixTree.Node
    }

    struct Node: InputGraphNodeProtocol, Equatable, CustomStringConvertible {
        var character: Character
        var displayedTextRange: InputGraphStructure.Range
        var inputElementsRange: InputGraphStructure.Range
        var groupId: Int? = nil
        var correction: CorrectGraph.Correction = .none
        /// すでにreplaceされてしまったノードであるかどうか？
        var isReplaced: Bool = false

        var description: String {
            let ds = displayedTextRange.startIndex?.description ?? "?"
            let de = displayedTextRange.endIndex?.description ?? "?"
            let `is` = inputElementsRange.startIndex?.description ?? "?"
            let ie = inputElementsRange.endIndex?.description ?? "?"
            return "Node(\"\(character)\", d(\(ds)..<\(de)), i(\(`is`)..<\(ie)), isTypo: \(correction.isTypo), id: \(groupId))"
        }
    }

    var nodes: [Node] = [
        // root node
        Node(character: "\0", displayedTextRange: .endIndex(0), inputElementsRange: .endIndex(0))
    ]

    var structure: InputGraphStructure = InputGraphStructure()

    mutating func backwardMatches(_ correctGraph: CorrectGraph, nodeIndex: Int) {
        let correctGraphNode = correctGraph.nodes[nodeIndex]

        let startNode = switch correctGraphNode.inputStyle {
        case .systemFlickDirect:
            ReplaceSuffixTree.direct
        case .systemRomanKana:
            ReplaceSuffixTree.roman2kana
        default: fatalError("implement it")
        }
        print(nodeIndex, startNode.children.count, correctGraphNode)
        // nodesをそれぞれ遡っていく必要がある
        typealias SearchItem = (
            suffixTreeNode: ReplaceSuffixTree.Node,
            startNodeIndex: Int,
            route: [Int],
            correction: CorrectGraph.Correction
        )
        typealias Match = (
            displayedTextStartIndex: Int?,
            inputElementsStartIndex: Int?,
            inputElementsEndIndex: Int?,
            backwardRoute: [Int],
            value: String,
            /// このマッチを認可するノードの`index`
            licenserNodeIndex: Int?,
            /// groupId
            groupId: Int?,
            correction: CorrectGraph.Correction
        )
        var backSearchMatch: [Match] = []
        var stack: [SearchItem] = [(startNode, nodeIndex, [nodeIndex], correctGraphNode.correction.isTypo ? .typo : .none)]
        while let (cSuffixTreeNode, cNodeIndex, cRoute, cCorrection) = stack.popLast() {
            let isUnInsertedNode = cNodeIndex == nodeIndex && cRoute.count == 1
            let bNode = if isUnInsertedNode {
                cSuffixTreeNode.find(key: correctGraphNode.value)
            } else {
                cSuffixTreeNode.find(key: self.nodes[cNodeIndex].character)
            }
            print(nodeIndex, cRoute, isUnInsertedNode ? correctGraphNode.value : self.nodes[cNodeIndex].character, bNode?.character, cSuffixTreeNode.children.count, cCorrection)
            if let bNode {
                // cNodeIndexのprevをリスト
                let indices = if isUnInsertedNode {
                    if let groupId = correctGraphNode.groupId,
                       let lastNodeIndex = self.nodes.lastIndex(where: {$0.groupId == groupId}) {
                        self.structure.prevIndices(displayedTextStartIndex: nil, inputElementsStartIndex: correctGraphNode.inputElementsRange.startIndex)
                            .union(IndexSet(integer: lastNodeIndex))
                    } else {
                        self.structure.prevIndices(displayedTextStartIndex: nil, inputElementsStartIndex: correctGraphNode.inputElementsRange.startIndex)
                    }
                } else {
                    self.prevIndices(for: self.nodes[cNodeIndex]).union(IndexSet(self.structure.allowedPrevIndex[cNodeIndex, default: []]))
                        .filteredIndexSet {
                            if let pEndIndex = self.nodes[$0].inputElementsRange.endIndex,
                               let cStartIndex = self.nodes[cNodeIndex].inputElementsRange.startIndex {
                                return pEndIndex == cStartIndex
                            }
                            return true
                        }
                }

                let nonReplacedIndices = indices.filteredIndexSet {!self.nodes[$0].isReplaced}

                print(nodeIndex, cRoute, bNode.character, Array(indices), indices.map{(self.nodes[$0].character, self.nodes[$0].isReplaced)})
                // bNode: 1つ前のノード
                // bNodeが値を持っているか？
                if let value = bNode.value {
                    // MARK: 条件A: bNodeがchildrenを持たない→longestMatchで確定なので追加して良い
                    if bNode.children.isEmpty && !cCorrection.isTypo {
                        let lastNode = nonReplacedIndices.first {!self.nodes[$0].correction.isTypo}.map{self.nodes[$0]}
                        let inputElementsStartIndex = lastNode?.inputElementsRange.endIndex
                        let displayedTextStartIndex = lastNode?.displayedTextRange.endIndex
                        backSearchMatch.append(
                            (displayedTextStartIndex, inputElementsStartIndex, correctGraphNode.inputElementsRange.endIndex, cRoute, value, nil, nil, cCorrection)
                        )
                    } else {
                        // MARK: 条件B: findできないprevノードが存在する
                        for prevGraphNodeIndex in nonReplacedIndices {
                            if bNode.find(key: self.nodes[prevGraphNodeIndex].character) == nil {
                                let inputElementsStartIndex = self.nodes[prevGraphNodeIndex].inputElementsRange.endIndex
                                let displayedTextStartIndex = self.nodes[prevGraphNodeIndex].displayedTextRange.endIndex
                                let licenser: Int? = if self.nodes[prevGraphNodeIndex].correction.isTypo {
                                    prevGraphNodeIndex
                                } else {
                                    nil
                                }
                                backSearchMatch.append(
                                    (displayedTextStartIndex, inputElementsStartIndex, correctGraphNode.inputElementsRange.endIndex, cRoute, value, licenser, nil, cCorrection)
                                )
                            }
                        }
                    }
                } else if isUnInsertedNode {
                    let lastNode = nonReplacedIndices.first {!self.nodes[$0].correction.isTypo}.map{self.nodes[$0]}
                    let displayedTextStartIndex = lastNode?.displayedTextRange.endIndex
                    backSearchMatch.append(
                        (
                            displayedTextStartIndex,
                            correctGraphNode.inputElementsRange.startIndex,
                            correctGraphNode.inputElementsRange.endIndex,
                            cRoute,
                            String(correctGraphNode.value),
                            nil,
                            groupId: correctGraphNode.groupId,
                            cCorrection
                        )
                    )
                }
                for prevGraphNodeIndex in indices {
                    // TODO: InputGraph.NodeにもInputStyle.IDを持たせてここで比較する
                    stack.append(
                        (
                            bNode,
                            prevGraphNodeIndex,
                            [prevGraphNodeIndex] + cRoute,
                            cCorrection.isTypo ? .typo : self.nodes[prevGraphNodeIndex].correction
                        )
                    )
                }
            } else {
                // 最初である場合
                if isUnInsertedNode {
                    let displayedTextStartIndex: Int? = if cCorrection.isTypo {
                        nil
                    } else {
                        nil
                    }
                    backSearchMatch.append(
                        (
                            displayedTextStartIndex,
                            correctGraphNode.inputElementsRange.startIndex,
                            correctGraphNode.inputElementsRange.endIndex,
                            cRoute,
                            String(correctGraphNode.value),
                            nil,
                            correctGraphNode.groupId,
                            cCorrection
                        )
                    )
                }
            }
        }

        print(backSearchMatch)
        var removeTargetIndices: IndexSet = IndexSet()
        for match in backSearchMatch {
            // licenserが存在するケースではlicenserと同じgroupIdを振る
            let licenser = match.licenserNodeIndex.map{self.nodes[$0]}
            // そうでなければ一塊で同じgroupとして追加。新規groupIdを発行
            if match.value.count > 1 {
                self.insertConnectedNodes(
                    values: Array(match.value),
                    inputElementsRange: .init(startIndex: match.inputElementsStartIndex, endIndex: match.inputElementsEndIndex),
                    displayedTextStartIndex: match.displayedTextStartIndex,
                    correction: match.correction,
                    inputStyle: correctGraphNode.inputStyle
                )
            } else if match.value.count == 1 {
                let index = self.insert(
                    Node(
                        character: match.value.first!,
                        displayedTextRange: match.displayedTextStartIndex.map{.range($0, $0 + match.value.count)} ?? .unknown,
                        inputElementsRange: .init(startIndex: match.inputElementsStartIndex, endIndex: match.inputElementsEndIndex),
                        groupId: match.groupId ?? licenser?.groupId,
                        correction: match.correction
                    )
                )
                if licenser?.groupId == nil, let licenserNodeIndex = match.licenserNodeIndex {
                    self.createNewConnection(from: licenserNodeIndex, to: index)
                }
            }
            if match.correction == .none {
                for nodeIndex in match.backwardRoute.dropLast() {
                    self.nodes[nodeIndex].isReplaced = true
                }
            }
        }
    }

    mutating func createNewConnection(from fromNodeIndex: Int, to toNodeIndex: Int) {
        assert(self.nodes[fromNodeIndex].groupId == nil)
        let newId = self.structure.groupIdIota.new()
        self.nodes[fromNodeIndex].groupId = newId
        self.nodes[toNodeIndex].groupId = newId
        self.structure.inputElementsStartIndexToNodeIndices.mutatingForeach { indexSet in
            indexSet.remove(toNodeIndex)
        }
        self.structure.displayedTextStartIndexToNodeIndices.mutatingForeach { indexSet in
            indexSet.remove(toNodeIndex)
        }
        self.structure.inputElementsEndIndexToNodeIndices.mutatingForeach { indexSet in
            indexSet.remove(fromNodeIndex)
        }
        self.structure.displayedTextEndIndexToNodeIndices.mutatingForeach { indexSet in
            indexSet.remove(fromNodeIndex)
        }
        self.structure.allowedNextIndex[fromNodeIndex, default: []].append(toNodeIndex)
        self.structure.allowedPrevIndex[toNodeIndex, default: []].append(fromNodeIndex)
    }

    mutating func insertConnectedNodes(values: [Character], inputElementsRange: InputGraphStructure.Range, displayedTextStartIndex: Int?, correction: CorrectGraph.Correction, inputStyle: InputGraph.InputStyle.ID) {
        let id = self.structure.groupIdIota.new()
        var lastNodeIndex: Int? = nil
        for (i, c) in zip(values.indices, values) {
            let inputElementRange: InputGraphStructure.Range = if i == values.startIndex && i+1 == values.endIndex {
                .init(startIndex: inputElementsRange.startIndex, endIndex: inputElementsRange.endIndex)
            } else if i == values.startIndex {
                .init(startIndex: inputElementsRange.startIndex, endIndex: nil)
            } else if i+1 == values.endIndex {
                .init(startIndex: nil, endIndex: inputElementsRange.endIndex)
            } else {
                .unknown
            }
            let node = Node(
                character: c,
                displayedTextRange: displayedTextStartIndex.map{.range($0+i, $0 + i+1)} ?? .unknown,
                inputElementsRange: inputElementRange,
                groupId: id, 
                correction: correction
            )
            lastNodeIndex = self.insert(node, connection: lastNodeIndex.map {.prevRestriction($0)} ?? .none)
        }
    }

    static func build(input: CorrectGraph) -> Self {
        var inputGraph = Self()
        inputGraph.structure.groupIdIota = input.groupIdIota
        // 必ず、ノードより前のすべてのノードが処理済みであることを保証しながら、insertCorrectGraphNodeを実行する
        var nodeIndices = Array(input.inputElementsStartIndexToNodeIndices.first ?? .init())
        var processedIndices = IndexSet()
        while let nodeIndex = nodeIndices.popLast() {
            if processedIndices.contains(nodeIndex) {
                continue
            }
            var prevIndices = input.prevIndices(for: nodeIndex)
            if let prevIndex = input.allowedPrevIndex[nodeIndex] {
                prevIndices.insert(prevIndex)
            }
            // 差がある場合
            let diff = prevIndices.subtracting(processedIndices)
            guard diff.isEmpty else {
                nodeIndices.append(nodeIndex)
                nodeIndices.append(contentsOf: diff)
                continue
            }
            processedIndices.insert(nodeIndex)
            inputGraph.backwardMatches(input, nodeIndex: nodeIndex)
            nodeIndices.append(contentsOf: input.nextIndices(for: nodeIndex))
            if let nextIndex = input.allowedNextIndex[nodeIndex] {
                nodeIndices.append(nextIndex)
            }
        }
        return inputGraph
    }
}
