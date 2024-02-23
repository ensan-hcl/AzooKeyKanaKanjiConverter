//
//  LookupGraphTests.swift
//
//
//  Created by miwa on 2024/02/23.
//

import XCTest
import Foundation
@testable import KanaKanjiConverterModule

struct LookupGraph: InputGraphProtocol {
    struct Node: Equatable, InputGraphNodeProtocol {
        var character: Character
        var charId: UInt8
        var loudsNodeIndices: Set<Int> = []
        var displayedTextRange: InputGraphStructure.Range
        var inputElementsRange: InputGraphStructure.Range
        var correction: InputGraph.Correction = .none
    }

    var nodes: [Node] = [
        // root node
        Node(character: "\0", charId: 0x00, displayedTextRange: .endIndex(0), inputElementsRange: .endIndex(0))
    ]

    var structure: InputGraphStructure = InputGraphStructure()

    static func build(input: InputGraph, character2CharId: (Character) -> UInt8) -> Self {
        let nodes = input.nodes.map {
            Node(character: $0.character, charId: character2CharId($0.character), displayedTextRange: $0.displayedTextRange, inputElementsRange: $0.inputElementsRange, correction: $0.correction)
        }
        return Self(nodes: nodes, structure: input.structure)
    }
}


extension LOUDS {
    func byfixNodeIndices(_ lookupGraph: LookupGraph, startGraphNodeIndex: Int = 0) -> (IndexSet, [Int: [(displayedTextEndIndex: Int?, inputElementsEndIndex: Int?)]]) {
        var indexSet = IndexSet(integer: 1)
        // loudsのノードとLookupGraphのノードの対応を取るための辞書
        var loudsNodeIndex2GraphNodeEndIndices: [Int: [(displayedTextEndIndex: Int?, inputElementsEndIndex: Int?)]] = [:]
        typealias SearchItem = (
            node: LookupGraph.Node,
            nodeIndex: Int,
            lastLoudsNodeIndex: Int
        )
        var stack: [SearchItem] = lookupGraph.nextIndices(for: lookupGraph.nodes[startGraphNodeIndex]).map { (lookupGraph.nodes[$0], $0, 1) }
        while let (cNode, cNodeIndex, cLastLoudsNodeIndex) = stack.popLast() {
            // nextNodesを探索
            if let loudsNodeIndex = self.searchCharNodeIndex(from: cLastLoudsNodeIndex, char: cNode.charId) {
                loudsNodeIndex2GraphNodeEndIndices[loudsNodeIndex, default: []].append((cNode.displayedTextRange.endIndex, cNode.inputElementsRange.endIndex))
                indexSet.insert(loudsNodeIndex)
                stack.append(contentsOf: lookupGraph.nextIndices(for: cNode).map { (lookupGraph.nodes[$0], $0, loudsNodeIndex) })
            } else {
                continue
            }
        }
        return (indexSet, loudsNodeIndex2GraphNodeEndIndices)
    }
}

extension DicdataStore {
    func buildConvertGraph(inputGraph: consuming InputGraph, option: ConvertRequestOptions) -> ConvertGraph {
        // FIXME: character2CharIdを書き直す
        let lookupGraph = LookupGraph.build(input: consume inputGraph, character2CharId: {_ in 0})
        var stack: [Int] = Array(lookupGraph.nextIndices(for: lookupGraph.root))
        var graphNodeIndex2LatticeNodes: [Int: [ConvertGraph.LatticeNode]] = [:]
        while let graphNodeIndex = stack.popLast() {
            let graphNode = lookupGraph.nodes[graphNodeIndex]
            guard let louds = self.loadLOUDS(identifier: String(graphNode.character)) else {
                continue
            }
            let (loudsNodeIndices, loudsNodeIndex2GraphEndIndices) = louds.byfixNodeIndices(lookupGraph, startGraphNodeIndex: graphNodeIndex)
            let dicdataWithIndex: [(loudsNodeIndex: Int, dicdata: [DicdataElement])] = self.getDicdataFromLoudstxt3(identifier: String(graphNode.character), indices: loudsNodeIndices, option: option)
            var latticeNodes: [ConvertGraph.LatticeNode] = []
            for (loudsNodeIndex, dicdata) in dicdataWithIndex {
                for endIndex in loudsNodeIndex2GraphEndIndices[loudsNodeIndex, default: []] {
                    let displayedTextRange: InputGraphStructure.Range = switch (graphNode.displayedTextRange.startIndex, endIndex.displayedTextEndIndex) {
                    case let (s?, e?): .range(s, e)
                    case (let s?, nil): .startIndex(s)
                    case (nil, let e?): .endIndex(e)
                    case (nil, nil): .unknown
                    }
                    let inputElementsRange: InputGraphStructure.Range = switch (graphNode.inputElementsRange.startIndex, endIndex.inputElementsEndIndex) {
                    case let (s?, e?): .range(s, e)
                    case (let s?, nil): .startIndex(s)
                    case (nil, let e?): .endIndex(e)
                    case (nil, nil): .unknown
                    }
                    latticeNodes.append(contentsOf: dicdata.map {
                        .init(data: $0, displayedTextRange: displayedTextRange, inputElementsRange: inputElementsRange)
                    })
                }
            }
            // FIXME: ここを埋める
            graphNodeIndex2LatticeNodes[graphNodeIndex] = latticeNodes
        }
        return ConvertGraph.build(input: consume lookupGraph, nodeIndex2LatticeNode: graphNodeIndex2LatticeNodes)
    }

    func getDicdataFromLoudstxt3(identifier: String, indices: some Sequence<Int>, option: ConvertRequestOptions) -> [(loudsNodeIndex: Int, dicdata: [DicdataElement])] {
        // split = 2048
        let dict = [Int: [Int]].init(grouping: indices, by: {$0 >> 11})
        var data: [(loudsNodeIndex: Int, dicdata: [DicdataElement])] = []
        for (key, value) in dict {
            // FIXME: use local option
            data.append(contentsOf: LOUDS.getDataForLoudstxt3(identifier + "\(key)", indices: value.map {$0 & 2047}, option: option))
        }
        return data
    }
}

final class LookupGraphTests: XCTestCase {
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
            let lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: {charIDs[$0.toKatakana()] ?? 0x00})
            let (loudsNodeIndices, loudsNodeIndex2GraphNodeEndIndices) = louds.byfixNodeIndices(lookupGraph)
            let dicdataWithIndex = dicdataStore.getDicdataFromLoudstxt3(identifier: "シ", indices: loudsNodeIndices, option: requestOptions())
            let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
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
            let lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: {charIDs[$0.toKatakana()] ?? 0x00})
            let (loudsNodeIndices, loudsNodeIndex2GraphNodeEndIndices) = louds.byfixNodeIndices(lookupGraph)
            let dicdataWithIndex = dicdataStore.getDicdataFromLoudstxt3(identifier: "シ", indices: loudsNodeIndices, option: requestOptions())
            let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
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
            let lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: {charIDs[$0.toKatakana()] ?? 0x00})
            let (loudsNodeIndices, loudsNodeIndex2GraphNodeEndIndices) = louds.byfixNodeIndices(lookupGraph)
            let dicdataWithIndex = dicdataStore.getDicdataFromLoudstxt3(identifier: "シ", indices: loudsNodeIndices, option: requestOptions())
            let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
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
