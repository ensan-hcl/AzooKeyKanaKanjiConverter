//
//  InputGraph.swift
//
//
//  Created by miwa on 2024/02/21.
//

import Foundation
import DequeModule

@testable import KanaKanjiConverterModule
import XCTest

struct InputGraph {
    struct Node: Equatable, CustomStringConvertible {
        var character: Character
        var inputElementsRange: InputGraphRange
        var correction: CorrectGraph.Correction = .none

        var description: String {
            let `is` = inputElementsRange.startIndex?.description ?? "?"
            let ie = inputElementsRange.endIndex?.description ?? "?"
            return "Node(\"\(character)\", i(\(`is`)..<\(ie)), isTypo: \(correction.isTypo))"
        }
    }

    var nodes: [Node] = [
        // root node
        Node(character: "\0", inputElementsRange: .endIndex(0), correction: .none)
    ]
    /// 許可されたNextIndex
    var allowedNextIndex: [Int: IndexSet] = [:]
    /// 許可されたprevIndex
    var allowedPrevIndex: [Int: IndexSet] = [:]
    /// correctGraphのノード情報
    var nextCorrectNodeIndices: [Int: IndexSet] = [:]

    mutating func update(_ correctGraph: CorrectGraph, nodeIndex: Int) {
        let cgNode = correctGraph.nodes[nodeIndex]
        // アルゴリズム
        // 1. nodeIndexをnextCorrectNodeIndicesに持っているノードを列挙する
        // 2. それぞれのノードにcgNodes[nodeIndex]を追加し、末尾置換が可能であれば実施する
        // 3. 可能でない場合、そのまま追加する
        // まず、cgNodeをinsertする
        let prevNodeIndices: [Int] = self.nextCorrectNodeIndices.lazy.filter {
            $0.value.contains(nodeIndex)
        }.map {
            $0.key
        }
        let newIndex = self.nodes.endIndex
        self.nodes.append(Node(character: cgNode.value, inputElementsRange: cgNode.inputElementsRange, correction: cgNode.correction))
        // 構造の情報を更新
        self.allowedPrevIndex[newIndex] = IndexSet(prevNodeIndices)
        for prevNodeIndex in prevNodeIndices {
            self.allowedNextIndex[prevNodeIndex, default: IndexSet()].insert(newIndex)
        }
        // correct graphにおけるnext nodeの情報
        self.nextCorrectNodeIndices[newIndex] = correctGraph.allowedNextIndex[nodeIndex]

        // 次に置換を動かす
        let startNode = InputGraphInputStyle.init(from: cgNode.inputStyle).replaceSuffixTree
        // nodesをそれぞれ遡っていく必要がある
        typealias SearchItem = (
            suffixTreeNode: ReplaceSuffixTree.Node,
            // 辿ってきたインデックス
            route: [Int],
            // 発見された置換
            foundValue: Replacement?,
            correction: CorrectGraph.Correction
        )
        typealias Match = (
            // 置換
            replacement: Replacement,
            // 置換を含むroute
            route: [Int]
        )
        struct Replacement: Hashable {
            var route: [Int]
            var value: String
        }
        var backSearchMatch: [Match] = []
        var stack: [SearchItem] = [(startNode, [newIndex], foundValue: nil, correction: cgNode.correction)]
        while let (cSuffixTreeNode, cRoute, cFoundValue, cCorrection) = stack.popLast() {
            // must not be empty
            let cNodeIndex = cRoute[0]
            if let bNode = cSuffixTreeNode.find(key: self.nodes[cNodeIndex].character) {
                for prevGraphNodeIndex in self.allowedPrevIndex[cNodeIndex, default: IndexSet()] {
                    // TODO: InputGraph.NodeにもInputStyle.IDを持たせてここで比較する
                    stack.append(
                        (
                            bNode,
                            // FIXME: 配列を生成し直しており、よくない
                            [prevGraphNodeIndex] + cRoute,
                            // bNodeがvalueを持っていればそれで置き換え、持っていなければ現在のものを用いる
                            foundValue: bNode.value.map {Replacement(route: cRoute, value: $0)} ?? cFoundValue,
                            cCorrection.isTypo ? .typo : self.nodes[prevGraphNodeIndex].correction
                        )
                    )
                }
            } else {
                // bNodeが見つからない場合、発見された置換をbackSearcMatchに追加する
                if let cFoundValue {
                    backSearchMatch.append((cFoundValue, cRoute))
                }
            }

        }

        // backSearchMatchを統合する
        let replacementToTarget = Dictionary(grouping: backSearchMatch, by: \.replacement)
        for (replacement, matches) in replacementToTarget {
            // MARK: replaceを実行する
            // 1. valueをnodeとして追加する
            // 2. routeに含まれるnodeをinvalidateする

            // MARK: 新規ノードを追加
            let startIndex = self.nodes[replacement.route[0]].inputElementsRange.startIndex
            let endIndex = self.nodes[replacement.route[replacement.route.endIndex - 1]].inputElementsRange.endIndex

            let characters = Array(replacement.value)
            let correction: CorrectGraph.Correction = if replacement.route.allSatisfy({!self.nodes[$0].correction.isTypo}) {
                .none
            } else {
                .typo
            }
            let newNodes = characters.indices.map { index in
                let range: InputGraphRange = if index == characters.startIndex && index == characters.endIndex - 1 {
                    .init(startIndex: startIndex, endIndex: endIndex)
                } else if index == characters.startIndex {
                    .init(startIndex: startIndex, endIndex: nil)
                } else if index == characters.endIndex - 1 {
                    .init(startIndex: nil, endIndex: endIndex)
                } else {
                    .unknown
                }
                return Node(character: characters[index], inputElementsRange: range, correction: correction)
            }
            let firstIndex = self.nodes.endIndex
            let lastIndex = self.nodes.endIndex + newNodes.count - 1
            self.nodes.append(contentsOf: newNodes)
            // MARK: next/prevを調整
            // firstIndexの処理: 直前ノードとのつながりをコピーする
            // routeからreplaceされる部分を落とし、置換の直前のindexを得る
            let prevIndices = matches.compactMap { match in
                assert(match.route.hasSuffix(replacement.route))
                return match.route.dropLast(replacement.route.count).last
            }
            self.allowedPrevIndex[firstIndex] = IndexSet(prevIndices)
            for i in prevIndices {
                // firstIndexを追加してreplacementの最初を削除する
                self.allowedNextIndex[i, default: IndexSet()].insert(firstIndex)
                self.allowedNextIndex[i, default: IndexSet()].remove(replacement.route[0])
            }
            // 中央部の処理
            for i in firstIndex ..< lastIndex {
                self.allowedNextIndex[i, default: IndexSet()].insert(i + 1)
                self.allowedPrevIndex[i + 1, default: IndexSet()].insert(i)
            }
            // lastIndexの処理: correctGraphの情報を修正する
            self.nextCorrectNodeIndices[lastIndex] = correctGraph.allowedNextIndex[nodeIndex]
        }
        // 上のforループを出てからこの処理を実行する
        for replacement in replacementToTarget.keys {
            // 置換済みのノードに後ろ向きに迷い込むことを防ぐ
            self.nextCorrectNodeIndices[replacement.route.last!] = IndexSet()
            self.allowedPrevIndex[replacement.route.last!] = IndexSet()
        }
    }

