//
//  InputGraphTests.swift
//
//
//  Created by miwa on 2024/02/21.
//

import Foundation

@testable import KanaKanjiConverterModule
import XCTest

// 置換のためのprefix tree
enum ReplacePrefixTree {
    final class Node {
        init(_ children: [Character: Node] = [:], value: String? = nil) {
            self.children = children
            self.value = value
        }

        static func terminal(_ value: String) -> Node {
            Node(value: value)
        }

        var children: [Character: Node] = [:]
        var value: String?
        func find(key: Character) -> Node? {
            return children[key]
        }
        func insert(route: some Collection<Character>, value: consuming String) {
            if let first = route.first {
                if let tree = self.children[first] {
                    tree.insert(route: route.dropFirst(), value: consume value)
                } else {
                    let tree = Node()
                    tree.insert(route: route.dropFirst(), value: consume value)
                    self.children[first] = tree
                }
            } else {
                self.value = consume value
            }
        }
    }

    static let roman2kana: Node = {
        var tree = Node()
        for item in KanaKanjiConverterModule.Roman2Kana.hiraganaChanges {
            tree.insert(route: item.key, value: String(item.value))
        }
        return tree
    }()
    static let direct: Node = Node()
}

// 誤字訂正のためのprefix tree
enum CorrectPrefixTree {
    final class Node {
        init(_ children: [Character: Node] = [:], value: [String] = []) {
            self.children = children
            self.value = value
        }

        static func terminal(_ value: [String]) -> Node {
            Node(value: value)
        }

        var children: [Character: Node] = [:]
        var value: [String]
        func find(key: Character) -> Node? {
            return children[key]
        }
        func insert(route: some Collection<Character>, value: consuming [String]) {
            if let first = route.first {
                if let tree = self.children[first] {
                    tree.insert(route: route.dropFirst(), value: consume value)
                } else {
                    let tree = Node()
                    tree.insert(route: route.dropFirst(), value: consume value)
                    self.children[first] = tree
                }
            } else {
                self.value = consume value
            }
        }
    }

    static let roman2kana: Node = {
        Node([
            "t": Node([
                "s": .terminal(["ta"]),
                "z": .terminal(["ta"]),
                "q": .terminal(["ta"]),
            ])
        ])
    }()
    static let direct: Node = {
        Node([
            "か": .terminal(["が"]),
            "は": .terminal(["ば", "ぱ"])
        ])
    }()
}

struct InputGraph {
    enum Range: Equatable, Sendable {
        case unknown
        case startIndex(Int)
        case endIndex(Int)
        case range(Int, Int)

        var startIndex: Int? {
            switch self {
            case .unknown, .endIndex: nil
            case .startIndex(let index), .range(let index, _): index
            }
        }

        var endIndex: Int? {
            switch self {
            case .unknown, .startIndex: nil
            case .endIndex(let index), .range(_, let index): index
            }
        }
    }
    struct Node: Equatable, CustomStringConvertible {
        var character: Character
        var displayedTextRange: Range
        var inputElementsRange: Range

        var description: String {
            let ds = displayedTextRange.startIndex?.description ?? "?"
            let de = displayedTextRange.endIndex?.description ?? "?"
            let `is` = inputElementsRange.startIndex?.description ?? "?"
            let ie = inputElementsRange.endIndex?.description ?? "?"
            return "Node(\"\(character)\", d(\(ds)..<\(de)), i(\(`is`)..<\(ie)))"
        }
    }

    var nodes: [Node] = [
        // root node
        Node(character: "\0", displayedTextRange: .endIndex(0), inputElementsRange: .endIndex(0))
    ]
    /// `displayedTextStartIndexToNodeIndices[0]`は`displayedTextRange==.startIndex(0)`または`displayedTextRange==.range(0, k)`であるようなノードのindexのセットを返す
    var displayedTextStartIndexToNodeIndices: [IndexSet] = []
    var inputElementsStartIndexToNodeIndices: [IndexSet] = []
    var displayedTextEndIndexToNodeIndices: [IndexSet] = [IndexSet(integer: 0)] // rootノードのindexで初期化
    var inputElementsEndIndexToNodeIndices: [IndexSet] = [IndexSet(integer: 0)] // rootノードのindexで初期化

