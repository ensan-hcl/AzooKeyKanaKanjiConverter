//
//  LookupGraphTests.swift
//
//
//  Created by miwa on 2024/02/23.
//

import XCTest
import Foundation
@testable import KanaKanjiConverterModule

struct LookupGraph {
    struct Node: Equatable {
        var character: Character
        var charId: UInt8
        var inputElementsRange: InputGraphRange
        var correction: CorrectGraph.Correction = .none
    }

    var nodes: [Node] = [
        // root node
        Node(character: "\0", charId: 0x00, inputElementsRange: .endIndex(0))
    ]
    /// 許可されたNextIndex
    var allowedNextIndex: [Int: IndexSet] = [:]
    /// 許可されたprevIndex
    var allowedPrevIndex: [Int: IndexSet] = [:]
    /// node indexから始まるloudsノードのindex
    var loudsNodeIndex: [Int: [Int: Int]] = [:]


    static func build(input: consuming InputGraph, character2CharId: (Character) -> UInt8) -> Self {
        let nodes = input.nodes.map {
            Node(character: $0.character, charId: character2CharId($0.character), inputElementsRange: $0.inputElementsRange, correction: $0.correction)
        }
        return Self(nodes: nodes, allowedNextIndex: input.allowedNextIndex, allowedPrevIndex: input.allowedPrevIndex)
    }

