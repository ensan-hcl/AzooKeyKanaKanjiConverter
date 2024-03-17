//
//  CorrectGraph.swift
//
//
//  Created by miwa on 2024/02/25.
//

import Foundation
@testable import KanaKanjiConverterModule
import XCTest

struct CorrectGraph {
    var nodes: [Node] = [
        // BOSノードは最初から追加
        .init(inputElementsRange: .endIndex(0), inputStyle: .all, correction: .none, value: "\0")
    ]
    /// 許可されたNextIndex
    var allowedNextIndex: [Int: IndexSet] = [:]
    /// 許可されたprevIndex
    var allowedPrevIndex: [Int: IndexSet] = [:]

    struct Node: Equatable, Sendable {
        var inputElementsRange: InputGraphRange
        var inputStyle: InputGraphInputStyle.ID
        var correction: CorrectGraph2.Correction
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

    mutating func insertConnectedTypoNodes(values: [Character], startIndex: Int, endIndex: Int, inputStyle: InputGraphInputStyle.ID, lastIndexSet: IndexSet) -> Int {
        guard !values.isEmpty else {
            fatalError("values must not be empty")
        }
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
            lastIndexSet = IndexSet(integer: self.insert(node, nextTo: lastIndexSet))
        }
        return lastIndexSet.first!
    }

    static func build(input: [ComposingText.InputElement]) -> Self {
        var correctGraph = Self()
        var inputIndexToEndNodeIndices: [Int: IndexSet] = [0: IndexSet(integer: 0)]
        for (index, item) in zip(input.indices, input) {
            // 訂正のない候補を追加
            do {
                let nodeIndex = correctGraph.insert(
                    Node(
                        inputElementsRange: .range(index, index + 1),
                        inputStyle: InputGraphInputStyle(from: input[index].inputStyle).id,
                        correction: .none,
                        value: item.character
                    ),
                    nextTo: inputIndexToEndNodeIndices[index, default: IndexSet()]
                )
                inputIndexToEndNodeIndices[index + 1, default: IndexSet()].insert(nodeIndex)
            }

            // 訂正候補を追加
            let correctPrefixTree = switch item.inputStyle {
            case .roman2kana: CorrectPrefixTree.roman2kana
            case .direct: CorrectPrefixTree.direct
            }
            typealias Match = (replace: String, inputCount: Int)
            typealias SearchItem = (
                node: CorrectPrefixTree.Node,
                nextIndex: Int,
                route: [Character],
                inputStyleId: InputGraphInputStyle.ID
            )
            var stack: [SearchItem] = [
                (correctPrefixTree, index, [], .all),
            ]
            while let (cNode, cIndex, cRoute, cInputStyleId) = stack.popLast() {
                guard cIndex < input.endIndex else {
                    continue
                }
                let inputStyleId = InputGraphInputStyle(from: input[cIndex].inputStyle).id
                guard cInputStyleId.isCompatible(with: inputStyleId) else {
                    continue
                }
                if let nNode = cNode.find(key: input[cIndex].character) {
                    stack.append((nNode, cIndex + 1, cRoute + [input[cIndex].character], inputStyleId))
                    for value in nNode.value {
                        if value.isEmpty {
                            continue
                        } else if value.count > 1 {
                            let nodeIndex = correctGraph.insertConnectedTypoNodes(
                                values: Array(value),
                                startIndex: index,
                                endIndex: index + cRoute.count + 1,
                                inputStyle: inputStyleId, 
                                lastIndexSet: inputIndexToEndNodeIndices[index, default: IndexSet()]
                            )
                            inputIndexToEndNodeIndices[index + cRoute.count + 1, default: IndexSet()].insert(nodeIndex)
                        } else {
                            let nodeIndex = correctGraph.insert(
                                Node(
                                    inputElementsRange: .range(index, index + cRoute.count + 1),
                                    inputStyle: inputStyleId,
                                    correction: .typo,
                                    value: value.first!
                                ),
                                nextTo: inputIndexToEndNodeIndices[index, default: IndexSet()]
                            )
                            inputIndexToEndNodeIndices[index + cRoute.count + 1, default: IndexSet()].insert(nodeIndex)
                        }
                    }
                }
            }
        }
        return correctGraph
    }
}


