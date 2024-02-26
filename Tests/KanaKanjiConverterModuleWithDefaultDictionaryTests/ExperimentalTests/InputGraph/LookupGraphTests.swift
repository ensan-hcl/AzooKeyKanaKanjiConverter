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
        var correction: CorrectGraph.Correction = .none
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
            nodeIndex: Int,
            lastLoudsNodeIndex: Int
        )
        var stack: [SearchItem] = [(startGraphNodeIndex, 1)]
        while let (cNodeIndex, cLastLoudsNodeIndex) = stack.popLast() {
            let cNode = lookupGraph.nodes[cNodeIndex]
            // nextNodesを探索
            if let loudsNodeIndex = self.searchCharNodeIndex(from: cLastLoudsNodeIndex, char: cNode.charId) {
                loudsNodeIndex2GraphNodeEndIndices[loudsNodeIndex, default: []].append((cNode.displayedTextRange.endIndex, cNode.inputElementsRange.endIndex))
                indexSet.insert(loudsNodeIndex)
                var nextIndices = lookupGraph.nextIndices(for: cNode)
                nextIndices.formUnion(IndexSet(lookupGraph.structure.allowedNextIndex[cNodeIndex, default: []]))
                stack.append(contentsOf: nextIndices.compactMap { index in
                    let node = lookupGraph.nodes[index]
                    // endIndexをチェックする
                    // endIndexは単調増加である必要がある
                    if let cDisplayedTextEndIndex = cNode.displayedTextRange.endIndex,
                       let nDisplayedTextEndIndex = node.displayedTextRange.endIndex {
                        guard cDisplayedTextEndIndex < nDisplayedTextEndIndex else {
                            return nil
                        }
                    }
                    if let cInputElementsEndIndex = cNode.inputElementsRange.endIndex,
                       let nInputElementsEndIndex = node.inputElementsRange.endIndex {
                        guard cInputElementsEndIndex < nInputElementsEndIndex else {
                            return nil
                        }
                    }
                    return (index, loudsNodeIndex)
                })
            } else {
                continue
            }
        }
        return (indexSet, loudsNodeIndex2GraphNodeEndIndices)
    }
}

extension DicdataStore {
    func buildConvertGraph(inputGraph: consuming InputGraph, option: ConvertRequestOptions) -> ConvertGraph {
        let lookupGraph = LookupGraph.build(input: consume inputGraph, character2CharId: { self.character2charId($0.toKatakana()) } )
        var stack: [Int] = Array(lookupGraph.nextIndices(for: lookupGraph.root))
        var graphNodeIndex2LatticeNodes: [Int: [ConvertGraph.LatticeNode]] = [:]
        while let graphNodeIndex = stack.popLast() {
            let graphNode = lookupGraph.nodes[graphNodeIndex]
            guard let louds = self.loadLOUDS(identifier: String(graphNode.character.toKatakana())) else {
                continue
            }
            let (loudsNodeIndices, loudsNodeIndex2GraphEndIndices) = louds.byfixNodeIndices(lookupGraph, startGraphNodeIndex: graphNodeIndex)
            let dicdataWithIndex: [(loudsNodeIndex: Int, dicdata: [DicdataElement])] = self.getDicdataFromLoudstxt3(identifier: String(graphNode.character.toKatakana()), indices: loudsNodeIndices, option: option)
            var latticeNodes: [ConvertGraph.LatticeNode] = []
            for (loudsNodeIndex, dicdata) in dicdataWithIndex {
                for endIndex in loudsNodeIndex2GraphEndIndices[loudsNodeIndex, default: []] {
                    let displayedTextRange = InputGraphStructure.Range(startIndex: graphNode.displayedTextRange.startIndex, endIndex: endIndex.displayedTextEndIndex)
                    let inputElementsRange = InputGraphStructure.Range(startIndex: graphNode.inputElementsRange.startIndex, endIndex: endIndex.inputElementsEndIndex)
                    if graphNode.displayedTextRange.startIndex == 0 || graphNode.inputElementsRange.startIndex == 0 {
                        latticeNodes.append(contentsOf: dicdata.map {
                            .init(data: $0, displayedTextRange: displayedTextRange, inputElementsRange: inputElementsRange, prevs: [.BOSNode()])
                        })
                    } else {
                        latticeNodes.append(contentsOf: dicdata.map {
                            .init(data: $0, displayedTextRange: displayedTextRange, inputElementsRange: inputElementsRange)
                        })
                    }
                }
            }
            graphNodeIndex2LatticeNodes[graphNodeIndex] = latticeNodes
            stack.append(contentsOf: lookupGraph.nextIndices(for: graphNode))
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
    func requestOptions() -> ConvertRequestOptions {
        .withDefaultDictionary(requireJapanesePrediction: false, requireEnglishPrediction: false, keyboardLanguage: .ja_JP, learningType: .nothing, memoryDirectoryURL: URL(fileURLWithPath: ""), sharedContainerURL: URL(fileURLWithPath: ""), metadata: .init(appVersionString: "Test"))
    }

    func setup() -> (dicdataStore: DicdataStore, character2CharId: (Character) -> UInt8, louds_シ: LOUDS?) {
        let dicdataStore = DicdataStore(convertRequestOptions: requestOptions())
        let character2CharId: (Character) -> UInt8 = { dicdataStore.character2charId($0.toKatakana()) }
        let louds = LOUDS.load("シ", option: requestOptions())
        return (dicdataStore, character2CharId, louds)
    }

    func testByfixNodeIndices_しかい() throws {
        let values = setup()
        XCTAssertNotNil(values.louds_シ)
        guard let louds = values.louds_シ else { return }
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "し", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        let lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: values.character2CharId)
        let startNodeIndex = lookupGraph.nextIndices(for: lookupGraph.root).first(where: { lookupGraph.nodes[$0].character == "し" })
        XCTAssertNotNil(startNodeIndex)
        let (loudsNodeIndices, _) = louds.byfixNodeIndices(lookupGraph, startGraphNodeIndex: startNodeIndex ?? 0)
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "シ", indices: loudsNodeIndices, option: requestOptions())
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

    func testByfixNodeIndices_sittai() throws {
        let values = setup()
        XCTAssertNotNil(values.louds_シ)
        guard let louds = values.louds_シ else { return }
        // 「しっ」の候補が存在するかどうかを確認
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        let lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: values.character2CharId)
        let startNodeIndex = lookupGraph.nextIndices(for: lookupGraph.root).first(where: { lookupGraph.nodes[$0].character == "し" })
        XCTAssertNotNil(startNodeIndex)
        let (loudsNodeIndices, _) = louds.byfixNodeIndices(lookupGraph, startGraphNodeIndex: startNodeIndex ?? 0)
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "シ", indices: loudsNodeIndices, option: requestOptions())
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

    func testByfixNodeIndices_sitsi() throws {
        let values = setup()
        XCTAssertNotNil(values.louds_シ)
        guard let louds = values.louds_シ else { return }
        // ts -> ta
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana),
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        let lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: values.character2CharId)
        let startNodeIndex = lookupGraph.nextIndices(for: lookupGraph.root).first(where: { lookupGraph.nodes[$0].character == "し" })
        XCTAssertNotNil(startNodeIndex)
        let (loudsNodeIndices, _) = louds.byfixNodeIndices(lookupGraph, startGraphNodeIndex: startNodeIndex ?? 0)
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "シ", indices: loudsNodeIndices, option: requestOptions())
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
}