    consuming func clean() -> Self {
        var newGraph = Self(nodes: [])
        var indices: [(nodeIndex: Int, fromIndex: Int?)] = [(0, nil)]
        var processedNodeIndices: [Int: Int] = [:]
        while let (nodeIndex, fromIndex) = indices.popLast() {
            let newIndex = if let newIndex = processedNodeIndices[nodeIndex] {
                newIndex
            } else {
                {
                    let newIndex = newGraph.nodes.endIndex
                    newGraph.nodes.append(self.nodes[nodeIndex])
                    newGraph.nextCorrectNodeIndices[newIndex] = self.nextCorrectNodeIndices[nodeIndex]
                    return newIndex
                }()
            }
            if let fromIndex {
                newGraph.allowedNextIndex[fromIndex, default: IndexSet()].insert(newIndex)
                newGraph.allowedPrevIndex[newIndex, default: IndexSet()].insert(fromIndex)
            }
            for nextNodeIndex in self.allowedNextIndex[nodeIndex, default: IndexSet()] {
                indices.append((nextNodeIndex, newIndex))
            }
            processedNodeIndices[nodeIndex] = newIndex
        }
        return newGraph
    }

    static func build(input: CorrectGraph) -> Self {
        var inputGraph = Self()
        // 必ず、ノードより前のすべてのノードが処理済みであることを保証しながら、updateを実行する
        var nodeIndices = Array([0])
        var processedIndices = IndexSet()
        while let nodeIndex = nodeIndices.popLast() {
            print("build", input.nodes[nodeIndex].value)
            if processedIndices.contains(nodeIndex) {
                continue
            }
            let prevIndices = input.allowedPrevIndex[nodeIndex, default: IndexSet()]
            // 差がある場合
            let diff = prevIndices.subtracting(processedIndices)
            guard diff.isEmpty else {
                nodeIndices.append(nodeIndex)
                nodeIndices.append(contentsOf: diff)
                continue
            }
            processedIndices.insert(nodeIndex)
            // root以外
            if nodeIndex != 0 {
                inputGraph.update(input, nodeIndex: nodeIndex)
            } else {
                // nextCorrectNodeIndicesを更新しておく
                inputGraph.nextCorrectNodeIndices[0] = input.allowedNextIndex[0]
            }
            nodeIndices.append(contentsOf: input.allowedNextIndex[nodeIndex, default: IndexSet()])
        }
        return inputGraph
    }
}
