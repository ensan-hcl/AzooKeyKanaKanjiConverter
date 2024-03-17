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
    func testBuildSimpleDirectInput() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "あ", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct),
            .init(character: "う", inputStyle: .direct)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(inputGraph.nodes.count, 4) // Root nodes
    }
    func testBuildSimpleDirectInput_あかう() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "あ", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct),
            .init(character: "う", inputStyle: .direct)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(inputGraph.nodes.count, 5) // Root nodes
    }

    func testBuildSimpleDirectInput_たいか() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "た", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(inputGraph.nodes.count, 5) // Root nodes
    }

    func testBuildSimpleRoman2KanaInput_1文字だけ() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "i", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", inputElementsRange: .range(0, 1), correction: .none)
        )
    }
    func testBuildSimpleRoman2KanaInput_2文字_it() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t"}),
            .init(character: "t", inputElementsRange: .range(1, 2), correction: .none)
        )
    }
    func testBuildSimpleRoman2KanaInput_3文字_ita() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .range(1, 3), correction: .none)
        )
    }
    func testBuildSimpleRoman2KanaInput_4文字_sits() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "し"}),
            .init(character: "し", inputElementsRange: .range(0, 2), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t" && !$0.correction.isTypo}),
            .init(character: "t", inputElementsRange: .range(2, 3), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .range(2, 4), correction: .typo)
        )
    }
    func testBuildSimpleRoman2KanaInput_3文字_its() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .range(1, 2)}),
            .init(character: "t", inputElementsRange: .range(1, 2), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "s"}),
            .init(character: "s", inputElementsRange: .range(2, 3), correction: .none)
        )
        // 消える
        XCTAssertNil(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .startIndex(1)})
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .range(1, 3), correction: .typo)
        )
    }
    func testBuildSimpleRoman2KanaInput_4文字_itsa() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertNil(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .range(1, 2)})
        )
        XCTAssertNil(
            inputGraph.nodes.first(where: {$0.character == "s"})
        )
        XCTAssertNil(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .startIndex(1)})
        )
        // groupIdの制約により、「た→あ」のみが許される遷移になる
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .range(1, 3), correction: .typo)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "あ"}),
            .init(character: "あ", inputElementsRange: .range(3, 4), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "つ"}),
            .init(character: "つ", inputElementsRange: .startIndex(1), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "ぁ"}),
            .init(character: "ぁ", inputElementsRange: .endIndex(4), correction: .none)
        )
        // 「さ」の生成は許されない
        XCTAssertNil(inputGraph.nodes.first(where: {$0.character == "さ"}))
    }

    func testBuildSimpleRoman2KanaInput_7文字_youshou() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "y", inputStyle: .roman2kana),
            .init(character: "o", inputStyle: .roman2kana),
            .init(character: "u", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "h", inputStyle: .roman2kana),
            .init(character: "o", inputStyle: .roman2kana),
            .init(character: "u", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "よ"}),
            .init(character: "よ", inputElementsRange: .range(0, 2), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "う" && $0.inputElementsRange == .range(2, 3)}),
            .init(character: "う", inputElementsRange: .range(2, 3), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "し"}),
            .init(character: "し", inputElementsRange: .startIndex(3), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "ょ"}),
            .init(character: "ょ", inputElementsRange: .endIndex(6), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "う" && $0.inputElementsRange == .range(6, 7)}),
            .init(character: "う", inputElementsRange: .range(6, 7), correction: .none)
        )

    }

    func testBuildSimpleRoman2KanaInput_2文字_tt() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "っ"}),
            .init(character: "っ", inputElementsRange: .startIndex(0), correction: .none)
        )
        XCTAssertNil(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .range(0, 1)})
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .endIndex(2)}),
            .init(character: "t", inputElementsRange: .endIndex(2), correction: .none)
        )
    }
    func testBuildSimpleRoman2KanaInput_3文字_tta() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "っ"}),
            .init(character: "っ", inputElementsRange: .startIndex(0), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .endIndex(3), correction: .none)
        )
    }
    func testBuildSimpleRoman2KanaInput_3文字_nta() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "n", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "ん"}),
            .init(character: "ん", inputElementsRange: .startIndex(0), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .endIndex(3), correction: .none)
        )
    }
    func testBuildSimpleRoman2KanaInput_4文字_itta() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "っ"}),
            .init(character: "っ", inputElementsRange: .startIndex(1), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .endIndex(4), correction: .none)
        )
    }

    func testBuildSimpleRoman2KanaInput_5文字_sitsi() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "し"}),
            .init(character: "し", inputElementsRange: .range(0, 2), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .range(2, 4), correction: .typo)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", inputElementsRange: .range(4, 5), correction: .none)
        )

    }

    func testBuildSimpleRoman2KanaInput_3文字_tts() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "っ" && $0.correction == .none}),
            .init(character: "っ", inputElementsRange: .startIndex(0), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "っ" && $0.correction == .typo}),
            .init(character: "っ", inputElementsRange: .startIndex(0), correction: .typo)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "s"}),
            .init(character: "s", inputElementsRange: .range(2, 3), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .endIndex(3), correction: .typo)
        )
        print(inputGraph)
    }

    func testBuildMixedInput_2文字_ts() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .direct)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t"}),
            .init(character: "t", inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertFalse(inputGraph.nodes.contains(.init(character: "た", inputElementsRange: .range(0, 2), correction: .typo)))
    }
}
