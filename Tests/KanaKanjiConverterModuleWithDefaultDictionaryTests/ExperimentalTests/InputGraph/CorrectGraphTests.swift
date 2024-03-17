//
//  CorrectGraphTests.swift
//
//
//  Created by miwa on 2024/02/21.
//

import Foundation

@testable import KanaKanjiConverterModule
import XCTest

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
            .init(character: "う", inputStyle: .direct)
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