struct CorrectGraph2 {
    var nodes: [Node] = []
    /// 許可されたNextIndex
    var allowedNextIndex: [Int: Int] = [:]
    /// 許可されたprevIndex
    var allowedPrevIndex: [Int: Int] = [:]
    var inputElementsStartIndexToNodeIndices: [IndexSet] = []
    var inputElementsEndIndexToNodeIndices: [IndexSet] = []
    var groupIdIota: Iota = Iota()
    
    func prevIndices(for nodeIndex: Int) -> IndexSet {
        var indexSet = IndexSet()
        if let startIndex = self.nodes[nodeIndex].inputElementsRange.startIndex,
           startIndex < self.inputElementsEndIndexToNodeIndices.endIndex {
            indexSet.formUnion(self.inputElementsEndIndexToNodeIndices[startIndex])
        }
        if let value = allowedPrevIndex[nodeIndex] {
            indexSet.insert(value)
        }
        return indexSet
    }

    func nextIndices(for nodeIndex: Int) -> IndexSet {
        var indexSet = IndexSet()
        if let endIndex = self.nodes[nodeIndex].inputElementsRange.endIndex,
           endIndex < self.inputElementsStartIndexToNodeIndices.endIndex {
            indexSet.formUnion(self.inputElementsStartIndexToNodeIndices[endIndex])
        }
        if let value = allowedNextIndex[nodeIndex] {
            indexSet.insert(value)
        }
        return indexSet
    }

    struct Node: Equatable, Sendable {
        var inputElementsRange: InputGraphRange
        var inputStyle: InputGraphInputStyle.ID
        var correction: Correction
        var value: Character
        var groupId: Int?
    }

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

    @discardableResult
    mutating func insert(_ node: consuming Node) -> Int {
        let index = nodes.count
        if let startIndex = node.inputElementsRange.startIndex {
            if self.inputElementsStartIndexToNodeIndices.endIndex <= startIndex {
                self.inputElementsStartIndexToNodeIndices.append(contentsOf: Array(repeating: IndexSet(), count: startIndex - self.inputElementsStartIndexToNodeIndices.endIndex + 1))
            }
            self.inputElementsStartIndexToNodeIndices[startIndex].insert(index)
        }
        if let endIndex = node.inputElementsRange.endIndex {
            if self.inputElementsEndIndexToNodeIndices.endIndex <= endIndex {
                self.inputElementsEndIndexToNodeIndices.append(contentsOf: Array(repeating: IndexSet(), count: endIndex - self.inputElementsEndIndexToNodeIndices.endIndex + 1))
            }
            self.inputElementsEndIndexToNodeIndices[endIndex].insert(index)
        }
        self.nodes.append(consume node)
        return index
    }

    mutating func insertConnectedTypoNodes(values: [Character], startIndex: Int, endIndex: Int, inputStyle: InputGraphInputStyle.ID) {
        var indices: [Int] = []
        let id = self.groupIdIota.new()
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
                value: c,
                groupId: id
            )
            let index = self.insert(node)
            indices.append(index)
        }
        // connectを追加
        for i in indices.indices.dropLast() {
            self.allowedNextIndex[indices[i]] = indices[i+1]
            self.allowedPrevIndex[indices[i+1]] = indices[i]
        }
    }

    static func build(input: [ComposingText.InputElement]) -> Self {
        var correctGraph = Self()
        for (index, item) in zip(input.indices, input) {
            correctGraph.insert(
                Node(
                    inputElementsRange: .range(index, index + 1),
                    inputStyle: InputGraphInputStyle(from: input[index].inputStyle).id,
                    correction: .none,
                    value: item.character
                )
            )
            let correctPrefixTree = switch item.inputStyle {
            case .roman2kana: CorrectPrefixTree.roman2kana
            case .direct: CorrectPrefixTree.direct
            }
            typealias Match = (replace: String, inputCount: Int)
            typealias SearchItem = (
                node: CorrectPrefixTree.Node,
                nextIndex: Int,
                route: [Character],
                inputStyleId: InputGraphInputStyle.ID
            )
            var stack: [SearchItem] = [
                (correctPrefixTree, index, [], .all),
            ]
            while let (cNode, cIndex, cRoute, cInputStyleId) = stack.popLast() {
                guard cIndex < input.endIndex else {
                    continue
                }
                let inputStyleId = InputGraphInputStyle(from: input[cIndex].inputStyle).id
                guard cInputStyleId.isCompatible(with: inputStyleId) else {
                    continue
                }
                if let nNode = cNode.find(key: input[cIndex].character) {
                    stack.append((nNode, cIndex + 1, cRoute + [input[cIndex].character], inputStyleId))
                    for value in nNode.value {
                        if value.isEmpty {
                            continue
                        } else if value.count > 1 {
                            correctGraph.insertConnectedTypoNodes(
                                values: Array(value),
                                startIndex: index,
                                endIndex: index + cRoute.count + 1,
                                inputStyle: inputStyleId
                            )
                        } else {
                            correctGraph.insert(
                                Node(
                                    inputElementsRange: .range(index, index + cRoute.count + 1),
                                    inputStyle: inputStyleId,
                                    correction: .typo,
                                    value: value.first!
                                )
                            )
                        }
                    }
                }
            }
        }
        return correctGraph
    }
}