    func next(for node: borrowing Node) -> [Node] {
        var indexSet = IndexSet()
        switch node.displayedTextRange {
        case .unknown, .startIndex: break
        case .endIndex(let endIndex), .range(_, let endIndex):
            indexSet.formUnion(self.displayedTextStartIndexToNodeIndices[endIndex])
        }
        switch node.inputElementsRange {
        case .unknown, .startIndex: break
        case .endIndex(let endIndex), .range(_, let endIndex):
            indexSet.formUnion(self.inputElementsStartIndexToNodeIndices[endIndex])
        }
        return indexSet.map{ self.nodes[$0] }
    }

    mutating func insert(_ node: consuming Node) {
        let index = self.nodes.count
        if let startIndex = node.displayedTextRange.startIndex {
            if self.displayedTextStartIndexToNodeIndices.endIndex <= startIndex {
                self.displayedTextStartIndexToNodeIndices.append(contentsOf: Array(repeating: IndexSet(), count: startIndex - self.displayedTextStartIndexToNodeIndices.endIndex + 1))
            }
            self.displayedTextStartIndexToNodeIndices[startIndex].insert(index)
        }
        if let endIndex = node.displayedTextRange.endIndex {
            if self.displayedTextEndIndexToNodeIndices.endIndex <= endIndex {
                self.displayedTextEndIndexToNodeIndices.append(contentsOf: Array(repeating: IndexSet(), count: endIndex - self.displayedTextEndIndexToNodeIndices.endIndex + 1))
            }
            self.displayedTextEndIndexToNodeIndices[endIndex].insert(index)
        }
        if let startIndex = node.inputElementsRange.startIndex {
            if self.inputElementsStartIndexToNodeIndices.endIndex <= startIndex {
                self.inputElementsStartIndexToNodeIndices.append(contentsOf: Array(repeating: IndexSet(), count: startIndex - self.inputElementsStartIndexToNodeIndices.endIndex + 1))
            }
            self.inputElementsStartIndexToNodeIndices[startIndex].insert(index)
        }
        if let endIndex = node.inputElementsRange.endIndex {
            if self.inputElementsEndIndexToNodeIndices.endIndex <= endIndex {
                self.inputElementsEndIndexToNodeIndices.append(contentsOf: Array(repeating: IndexSet(), count: endIndex - self.inputElementsEndIndexToNodeIndices.endIndex + 1))
            }
            self.inputElementsEndIndexToNodeIndices[endIndex].insert(index)
        }
        self.nodes.append(node)
    }

    // EOSノードを追加する
    mutating func finalize() {}