    mutating func byfixNodeIndices(in louds: LOUDS, startGraphNodeIndex: Int = 0) -> (IndexSet, [Int: [Int]]) {
        var indexSet = IndexSet(integer: 1)
        // loudsのノードとLookupGraphのノードの対応を取るための辞書
        var loudsNodeIndex2GraphNodeEndIndices: [Int: [Int]] = [:]
        // loudsのノードとLookupGraphのノードの対応を取るための辞書
        var graphNodeEndIndexToLoudsNodeIndex: [Int: Int] = [:]
        typealias SearchItem = (
            nodeIndex: Int,
            lastLoudsNodeIndex: Int
        )
        var stack: [SearchItem] = [(startGraphNodeIndex, 1)]
        while let (cNodeIndex, cLastLoudsNodeIndex) = stack.popLast() {
            let cNode = self.nodes[cNodeIndex]
            // nextNodesを探索
            if let loudsNodeIndex = louds.searchCharNodeIndex(from: cLastLoudsNodeIndex, char: cNode.charId) {
                graphNodeEndIndexToLoudsNodeIndex[cNodeIndex] = loudsNodeIndex
                loudsNodeIndex2GraphNodeEndIndices[loudsNodeIndex, default: []].append(cNodeIndex)
                indexSet.insert(loudsNodeIndex)
                let nextIndices = self.allowedNextIndex[cNodeIndex, default: IndexSet()]
                stack.append(contentsOf: nextIndices.compactMap { index in
                    let node = self.nodes[index]
                    // endIndexをチェックする
                    // endIndexは単調増加である必要がある
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
        self.loudsNodeIndex[startGraphNodeIndex] = graphNodeEndIndexToLoudsNodeIndex
        return (indexSet, loudsNodeIndex2GraphNodeEndIndices)
    }

    mutating func differentialByfixSearch(in louds: LOUDS, cacheLookupGraph: LookupGraph, graphNodeIndex: (start: Int, cache: Int)) -> (IndexSet, [Int: [Int]]) {
        guard var graphNodeEndIndexToLoudsNodeIndex = cacheLookupGraph.loudsNodeIndex[graphNodeIndex.cache] else {
            return self.byfixNodeIndices(in: louds, startGraphNodeIndex: graphNodeIndex.start)
        }
        // lookupGraph.current.nodes[graphNodeIndex.start]とlookupGraph.cache.nodes[graphNodeIndex.cache]はマッチする

        var indexSet = IndexSet(integer: 1)
        // loudsのノードとLookupGraphのノードの対応を取るための辞書
        var loudsNodeIndex2GraphNodeEndIndices: [Int: [Int]] = [:]
        typealias SearchItem = (
            nodeIndex: Int,
            /// cache側のnodeIndex。ノードがマッチしていればnilではない、マッチしていなければnil
            cacheNodeIndex: Int?,
            lastLoudsNodeIndex: Int
        )
        var stack: [SearchItem] = [(graphNodeIndex.start, graphNodeIndex.cache, 1)]
        while let (cNodeIndex, cCacheNodeIndex, cLastLoudsNodeIndex) = stack.popLast() {
            let cNode = self.nodes[cNodeIndex]
            if let cCacheNodeIndex, let loudsNodeIndex = graphNodeEndIndexToLoudsNodeIndex[cCacheNodeIndex] {
                loudsNodeIndex2GraphNodeEndIndices[loudsNodeIndex, default: []].append(cNodeIndex)
                indexSet.insert(loudsNodeIndex)
                // next nodesを確認する
                let cachedNextNodes = cacheLookupGraph.allowedNextIndex[cCacheNodeIndex, default: []].map { ($0, cacheLookupGraph.nodes[$0].charId) }
                let currentNextNodes = self.allowedNextIndex[cCacheNodeIndex, default: []].map { ($0, self.nodes[$0].charId) }
                for currentNextNode in currentNextNodes {
                    if let item = cachedNextNodes.first(where: {$0.1 == currentNextNode.1}) {
                        stack.append((currentNextNode.0, item.0, loudsNodeIndex))
                    } else {
                        stack.append((currentNextNode.0, nil, loudsNodeIndex))
                    }
                }

            }
            // キャッシュが効かないケース
            else if let loudsNodeIndex = louds.searchCharNodeIndex(from: cLastLoudsNodeIndex, char: cNode.charId) {
                graphNodeEndIndexToLoudsNodeIndex[cNodeIndex] = loudsNodeIndex
                loudsNodeIndex2GraphNodeEndIndices[loudsNodeIndex, default: []].append(cNodeIndex)
                indexSet.insert(loudsNodeIndex)
                let nextIndices = self.allowedNextIndex[cNodeIndex, default: IndexSet()]
                stack.append(contentsOf: nextIndices.compactMap { index in
                    let node = self.nodes[index]
                    // endIndexをチェックする
                    // endIndexは単調増加である必要がある
                    if let cInputElementsEndIndex = cNode.inputElementsRange.endIndex,
                       let nInputElementsEndIndex = node.inputElementsRange.endIndex {
                        guard cInputElementsEndIndex < nInputElementsEndIndex else {
                            return nil
                        }
                    }
                    return (index, nil, loudsNodeIndex)
                })
            }
        }
        self.loudsNodeIndex[graphNodeIndex.start] = graphNodeEndIndexToLoudsNodeIndex
        return (indexSet, loudsNodeIndex2GraphNodeEndIndices)
    }

}

extension DicdataStore {
    func buildConvertGraph(inputGraph: consuming InputGraph, option: ConvertRequestOptions) -> ConvertGraph {
        var lookupGraph = LookupGraph.build(input: consume inputGraph, character2CharId: { self.character2charId($0.toKatakana()) })
        var stack = Array(lookupGraph.allowedNextIndex[0, default: []])
        var graphNodeIndex2LatticeNodes: [Int: [ConvertGraph.LatticeNode]] = [:]
        var processedIndexSet = IndexSet()
        while let graphNodeIndex = stack.popLast() {
            // 処理済みのノードは無視
            guard !processedIndexSet.contains(graphNodeIndex) else {
                continue
            }
            let graphNode = lookupGraph.nodes[graphNodeIndex]
            guard let louds = self.loadLOUDS(identifier: String(graphNode.character.toKatakana())) else {
                continue
            }
            /// graphNodeIndexから始まる辞書エントリを列挙
            ///   * loudsNodeIndices: loudsから得たloudstxt内のデータの位置
            ///   * loudsNodeIndex2GraphNodeEndIndices: それぞれのloudsNodeIndexがどのgraphNodeIndexを終端とするか
            let (indexSet, loudsNodeIndex2GraphNodeEndIndices) = lookupGraph.byfixNodeIndices(in: louds, startGraphNodeIndex: graphNodeIndex)
            let dicdataWithIndex: [(loudsNodeIndex: Int, dicdata: [DicdataElement])] = self.getDicdataFromLoudstxt3(identifier: String(graphNode.character.toKatakana()), indices: indexSet, option: option)

            // latticeNodesを構築する
            var latticeNodes: [ConvertGraph.LatticeNode] = []
            for (loudsNodeIndex, dicdata) in dicdataWithIndex {
                for endNodeIndex in loudsNodeIndex2GraphNodeEndIndices[loudsNodeIndex, default: []] {
                    let inputElementsRange = InputGraphRange(
                        startIndex: graphNode.inputElementsRange.startIndex,
                        endIndex: lookupGraph.nodes[endNodeIndex].inputElementsRange.endIndex
                    )
                    if graphNode.inputElementsRange.startIndex == 0 {
                        latticeNodes.append(contentsOf: dicdata.map {
                            .init(data: $0, nextConvertNodeIndices: lookupGraph.allowedNextIndex[endNodeIndex, default: []], inputElementsRange: inputElementsRange, prevs: [.BOSNode()])
                        })
                    } else {
                        latticeNodes.append(contentsOf: dicdata.map {
                            .init(data: $0, nextConvertNodeIndices: lookupGraph.allowedNextIndex[endNodeIndex, default: []], inputElementsRange: inputElementsRange)
                        })
                    }
                }
            }
            graphNodeIndex2LatticeNodes[graphNodeIndex] = latticeNodes

            // 続くノードのindexを追加する
            processedIndexSet.insert(graphNodeIndex)
            stack.append(contentsOf: lookupGraph.allowedNextIndex[graphNodeIndex, default: []])
        }
        return ConvertGraph.build(input: lookupGraph, nodeIndex2LatticeNode: graphNodeIndex2LatticeNodes)
    }

    func getDicdataFromLoudstxt3(identifier: String, indices: some Sequence<Int>, option: ConvertRequestOptions) -> [(loudsNodeIndex: Int, dicdata: [DicdataElement])] {
        // split = 2048
        let dict = [Int: [Int]].init(grouping: indices, by: {$0 >> 11})
        var data: [(loudsNodeIndex: Int, dicdata: [DicdataElement])] = []
        for (key, value) in dict {
            // FIXME: use local option
            // trueIndexはそのまま、keyIndexはsplit-1=2047で&したものを用いる
            data.append(contentsOf: LOUDS.getDataForLoudstxt3(identifier + "\(key)", indices: value.map {(trueIndex: $0, keyIndex: $0 & 2047)}, option: option))
        }
        return data
    }
}

final class LookupGraphTests: XCTestCase {
    func requestOptions() -> ConvertRequestOptions {
        .withDefaultDictionary(requireJapanesePrediction: false, requireEnglishPrediction: false, keyboardLanguage: .ja_JP, learningType: .nothing, memoryDirectoryURL: URL(fileURLWithPath: ""), sharedContainerURL: URL(fileURLWithPath: ""), metadata: .init(appVersionString: "Test"))
    }

    func setup() -> (dicdataStore: DicdataStore, character2CharId: (Character) -> UInt8) {
        let dicdataStore = DicdataStore(convertRequestOptions: requestOptions())
        let character2CharId: (Character) -> UInt8 = { dicdataStore.character2charId($0.toKatakana()) }
        return (dicdataStore, character2CharId)
    }

    func testByfixNodeIndices_しかい() throws {
        let values = setup()
        guard let louds = LOUDS.load("シ", option: requestOptions()) else {
            XCTFail()
            return
        }
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "し", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        var lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: values.character2CharId)
        let startNodeIndex = inputGraph.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph.nodes[$0].character == "し" })
        XCTAssertNotNil(startNodeIndex)
        let (loudsNodeIndices, _) = lookupGraph.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex ?? 0)
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

        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["シ", "シカ", "シカイ", "シガ", "シガイ"]),
            []
        )
    }

    func testByfixNodeIndices_みらい() throws {
        let values = setup()
        guard let louds = LOUDS.load("ミ", option: requestOptions()) else {
            XCTFail()
            return
        }
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "み", inputStyle: .direct),
            .init(character: "ら", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        var lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: values.character2CharId)
        let startNodeIndex = lookupGraph.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph.nodes[$0].character == "み" })
        XCTAssertNotNil(startNodeIndex)
        let (loudsNodeIndices, _) = lookupGraph.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex ?? 0)
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "ミ", indices: loudsNodeIndices, option: requestOptions())
        let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
        // ミ
        XCTAssertTrue(dicdata.contains {$0.word == "見"})
        // ミラ
        XCTAssertTrue(dicdata.contains {$0.word == "ミラ"})
        // ミライ
        XCTAssertTrue(dicdata.contains {$0.word == "未来"})

        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["ミ", "ミラ", "ミライ"]),
            []
        )
    }

    func testByfixNodeIndices_たいかく() throws {
        let values = setup()
        guard let louds = LOUDS.load("タ", option: requestOptions()) else {
            XCTFail()
            return
        }
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "た", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct),
            .init(character: "く", inputStyle: .direct)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        var lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: values.character2CharId)
        let startNodeIndex = lookupGraph.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph.nodes[$0].character == "た" })
        XCTAssertNotNil(startNodeIndex)
        let (loudsNodeIndices, _) = lookupGraph.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex ?? 0)
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "タ", indices: loudsNodeIndices, option: requestOptions())
        let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
        // タ
        XCTAssertTrue(dicdata.contains {$0.word == "他"})
        // タイ
        XCTAssertTrue(dicdata.contains {$0.word == "タイ"})
        XCTAssertTrue(dicdata.contains {$0.word == "他意"})
        // タイカ
        XCTAssertTrue(dicdata.contains {$0.word == "対価"})
        // タイガ
        XCTAssertTrue(dicdata.contains {$0.word == "大河"})
        // タイカク
        XCTAssertTrue(dicdata.contains {$0.word == "体格"})
        // タイガク
        XCTAssertTrue(dicdata.contains {$0.word == "退学"})
        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["タ", "タイ", "タイカ", "タイガ", "タイカク", "タイガク"]),
            []
        )
    }

    func testByfixNodeIndices_sittai() throws {
        let values = setup()
        guard let louds = LOUDS.load("シ", option: requestOptions()) else {
            XCTFail()
            return
        }
        // 「しっ」の候補が存在するかどうかを確認
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        var lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: values.character2CharId)
        let startNodeIndex = lookupGraph.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph.nodes[$0].character == "し" })
        XCTAssertNotNil(startNodeIndex)
        let (loudsNodeIndices, _) = lookupGraph.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex ?? 0)
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
        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["シ", "シッ", "シッタ", "シッタイ"]),
            []
        )
    }

    func testByfixNodeIndices_sitsi() throws {
        let values = setup()
        guard let louds = LOUDS.load("シ", option: requestOptions()) else {
            XCTFail()
            return
        }
        // ts -> ta
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        var lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: values.character2CharId)
        let startNodeIndex = lookupGraph.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph.nodes[$0].character == "し" })
        XCTAssertNotNil(startNodeIndex)
        let (loudsNodeIndices, _) = lookupGraph.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex ?? 0)
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
        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["シ", "シツ", "シタ", "シタイ"]),
            []
        )
    }

    func testByfixNodeIndices_たいか_add_く() throws {
        let values = setup()
        guard let louds = LOUDS.load("タ", option: requestOptions()) else {
            XCTFail()
            return
        }
        let correctGraph1 = CorrectGraph.build(input: [
            .init(character: "た", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct),
        ])
        let inputGraph1 = InputGraph.build(input: correctGraph1)
        var lookupGraph1 = LookupGraph.build(input: inputGraph1, character2CharId: values.character2CharId)
        let startNodeIndex1 = lookupGraph1.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph1.nodes[$0].character == "た" })
        XCTAssertNotNil(startNodeIndex1)
        _ = lookupGraph1.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex1 ?? 0)

        let correctGraph2 = CorrectGraph.build(input: [
            .init(character: "た", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct),
            .init(character: "く", inputStyle: .direct) // added
        ])
        let inputGraph2 = InputGraph.build(input: correctGraph2)
        var lookupGraph2 = LookupGraph.build(input: inputGraph2, character2CharId: values.character2CharId)
        let startNodeIndex2 = lookupGraph2.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph2.nodes[$0].character == "た" })
        XCTAssertNotNil(startNodeIndex2)
        let (loudsNodeIndices2, _) = lookupGraph2.differentialByfixSearch(in: louds, cacheLookupGraph: lookupGraph1, graphNodeIndex: (startNodeIndex2 ?? 0, startNodeIndex1 ?? 0))
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "タ", indices: loudsNodeIndices2, option: requestOptions())
        let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
        // タ
        XCTAssertTrue(dicdata.contains {$0.word == "他"})
        // タイ
        XCTAssertTrue(dicdata.contains {$0.word == "タイ"})
        XCTAssertTrue(dicdata.contains {$0.word == "他意"})
        // タイカ
        XCTAssertTrue(dicdata.contains {$0.word == "対価"})
        // タイガ
        XCTAssertTrue(dicdata.contains {$0.word == "大河"})
        // タイカク
        XCTAssertTrue(dicdata.contains {$0.word == "体格"})
        // タイガク
        XCTAssertTrue(dicdata.contains {$0.word == "退学"})
        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["タ", "タイ", "タイカ", "タイガ", "タイカク", "タイガク"]),
            []
        )
    }

    func testByfixNodeIndices_たいか_remove_く() throws {
        let values = setup()
        guard let louds = LOUDS.load("タ", option: requestOptions()) else {
            XCTFail()
            return
        }
        let correctGraph1 = CorrectGraph.build(input: [
            .init(character: "た", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct),
        ])
        let inputGraph1 = InputGraph.build(input: correctGraph1)
        var lookupGraph1 = LookupGraph.build(input: inputGraph1, character2CharId: values.character2CharId)
        let startNodeIndex1 = lookupGraph1.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph1.nodes[$0].character == "た" })
        XCTAssertNotNil(startNodeIndex1)
        _ = lookupGraph1.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex1 ?? 0)

        let correctGraph2 = CorrectGraph.build(input: [
            .init(character: "た", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct),
        ])
        let inputGraph2 = InputGraph.build(input: correctGraph2)
        var lookupGraph2 = LookupGraph.build(input: inputGraph2, character2CharId: values.character2CharId)
        let startNodeIndex2 = lookupGraph2.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph2.nodes[$0].character == "た" })
        XCTAssertNotNil(startNodeIndex2)
        let (loudsNodeIndices2, _) = lookupGraph2.differentialByfixSearch(in: louds, cacheLookupGraph: lookupGraph1, graphNodeIndex: (startNodeIndex2 ?? 0, startNodeIndex1 ?? 0))
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "タ", indices: loudsNodeIndices2, option: requestOptions())
        let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
        // タ
        XCTAssertTrue(dicdata.contains {$0.word == "他"})
        // タイ
        XCTAssertTrue(dicdata.contains {$0.word == "タイ"})
        XCTAssertTrue(dicdata.contains {$0.word == "他意"})
        // タイカ
        XCTAssertFalse(dicdata.contains {$0.ruby == "タイカ"})
        // タイガ
        XCTAssertFalse(dicdata.contains {$0.ruby == "タイガ"})
        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["タ", "タイ"]),
            []
        )
    }
}
