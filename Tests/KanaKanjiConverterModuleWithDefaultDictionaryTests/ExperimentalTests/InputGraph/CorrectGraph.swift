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
    var nodes: [Node] = []
    var inputElementsStartIndexToNodeIndices: [IndexSet] = []
    var inputElementsEndIndexToNodeIndices: [IndexSet] = [IndexSet(integer: 0)]

    struct Node: Equatable, Sendable {
        var inputElementsRange: Range<Int>
        var inputStyle: InputGraph.InputStyle.ID
        var correction: Correction
        var value: [Character]
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

    mutating func insert(_ node: consuming Node) {
        let index = nodes.count
        do {
            let startIndex = node.inputElementsRange.lowerBound
            if self.inputElementsStartIndexToNodeIndices.endIndex <= startIndex {
                self.inputElementsStartIndexToNodeIndices.append(contentsOf: Array(repeating: IndexSet(), count: startIndex - self.inputElementsStartIndexToNodeIndices.endIndex + 1))
            }
            self.inputElementsStartIndexToNodeIndices[startIndex].insert(index)
        }
        do {
            let endIndex = node.inputElementsRange.upperBound
            if self.inputElementsEndIndexToNodeIndices.endIndex <= endIndex {
                self.inputElementsEndIndexToNodeIndices.append(contentsOf: Array(repeating: IndexSet(), count: endIndex - self.inputElementsEndIndexToNodeIndices.endIndex + 1))
            }
            self.inputElementsEndIndexToNodeIndices[endIndex].insert(index)
        }
        self.nodes.append(consume node)
    }

    static func build(input: [ComposingText.InputElement]) -> Self {
        var correctGraph = Self()
        for (index, item) in zip(input.indices, input) {
            correctGraph.insert(
                Node(
                    inputElementsRange: index ..< index + 1,
                    inputStyle: InputGraph.InputStyle(from: input[index].inputStyle).id,
                    correction: .none,
                    value: [item.character]
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
                inputStyleId: InputGraph.InputStyle.ID
            )
            var stack: [SearchItem] = [
                (correctPrefixTree, index, [], .all),
            ]
            while let (cNode, cIndex, cRoute, cInputStyleId) = stack.popLast() {
                guard cIndex < input.endIndex else {
                    continue
                }
                let inputStyleId = InputGraph.InputStyle(from: input[cIndex].inputStyle).id
                guard cInputStyleId.isCompatible(with: inputStyleId) else {
                    continue
                }
                if let nNode = cNode.find(key: input[cIndex].character) {
                    stack.append((nNode, cIndex + 1, cRoute + [input[cIndex].character], inputStyleId))
                    for value in nNode.value {
                        correctGraph.insert(
                            Node(
                                inputElementsRange: index ..< index + cRoute.count + 1,
                                inputStyle: inputStyleId,
                                correction: .typo,
                                value: Array(value)
                            )
                        )
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
            graph.nodes.first(where: {$0.value == ["あ"]}),
            .init(inputElementsRange: 0..<1, inputStyle: .systemFlickDirect, correction: .none, value: ["あ"])
        )
    }
    func testBuildSimpleDirectInputWithTypo() throws {
        let graph = CorrectGraph.build(input: [
            .init(character: "か", inputStyle: .direct)
        ])
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == ["か"]}),
            .init(inputElementsRange: 0..<1, inputStyle: .systemFlickDirect, correction: .none, value: ["か"])
        )
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == ["が"]}),
            .init(inputElementsRange: 0..<1, inputStyle: .systemFlickDirect, correction: .typo, value: ["が"])
        )
    }
    func testBuildSimpleRomanInput() throws {
        let graph = CorrectGraph.build(input: [
            .init(character: "k", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana)
        ])
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == ["k"]}),
            .init(inputElementsRange: 0..<1, inputStyle: .systemRomanKana, correction: .none, value: ["k"])
        )
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == ["a"]}),
            .init(inputElementsRange: 1..<2, inputStyle: .systemRomanKana, correction: .none, value: ["a"])
        )
    }
    func testBuildSimpleRomanInputWithTypo() throws {
        let graph = CorrectGraph.build(input: [
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana)
        ])
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == ["t"]}),
            .init(inputElementsRange: 0..<1, inputStyle: .systemRomanKana, correction: .none, value: ["t"])
        )
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == ["s"]}),
            .init(inputElementsRange: 1..<2, inputStyle: .systemRomanKana, correction: .none, value: ["s"])
        )
        XCTAssertEqual(
            graph.nodes.first(where: {$0.value == ["t", "a"]}),
            .init(inputElementsRange: 0..<2, inputStyle: .systemRomanKana, correction: .typo, value: ["t", "a"])
        )
    }
}