    static func build(input: [ComposingText.InputElement]) -> Self {
        var inputGraph = Self()
        // アルゴリズム
        // 1. 今のindexから始めて、longest_matchになるように置換ルールを適用
        //    例えば、|tsar...だとしたら、tsaがlongest_matchになるので、[tsa]を[つぁ]として作成し、[つ][ぁ]をinsertする
        // 1. このとき、さらに誤字訂正候補も同時に探索する。
        //    例えば、[ts]->[ta]という訂正候補があるとする。このとき、
        //    | -> t -> s -> a -< r
        //    | ->   ta   -< a
        //    なので、[tsa]と[ta]が実際にはinsertされることになる。この誤字訂正由来の候補には適切にメタデータを付与し、ペナルティを課す
        // 2. 具体的にどのように探索するか。
        //    まず、inputsに対して訂正ルールの適用を行い、altItemsを1回のループで構築する。
        //    altItemsは[index: [(item: String, length: Int)]]である
        //    例えばitsaにおいてts→taのルールを持つ場合、altItemsは[1: [(item: ta, length: 2)]]となる。これは「index1から始まるtaという長さ2の訂正候補」になる。
        //    次のループでは置換ルールの適用を行う。
        //    それぞれのindexにおいて、そのindexから始まる置換ルールを列挙する。
        //    これは、replaceRulePrefixTreeを順に辿ることで行う。具体的には、
        //    0. クエリスタックSを[(root: Node, index: Int, []: [Character])]で初期化する
        //    1. クエリスタックから(node, i, chars)を取り出し、nodeに対してinputs[i].characterの検索をかける。存在していれば(childNode, i+1. chars + [inputs[i].character])をスタックに追加。また、altItems[i]のそれぞれに対して順に検索をかけ、スタックに追加。
        var altItems: [Int: [(replace: String, inputCount: Int)]] = [:]
        // correctRuleの適用によってaltItemsを構築する
        for (index, item) in zip(input.indices, input) {
            let correctPrefixTree = switch item.inputStyle {
            case .roman2kana: CorrectPrefixTree.roman2kana
            case .direct: CorrectPrefixTree.direct
            }
            typealias Match = (replace: String, inputCount: Int)
            typealias SearchItem = (
                node: CorrectPrefixTree.Node,
                nextIndex: Int,
                route: [Character]
            )
            var stack: [SearchItem] = [
                (correctPrefixTree, index, [])
            ]
            var matches: [Match] = []
            while let (cNode, cIndex, cRoute) = stack.popLast() {
                if cIndex < input.endIndex, let nNode = cNode.find(key: input[cIndex].character) {
                    // valueがあるかないかで分岐
                    matches.append(contentsOf: nNode.value.map{($0, cIndex - index + 1)})
                    stack.append((nNode, cIndex + 1, cRoute + [input[cIndex].character]))
                }
            }
            altItems[index] = matches
        }
        // replaceRuleの適用によって構築する
        for (index, item) in zip(input.indices, input) {
            guard let beforeNodeIndex = inputGraph.inputElementsEndIndexToNodeIndices[index].first,
                  let displayedTextStartIndex = inputGraph.nodes[beforeNodeIndex].displayedTextRange.endIndex else { continue }
            let replacePrefixTree = switch item.inputStyle {
            case .roman2kana: ReplacePrefixTree.roman2kana
            case .direct: ReplacePrefixTree.direct
            }
            typealias Match = (route: [Character], value: String)
            typealias SearchItem = (
                node: ReplacePrefixTree.Node,
                nextIndex: Int,
                route: [Character],
                longestMatch: Match
            )
            var stack: [SearchItem] = [
                (replacePrefixTree, index, [], (route: [], value: ""))
            ]
            var matches: [Match] = []
            while let (cNode, cIndex, cRoute, cLongestMatch) = stack.popLast() {
                if cIndex < input.endIndex, let nNode = cNode.find(key: input[cIndex].character) {
                    // valueがあるかないかで分岐
                    if let value = nNode.value {
                        stack.append((nNode, cIndex + 1, cRoute + [input[cIndex].character], (cRoute + [input[cIndex].character], value)))
                    } else {
                        stack.append((nNode, cIndex + 1, cRoute + [input[cIndex].character], cLongestMatch))
                    }
                } else {
                    if !cLongestMatch.route.isEmpty {
                        // longestMatch候補があれば、現在地点で打ち切ってmatchを確定する
                        matches.append(cLongestMatch)
                    } else if cRoute.isEmpty {
                        // 1文字目がrootに存在しない場合、character自体をmatchに登録する
                        // これは置換ルールとして正規表現で.->\1が存在していると考えれば良い
                        matches.append((route: [input[cIndex].character], value: String(input[cIndex].character)))
                    }
                }
                // altItemsを舐める
                perItem: for item in altItems[cIndex, default: []] {
                    // itemの対応するinputCountが1でない場合、少しややこしい
                    // altItemはひとまずreplace全体で一塊と考える
                    // 例えばab→an、sn→anなる二つのルールがあるときにabsnと打った場合、anan（あなn）が原理的には作られる
                    // しかし、一般のケースではreplaceで挿入や削除が起こる（例：amn→an）
                    // そこで、一旦はab→anのとき、[an]を一塊で扱う。つまり、現在ノードからa, nと辿った場合に候補が見つかる場合にのみ、stackに追加する
                    // この制限は将来的に取り除ける
                    var node: ReplacePrefixTree.Node? = cNode
                    if item.inputCount != 1 {
                        var chars = Array(item.replace)  // FIXME: 本当はQueueにしたい
                        while !chars.isEmpty {
                            if let nNode = node?.find(key: chars.removeFirst()) {
                                node = nNode
                            } else {
                                continue perItem
                            }
                        }
                    } else {
                        stack.append((.init(), cIndex + item.inputCount, cRoute + Array(item.replace), (cRoute + Array(item.replace), item.replace)))
                    }
                    if let node {
                        // valueがあるかないかで分岐
                        if let value = node.value {
                            stack.append((node, cIndex + item.inputCount, cRoute + Array(item.replace), (cRoute + Array(item.replace), value)))
                        } else {
                            stack.append((node, cIndex + item.inputCount, cRoute + Array(item.replace), cLongestMatch))
                        }
                    }
                }
            }
            // 最終的にmatchesがemptyだったら
            // TODO: ここの条件は「誤字訂正ではない候補が存在しなかったら」とするべき
            if matches.isEmpty {
                matches.append(([item.character], String(item.character)) as Match)
            }
            print(matches)
            // matchをinsertする
            for match in matches {
                let characters = Array(match.value)
                for (i, c) in zip(characters.indices, characters) {
                    let inputElementRange: InputGraph.Range = if i == characters.startIndex && i+1 == characters.endIndex {
                        .range(index, index + match.route.count)
                    } else if i == characters.startIndex {
                        .startIndex(index)
                    } else if i+1 == characters.endIndex {
                        .endIndex(i + match.route.count)
                    } else {
                        .unknown
                    }
                    let node = Node(
                        character: c,
                        displayedTextRange: .range(displayedTextStartIndex + i, displayedTextStartIndex + i + 1),
                        inputElementsRange: inputElementRange
                    )
                    inputGraph.insert(node)
                }
            }
        }

        return consume inputGraph
    }
}

