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
            .init(value: "あ", inputStyle: .systemFlickDirect),
            .init(value: "い", inputStyle: .systemFlickDirect),
            .init(value: "う", inputStyle: .systemFlickDirect)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
        XCTAssertEqual(inputGraph.nodes.count, 4) // Root nodes
    }
    func testBuildSimpleDirectInput_あかう() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(value: "あ", inputStyle: .systemFlickDirect),
            .init(value: "か", inputStyle: .systemFlickDirect),
            .init(value: "う", inputStyle: .systemFlickDirect)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
        XCTAssertEqual(inputGraph.nodes.count, 5) // Root nodes
    }

    func testBuildSimpleDirectInput_たいか() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(value: "た", inputStyle: .systemFlickDirect),
            .init(value: "い", inputStyle: .systemFlickDirect),
            .init(value: "か", inputStyle: .systemFlickDirect)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "だ"}),
            .init(character: "だ", inputElementsRange: .range(0, 1), correction: .typo(weight: -3))
        )
    }

    func testBuildSimpleRoman2KanaInput_1文字だけ() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(value: "i", inputStyle: .systemRomanKana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", inputElementsRange: .range(0, 1), correction: .none)
        )
    }
    func testBuildSimpleRoman2KanaInput_2文字_it() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(value: "i", inputStyle: .systemRomanKana),
            .init(value: "t", inputStyle: .systemRomanKana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
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
            .init(value: "i", inputStyle: .systemRomanKana),
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "a", inputStyle: .systemRomanKana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
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
            .init(value: "s", inputStyle: .systemRomanKana),
            .init(value: "i", inputStyle: .systemRomanKana),
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "s", inputStyle: .systemRomanKana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
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
            .init(character: "た", inputElementsRange: .range(2, 4), correction: .typo(weight: -3))
        )
    }
    func testBuildSimpleRoman2KanaInput_3文字_its() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(value: "i", inputStyle: .systemRomanKana),
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "s", inputStyle: .systemRomanKana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
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
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .startIndex(1)}),
            .init(character: "t", inputElementsRange: .startIndex(1), correction: .typo(weight: -3/2))
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .range(1, 3), correction: .typo(weight: -3))
        )
    }
    func testBuildSimpleRoman2KanaInput_4文字_itsa() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(value: "i", inputStyle: .systemRomanKana),
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "s", inputStyle: .systemRomanKana),
            .init(value: "a", inputStyle: .systemRomanKana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
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
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .startIndex(1)}),
            .init(character: "t", inputElementsRange: .startIndex(1), correction: .typo(weight: -3/2))
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .range(1, 3), correction: .typo(weight: -3))
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
            .init(value: "y", inputStyle: .systemRomanKana),
            .init(value: "o", inputStyle: .systemRomanKana),
            .init(value: "u", inputStyle: .systemRomanKana),
            .init(value: "s", inputStyle: .systemRomanKana),
            .init(value: "h", inputStyle: .systemRomanKana),
            .init(value: "o", inputStyle: .systemRomanKana),
            .init(value: "u", inputStyle: .systemRomanKana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
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
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "t", inputStyle: .systemRomanKana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "っ"}),
            .init(character: "っ", inputElementsRange: .startIndex(0), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .range(0, 1)}),
            .init(character: "t", inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .range(1, 2)}),
            .init(character: "t", inputElementsRange: .range(1, 2), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t" && $0.inputElementsRange == .endIndex(2)}),
            .init(character: "t", inputElementsRange: .endIndex(2), correction: .none)
        )
    }
    func testBuildSimpleRoman2KanaInput_3文字_tta() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "a", inputStyle: .systemRomanKana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "っ"}),
            .init(character: "っ", inputElementsRange: .startIndex(0), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .endIndex(3), correction: .none)
        )
        // [t(1)t(2) → っt(3)]なので、t(2)に対してaがついて「た」が生じてはならない。
        XCTAssertEqual(inputGraph.nodes.filter({$0.character == "た"}).count, 1)
    }
    func testBuildSimpleRoman2KanaInput_3文字_nta() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(value: "n", inputStyle: .systemRomanKana),
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "a", inputStyle: .systemRomanKana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
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
            .init(value: "i", inputStyle: .systemRomanKana),
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "a", inputStyle: .systemRomanKana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
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
            .init(value: "s", inputStyle: .systemRomanKana),
            .init(value: "i", inputStyle: .systemRomanKana),
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "s", inputStyle: .systemRomanKana),
            .init(value: "i", inputStyle: .systemRomanKana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "し"}),
            .init(character: "し", inputElementsRange: .range(0, 2), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .range(2, 4), correction: .typo(weight: -3))
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "い"}),
            .init(character: "い", inputElementsRange: .range(4, 5), correction: .none)
        )

    }

    func testBuildSimpleRoman2KanaInput_3文字_tts() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "s", inputStyle: .systemRomanKana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "っ" && $0.correction == .none}),
            .init(character: "っ", inputElementsRange: .startIndex(0), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "っ" && $0.correction == .typo(weight: -3/2)}),
            .init(character: "っ", inputElementsRange: .startIndex(0), correction: .typo(weight: -3/2))
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "s"}),
            .init(character: "s", inputElementsRange: .range(2, 3), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "た"}),
            .init(character: "た", inputElementsRange: .endIndex(3), correction: .typo(weight: -3))
        )
    }

    func testBuildSimpleRoman2KanaInput_4文字_tysa() throws {
        // ちゃあ/tyさ
        let correctGraph = CorrectGraph.build(input: [
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "y", inputStyle: .systemRomanKana),
            .init(value: "s", inputStyle: .systemRomanKana),
            .init(value: "a", inputStyle: .systemRomanKana)
        ])
        // cleanで壊れる
        let inputGraph = InputGraph.build(input: correctGraph).clean()
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t"}),
            .init(character: "t", inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "y" && !$0.correction.isTypo}),
            .init(character: "y", inputElementsRange: .range(1, 2), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "さ"}),
            .init(character: "さ", inputElementsRange: .range(2, 4), correction: .none)
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "ち"}),
            .init(character: "ち", inputElementsRange: .startIndex(0), correction: .typo(weight: -3))
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "ゃ" && $0.correction == .typo(weight: -3)}),
            .init(character: "ゃ", inputElementsRange: .endIndex(3), correction: .typo(weight: -3))
        )
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "あ"}),
            .init(character: "あ", inputElementsRange: .range(3, 4), correction: .none)
        )
    }

    func testBuildMixedInput_2文字_ts() throws {
        let correctGraph = CorrectGraph.build(input: [
            .init(value: "t", inputStyle: .systemRomanKana),
            .init(value: "s", inputStyle: .systemFlickDirect)
        ])
        let inputGraph = InputGraph.build(input: correctGraph).clean()
        XCTAssertEqual(
            inputGraph.nodes.first(where: {$0.character == "t"}),
            .init(character: "t", inputElementsRange: .range(0, 1), correction: .none)
        )
        XCTAssertFalse(inputGraph.nodes.contains(.init(character: "た", inputElementsRange: .range(0, 2), correction: .typo(weight: -3))))
    }
}