final class CorrectGraphTests: XCTestCase {
    func testBuildSimpleDirectInput() throws {
        let graph = CorrectGraph.build(input: [
            .init(character: "あ", inputStyle: .direct)
        ])
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == "あ"}),
            .init(inputElementsRange: .range(0, 1), inputStyle: .systemFlickDirect, correction: .none, value: "あ")
        )
    }
    func testBuildSimpleDirectInputWithTypo() throws {
        let graph = CorrectGraph.build(input: [
            .init(character: "か", inputStyle: .direct)
        ])
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == "か"}),
            .init(inputElementsRange: .range(0, 1), inputStyle: .systemFlickDirect, correction: .none, value: "か")
        )
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == "が"}),
            .init(inputElementsRange: .range(0, 1), inputStyle: .systemFlickDirect, correction: .typo, value: "が")
        )
    }
    func testBuildMultipleDirectInputWithTypo() throws {
        let graph = CorrectGraph.build(input: [
            .init(character: "あ", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct),
            .init(character: "う", inputStyle: .direct),
        ])
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == "か"}),
            .init(inputElementsRange: .range(1, 2), inputStyle: .systemFlickDirect, correction: .none, value: "か")
        )
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == "が"}),
            .init(inputElementsRange: .range(1, 2), inputStyle: .systemFlickDirect, correction: .typo, value: "が")
        )
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == "う"}),
            .init(inputElementsRange: .range(2, 3), inputStyle: .systemFlickDirect, correction: .none, value: "う")
        )
        if let index = graph.nodes.firstIndex(where: {$0.value == "う"}) {
            XCTAssertEqual(graph.allowedPrevIndex[index, default: .init()].count, 2)
        } else {
            XCTAssertThrowsError("Should not be nil")
        }
    }
    func testBuildSimpleRomanInput() throws {
        let graph = CorrectGraph.build(input: [
            .init(character: "k", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana)
        ])
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == "k"}),
            .init(inputElementsRange: .range(0, 1), inputStyle: .systemRomanKana, correction: .none, value: "k")
        )
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == "a"}),
            .init(inputElementsRange: .range(1, 2), inputStyle: .systemRomanKana, correction: .none, value: "a")
        )
    }
    func testBuildSimpleRomanInputWithTypo() throws {
        let graph = CorrectGraph.build(input: [
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana)
        ])
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == "t" && $0.inputElementsRange == .range(0, 1)}),
            .init(inputElementsRange: .range(0, 1), inputStyle: .systemRomanKana, correction: .none, value: "t")
        )
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == "s"}),
            .init(inputElementsRange: .range(1, 2), inputStyle: .systemRomanKana, correction: .none, value: "s")
        )
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == "t" && $0.inputElementsRange == .startIndex(0)}),
            .init(inputElementsRange: .startIndex(0), inputStyle: .systemRomanKana, correction: .typo, value: "t")
        )
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == "a"}),
            .init(inputElementsRange: .endIndex(2), inputStyle: .systemRomanKana, correction: .typo, value: "a")
        )
        if let index = graph.nodes.firstIndex(where: {$0.value == "a"}) {
            let indices = graph.allowedPrevIndex[index, default: .init()]
            XCTAssertEqual(indices.count, 1)
            XCTAssertEqual(
                indices.first,
                graph.nodes.firstIndex(where: {$0.value == "t" && $0.inputElementsRange == .startIndex(0)})
            )
        } else {
            XCTAssertThrowsError("Should not be nil")
        }
    }
}