final class InputGraphTests: XCTestCase {
    func testInsert() throws {
        var graph = InputGraph()
        let node1 = InputGraph.Node(character: "a", displayedTextRange: .range(0, 1), inputElementsRange: .range(0, 1))
        let node2 = InputGraph.Node(character: "b", displayedTextRange: .range(1, 2), inputElementsRange: .range(1, 2))
        graph.insert(node1)
        graph.insert(node2)
        XCTAssertEqual(graph.next(for: node1), [node2])
    }

    func testBuild() throws {
        do {
            let graph = InputGraph.build(input: [
                .init(character: "あ", inputStyle: .direct),
                .init(character: "い", inputStyle: .direct),
                .init(character: "う", inputStyle: .direct)
            ])
            XCTAssertEqual(graph.nodes.count, 4) // Root nodes
            print(graph.nodes)
        }
        do {
            let graph = InputGraph.build(input: [
                .init(character: "あ", inputStyle: .direct),
                .init(character: "か", inputStyle: .direct),
                .init(character: "う", inputStyle: .direct)
            ])
            XCTAssertEqual(graph.nodes.count, 5) // Root nodes
            print(graph.nodes)
        }
        do {
            let graph = InputGraph.build(input: [
                .init(character: "i", inputStyle: .roman2kana),
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "a", inputStyle: .roman2kana),
            ])
            XCTAssertEqual(graph.nodes.count, 3) // Root nodes
            print(graph.nodes)
        }
        do {
            // FIXME: 誤字訂正候補が優先され、t→t、s→sの候補が入らない
            let graph = InputGraph.build(input: [
                .init(character: "i", inputStyle: .roman2kana),
                .init(character: "t", inputStyle: .roman2kana),
                .init(character: "s", inputStyle: .roman2kana),
            ])
            XCTAssertEqual(graph.nodes.count, 3) // Root nodes
            print(graph.nodes)
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
            print(graph.nodes)
        }
    }
}
