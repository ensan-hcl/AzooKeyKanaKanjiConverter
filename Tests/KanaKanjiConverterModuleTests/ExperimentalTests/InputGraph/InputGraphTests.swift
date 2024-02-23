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

    func testBuild() throws {
        do {
            let graph = InputGraph.build(input: [
                .init(character: "あ", inputStyle: .direct),
                .init(character: "い", inputStyle: .direct),
                .init(character: "う", inputStyle: .direct)
            ])
            XCTAssertEqual(graph.nodes.count, 4) // Root nodes
        }
        do {
            let graph = InputGraph.build(input: [
                .init(character: "あ", inputStyle: .direct),
                .init(character: "か", inputStyle: .direct),
                .init(character: "う", inputStyle: .direct)
            ])
            XCTAssertEqual(graph.nodes.count, 5) // Root nodes
        }
        do {
            let graph = InputGraph.build(input: [
                .init(character: "i", inputStyle: .roman2kana),
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "a", inputStyle: .roman2kana),
            ])
            XCTAssertEqual(graph.nodes.count, 3) // Root nodes
        }
        do {
            let graph = InputGraph.build(input: [
                .init(character: "i", inputStyle: .roman2kana),
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "s", inputStyle: .roman2kana),
            ])
            XCTAssertEqual(graph.nodes.count, 5) // Root nodes
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "い"}),
                .init(character: "い", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 1), correction: .none)
            )
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "t"}),
                .init(character: "t", displayedTextRange: .range(1, 2), inputElementsRange: .range(1, 2), correction: .none)
            )
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "s"}),
                .init(character: "s", displayedTextRange: .range(2, 3), inputElementsRange: .range(2, 3), correction: .none)
            )
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "た"}),
                .init(character: "た", displayedTextRange: .range(1, 2), inputElementsRange: .range(1, 3), correction: .typo)
            )
        }
        do {
            // ts->taの誤字訂正が存在
            let graph = InputGraph.build(input: [
                .init(character: "i", inputStyle: .roman2kana),
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "s", inputStyle: .roman2kana),
                .init(character: "a", inputStyle: .roman2kana),
            ])
            XCTAssertEqual(graph.nodes.count, 6) // Root nodes
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "い"}),
                .init(character: "い", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 1), correction: .none)
            )
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "た"}),
                .init(character: "た", displayedTextRange: .range(1, 2), inputElementsRange: .range(1, 3), correction: .typo)
            )
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "ぁ"}),
                .init(character: "ぁ", displayedTextRange: .range(2, 3), inputElementsRange: .endIndex(4), correction: .none)
            )
        }
        do {
            // ts->taの誤字訂正は入力方式を跨いだ場合は発火しない
            let graph = InputGraph.build(input: [
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "s", inputStyle: .direct),
            ])
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "t"}),
                .init(character: "t", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 1), correction: .none)
            )
            XCTAssertFalse(graph.nodes.contains(.init(character: "た", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 2), correction: .typo)))
        }
        do {
            // tt→っt
            let graph = InputGraph.build(input: [
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "t", inputStyle: .roman2kana),
            ])
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "っ"}),
                .init(character: "っ", displayedTextRange: .range(0, 1), inputElementsRange: .startIndex(0), correction: .none)
            )
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "t"}),
                .init(character: "t", displayedTextRange: .range(1, 2), inputElementsRange: .endIndex(2), correction: .none)
            )
        }
        do {
            // tt→っt
            let graph = InputGraph.build(input: [
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "a", inputStyle: .roman2kana),
            ])
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "っ"}),
                .init(character: "っ", displayedTextRange: .range(0, 1), inputElementsRange: .startIndex(0), correction: .none)
            )
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "た"}),
                .init(character: "た", displayedTextRange: .range(1, 2), inputElementsRange: .endIndex(3), correction: .none)
            )
        }
        do {
            // nt→んt
            let graph = InputGraph.build(input: [
                .init(character: "n", inputStyle: .roman2kana),
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "a", inputStyle: .roman2kana),
            ])
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "ん"}),
                .init(character: "ん", displayedTextRange: .range(0, 1), inputElementsRange: .startIndex(0), correction: .none)
            )
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "た"}),
                .init(character: "た", displayedTextRange: .range(1, 2), inputElementsRange: .endIndex(3), correction: .none)
            )
        }
        do {
            // t
            // tt→っt
            // っts→った (
            // FIXME: 興味深いテストケースだが実装が重いので保留
            /*
            let graph = InputGraph.build(input: [
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "s", inputStyle: .roman2kana),
            ])
            print(graph)
            XCTAssertEqual(
                graph.nodes.first(where: {$0.character == "た"}),
                .init(character: "た", displayedTextRange: .range(2, 3), inputElementsRange: .endIndex(4), correction: .none)
            )
             */
        }
    }
}
