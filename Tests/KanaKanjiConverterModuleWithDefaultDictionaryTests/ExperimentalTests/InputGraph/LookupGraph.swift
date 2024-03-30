//
//  LookupGraph.swift
//  
//
//  Created by miwa on 2024/03/31.
//

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
