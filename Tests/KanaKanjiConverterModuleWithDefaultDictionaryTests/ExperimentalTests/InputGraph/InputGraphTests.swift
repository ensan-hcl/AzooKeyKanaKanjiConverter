//
//  InputGraphTests.swift
//
//
//  Created by miwa on 2024/02/21.
//

import Foundation

@testable import KanaKanjiConverterModule
import XCTest


final class InputGraphTests: XCTestCase {
    func testInsert() throws {
        var graph = InputGraph()
        let node1 = InputGraph.Node(character: "a", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 1))
        let node2 = InputGraph.Node(character: "b", displayedTextRange: .range(1, 2), inputElementsRange: .range(1, 2))
        graph.insert(node1)
        graph.insert(node2)
        XCTAssertEqual(graph.next(for: node1), [node2])
        XCTAssertEqual(graph.prev(for: node2), [node1])
    }

    func testBuildSimpleDirectInput() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "あ", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct),
            .init(character: "う", inputStyle: .direct)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(inputGraph.nodes.count, 4) // Root nodes
    }
    func testBuildSimpleDirectInput_typoあり() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "あ", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct),
            .init(character: "う", inputStyle: .direct)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(inputGraph.nodes.count, 5) // Root nodes
    }
    func testBuildSimpleRoman2KanaInput_1文字だけ() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "i", inputStyle: .roman2kana),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertNil(
            inputGraph.nodes.first(where: {$0.character == "i"})
        )
        XCTAssertEqual(inputGraph.nodes.count, 2) // Root nodes
    }
    func testBuildSimpleRoman2KanaInput_2文字_it() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t"}),
            .init(character: "t", displayedTextRange: .range(1, 2), inputElementsRange: .range(1, 2), correction: .none)
        )
        print(inputGraph)
    }
    func testBuildSimpleRoman2KanaInput_3文字_ita() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t"}),
            .init(character: "t", displayedTextRange: .range(1, 2), inputElementsRange: .range(1, 2), correction: .none, isReplaced: true)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", displayedTextRange: .range(1, 2), inputElementsRange: .range(1, 3), correction: .none)
        )
        print(inputGraph)
    }
    func testBuildSimpleRoman2KanaInput_4文字_sits() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "し" && $0.displayedTextRange == .range(0, 1)}),
            .init(character: "し", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 2), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "s"}),
            .init(character: "s", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 1), correction: .none, isReplaced: true)
        )
        // [s]のノードを消していないため、displayedTextIndex側で拾ってしまってエラー
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", displayedTextRange: .range(1, 2), inputElementsRange: .range(2, 4), correction: .typo)
        )
        print(inputGraph)
    }
    func testBuildSimpleRoman2KanaInput_3文字_its() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .range(1, 2)}),
            .init(character: "t", displayedTextRange: .range(1, 2), inputElementsRange: .range(1, 2), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "s"}),
            .init(character: "s", displayedTextRange: .range(2, 3), inputElementsRange: .range(2, 3), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .startIndex(1)}),
            .init(character: "t", displayedTextRange: .range(1, 2), inputElementsRange: .startIndex(1), groupId: 0, correction: .typo)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", displayedTextRange: .range(1, 2), inputElementsRange: .range(1, 3), correction: .typo)
        )
        print(inputGraph)
    }
    func testBuildSimpleRoman2KanaInput_4文字_itsa() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .range(1, 2)}),
            .init(character: "t", displayedTextRange: .range(1, 2), inputElementsRange: .range(1, 2), correction: .none, isReplaced: true)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "s"}),
            .init(character: "s", displayedTextRange: .range(2, 3), inputElementsRange: .range(2, 3), correction: .none, isReplaced: true)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .startIndex(1)}),
            .init(character: "t", displayedTextRange: .range(1, 2), inputElementsRange: .startIndex(1), groupId: 0, correction: .typo)
        )
        // groupIdの制約により、「た→あ」のみが許される遷移になる
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", displayedTextRange: .range(1, 2), inputElementsRange: .range(1, 3), groupId: 1, correction: .typo)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "あ"}),
            .init(character: "あ", displayedTextRange: .range(2, 3), inputElementsRange: .range(3, 4), groupId: 1, correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "つ"}),
            .init(character: "つ", displayedTextRange: .range(1, 2), inputElementsRange: .startIndex(1), groupId: 2, correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "ぁ"}),
            .init(character: "ぁ", displayedTextRange: .range(2, 3), inputElementsRange: .endIndex(4), groupId: 2, correction: .none)
        )
        // 「さ」の生成は許されない
        XCTAssertNil(inputGraph.nodes.first(where: {$0.character == "さ"}))
    }

    func testBuildMixedInput_2文字_ts() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .direct),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t"}),
            .init(character: "t", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertFalse(inputGraph.nodes.contains(.init(character: "た", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 2), correction: .typo)))
    }
    func testBuildMixedInput_2文字_tt() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "っ"}),
            .init(character: "っ", displayedTextRange: .range(0, 1), inputElementsRange: .startIndex(0), groupId: 0, correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.groupId != nil}),
            .init(character: "t", displayedTextRange: .range(1, 2), inputElementsRange: .endIndex(2), groupId: 0, correction: .none)
        )
    }
    func testBuildMixedInput_3文字_tta() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "っ"}),
            .init(character: "っ", displayedTextRange: .range(0, 1), inputElementsRange: .startIndex(0), groupId: 0, correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            // FIXME: 「た」のgroupIdは0だと嬉しい
            .init(character: "た", displayedTextRange: .range(1, 2), inputElementsRange: .endIndex(3), groupId: nil, correction: .none)
        )
    }
    func testBuildMixedInput_3文字_nta() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "n", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "ん"}),
            .init(character: "ん", displayedTextRange: .range(0, 1), inputElementsRange: .startIndex(0), groupId: 0, correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", displayedTextRange: .range(1, 2), inputElementsRange: .endIndex(3), groupId: nil, correction: .none)
        )
    }
    func testBuildMixedInput_4文字_itta() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 1), groupId: nil, correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "っ"}),
            .init(character: "っ", displayedTextRange: .range(1, 2), inputElementsRange: .startIndex(1), groupId: 0, correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            // FIXME: 「た」のgroupIdは0だと嬉しい
            .init(character: "た", displayedTextRange: .range(2, 3), inputElementsRange: .endIndex(4), groupId: nil, correction: .none)
        )
    }
    func testBuildMixedInput_3文字_tts() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "っ" && $0.correction == .none}),
            .init(character: "っ", displayedTextRange: .range(0, 1), inputElementsRange: .startIndex(0), groupId: 2, correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            // FIXME: 「た」のgroupIdは0だと嬉しい
            .init(character: "た", displayedTextRange: .range(1, 2), inputElementsRange: .range(1, 3), groupId: nil, correction: .typo)
        )
    }

}
