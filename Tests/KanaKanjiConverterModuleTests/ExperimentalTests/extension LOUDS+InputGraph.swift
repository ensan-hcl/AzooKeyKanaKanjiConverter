//
//  extension LOUDS+InputGraph.swift
//
//
//  Created by miwa on 2024/02/22.
//

import XCTest
import Foundation
@testable import KanaKanjiConverterModule

extension LOUDS {
    func byfixNodeIndices(_ inputGraph: InputGraph, char2id: (Character) -> UInt8?) -> IndexSet {
        var indexSet = IndexSet(integer: 1)
        typealias SearchItem = (
            node: InputGraph.Node,
            lastNodeIndex: Int
        )
        var stack: [SearchItem] = inputGraph.next(for: inputGraph.root).map { ($0, 1) }
        while let (cNode, cNodeIndex) = stack.popLast() {
            // nextNodesを探索
            if let charId = char2id(cNode.character), let nodeIndex = self.searchCharNodeIndex(from: cNodeIndex, char: charId) {
                indexSet.insert(nodeIndex)
                stack.append(contentsOf: inputGraph.next(for: cNode).map { ($0, nodeIndex) })
            } else {
                continue
            }
        }
        return indexSet
    }
}

final class InputGraphBasedLOUDSTests: XCTestCase {
    static var resourceURL = Bundle.module.resourceURL!.standardizedFileURL.appendingPathComponent("DictionaryMock", isDirectory: true)
    func requestOptions() -> ConvertRequestOptions {
        var options: ConvertRequestOptions = .default
        options.dictionaryResourceURL = Self.resourceURL
        return options
    }

    func loadCharIDs() -> [Character: UInt8] {
        do {
            let string = try String(contentsOf: Self.resourceURL.appendingPathComponent("louds/charID.chid", isDirectory: false), encoding: String.Encoding.utf8)
            return [Character: UInt8](uniqueKeysWithValues: string.enumerated().map {($0.element, UInt8($0.offset))})
        } catch {
            print("ファイルが見つかりませんでした")
            return [:]
        }
    }

    func testByfixNodeIndices() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let charIDs = loadCharIDs()
        let louds = LOUDS.load("シ", option: requestOptions())
        XCTAssertNotNil(louds)
        guard let louds else { return }
        do {
            let inputGraph = InputGraph.build(input: [
                .init(character: "し", inputStyle: .direct),
                .init(character: "か", inputStyle: .direct),
                .init(character: "い", inputStyle: .direct),
            ])
            let nodeIndices = louds.byfixNodeIndices(inputGraph, char2id: {charIDs[$0.toKatakana()]})
            let dicdata: [DicdataElement] = dicdataStore.getDicdataFromLoudstxt3(identifier: "シ", indices: nodeIndices)
            // シ
            XCTAssertTrue(dicdata.contains {$0.word == "死"})
            // シカ
            XCTAssertTrue(dicdata.contains {$0.word == "鹿"})
            XCTAssertTrue(dicdata.contains {$0.word == "歯科"})
            // シガ
            XCTAssertTrue(dicdata.contains {$0.word == "滋賀"})
            // シカイ
            XCTAssertTrue(dicdata.contains {$0.word == "司会"})
            XCTAssertTrue(dicdata.contains {$0.word == "視界"})
            XCTAssertTrue(dicdata.contains {$0.word == "死界"})
            // シガイ
            XCTAssertTrue(dicdata.contains {$0.word == "市外"})
            XCTAssertTrue(dicdata.contains {$0.word == "市街"})
            XCTAssertTrue(dicdata.contains {$0.word == "死骸"})
        }
        do {
            // ts -> ta
            let inputGraph = InputGraph.build(input: [
                .init(character: "s", inputStyle: .roman2kana),
                .init(character: "i", inputStyle: .roman2kana),
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "s", inputStyle: .roman2kana),
                .init(character: "i", inputStyle: .roman2kana),
            ])
            let nodeIndices = louds.byfixNodeIndices(inputGraph, char2id: {charIDs[$0.toKatakana()]})
            let dicdata: [DicdataElement] = dicdataStore.getDicdataFromLoudstxt3(identifier: "シ", indices: nodeIndices)
            // シ
            XCTAssertTrue(dicdata.contains {$0.word == "死"})
            // [シツ]ィ
            XCTAssertTrue(dicdata.contains {$0.word == "質"})
            XCTAssertTrue(dicdata.contains {$0.word == "室"})
            // シタ
            XCTAssertTrue(dicdata.contains {$0.word == "下"})
            XCTAssertTrue(dicdata.contains {$0.word == "舌"})
            // シタイ
            XCTAssertTrue(dicdata.contains {$0.word == "死体"})
            XCTAssertTrue(dicdata.contains {$0.word == "肢体"})
        }
        do {
            // 「しっ」の候補が存在するかどうかを確認
            let inputGraph = InputGraph.build(input: [
                .init(character: "s", inputStyle: .roman2kana),
                .init(character: "i", inputStyle: .roman2kana),
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "a", inputStyle: .roman2kana),
                .init(character: "i", inputStyle: .roman2kana),
            ])
            print(inputGraph)
            let nodeIndices = louds.byfixNodeIndices(inputGraph, char2id: {return charIDs[$0.toKatakana()]})
            let dicdata: [DicdataElement] = dicdataStore.getDicdataFromLoudstxt3(identifier: "シ", indices: nodeIndices)
            // シ
            XCTAssertTrue(dicdata.contains {$0.word == "死"})
            // シッ
            XCTAssertTrue(dicdata.contains {$0.word == "知っ"})
            XCTAssertTrue(dicdata.contains {$0.word == "しっ"})
            // シッタ
            XCTAssertTrue(dicdata.contains {$0.word == "叱咤"})
            // シッタイ
            XCTAssertTrue(dicdata.contains {$0.word == "失態"})
        }
    }
}
