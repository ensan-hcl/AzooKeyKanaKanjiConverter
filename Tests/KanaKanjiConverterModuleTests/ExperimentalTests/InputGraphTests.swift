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
    static var characterNodes: [InputGraph.InputStyle.ID: [Character: [Node]]] = [:]

    final class Node {
        init(_ children: [Character: Node] = [:], character: Character = "\0", value: String? = nil, parent: Node? = nil) {
            self.children = children
            self.value = value
            self.character = character
            self.parent = parent
        }
        var parent: Node?
        var children: [Character: Node] = [:]
        var character: Character
        var value: String?
        func find(key: Character) -> Node? {
            return children[key]
        }
        func insert(route: some Collection<Character>, value: consuming String, inputStyle: InputGraph.InputStyle.ID) {
            if let first = route.first {
                if let tree = self.children[first] {
                    tree.insert(route: route.dropFirst(), value: consume value, inputStyle: inputStyle)
                } else {
                    let tree = Node(character: first, parent: self)
                    tree.insert(route: route.dropFirst(), value: consume value, inputStyle: inputStyle)
                    self.children[first] = tree
                    ReplacePrefixTree.characterNodes[inputStyle, default: [:]][first, default: []].append(tree)
                }
            } else {
                self.value = consume value
            }
        }
    }

    static let roman2kana: Node = {
        var tree = Node()
        for item in KanaKanjiConverterModule.Roman2Kana.hiraganaChanges {
            tree.insert(route: item.key, value: String(item.value), inputStyle: .systemRomanKana)
        }
        // additionals
        for item in ["bb", "cc", "dd", "ff", "gg", "hh", "jj", "kk", "ll", "mm", "pp", "qq", "rr", "ss", "tt", "vv", "ww", "xx", "yy", "zz"] {
            tree.insert(route: Array(item), value: "っ" + String(item.last!), inputStyle: .systemRomanKana)
        }
        // additionals
        for item in ["nb", "nc", "nd", "nf", "ng", "nh", "nj", "nk", "nl", "nm", "np", "nq", "nr", "ns", "nt", "nv", "nw", "nx", "nz"] {
            tree.insert(route: Array(item), value: "ん" + String(item.last!), inputStyle: .systemRomanKana)
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
                "p": .terminal(["to"]),
            ]),
            "g": Node([
                "s": .terminal(["ga"]),
                "z": .terminal(["ga"]),
                "q": .terminal(["ga"]),
                "p": .terminal(["go"]),
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
    struct InputStyle: Identifiable {
        init(from deprecatedInputStyle: KanaKanjiConverterModule.InputStyle) {
            switch deprecatedInputStyle {
            case .direct:
                self = .systemFlickDirect
            case .roman2kana:
                self = .systemRomanKana
            }
        }

        init(id: InputGraph.InputStyle.ID, replacePrefixTree: ReplacePrefixTree.Node, correctPrefixTree: CorrectPrefixTree.Node) {
            self.id = id
            self.replacePrefixTree = replacePrefixTree
            self.correctPrefixTree = correctPrefixTree
        }
        
        struct ID: Equatable, Hashable, Sendable, CustomStringConvertible {
            init(id: UInt8) {
                self.id = id
            }
            init(from deprecatedInputStyle: KanaKanjiConverterModule.InputStyle) {
                switch deprecatedInputStyle {
                case .direct:
                    self = .systemFlickDirect
                case .roman2kana:
                    self = .systemRomanKana
                }
            }
            static let all = Self(id: 0x00)
            static let systemFlickDirect = Self(id: 0x01)
            static let systemRomanKana = Self(id: 0x02)
            var id: UInt8

            func isCompatible(with id: ID) -> Bool {
                if self == .all {
                    true
                } else {
                    self == id
                }
            }
            var description: String {
                "ID(\(id))"
            }
        }
        static let all: Self = InputStyle(
            id: .all,
            replacePrefixTree: ReplacePrefixTree.Node(),
            correctPrefixTree: CorrectPrefixTree.Node()
        )
        static let systemFlickDirect: Self = InputStyle(
            id: .systemFlickDirect,
            replacePrefixTree: ReplacePrefixTree.direct,
            correctPrefixTree: CorrectPrefixTree.direct
        )
        static let systemRomanKana: Self = InputStyle(
            id: .systemRomanKana,
            replacePrefixTree: ReplacePrefixTree.roman2kana,
            correctPrefixTree: CorrectPrefixTree.roman2kana
        )

        /// `id` for the input style.
        ///  - warning: value `0x00-0x7F` is reserved for system space.
        var id: ID
        var replacePrefixTree: ReplacePrefixTree.Node
        var correctPrefixTree: CorrectPrefixTree.Node
    }

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

    enum Correction: CustomStringConvertible {
        /// 訂正ではない
        case none
        /// 訂正である
        case typo

        var isTypo: Bool {
            self == .typo
        }

        var description: String {
            switch self {
            case .none: "none"
            case .typo: "typo"
            }
        }
    }

    struct Node: Equatable, CustomStringConvertible {
        var character: Character
        var displayedTextRange: Range
        var inputElementsRange: Range
        var correction: Correction = .none

        var description: String {
            let ds = displayedTextRange.startIndex?.description ?? "?"
            let de = displayedTextRange.endIndex?.description ?? "?"
            let `is` = inputElementsRange.startIndex?.description ?? "?"
            let ie = inputElementsRange.endIndex?.description ?? "?"
            return "Node(\"\(character)\", d(\(ds)..<\(de)), i(\(`is`)..<\(ie)), isTypo: \(correction.isTypo)"
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
    // 使用されなくなったインデックスの集合
    var deadNodeIndices: [Int] = []

    var root: Node {
        nodes[0]
    }

    func next(for node: Node) -> [Node] {
        var indexSet = IndexSet()
        if let endIndex = node.displayedTextRange.endIndex {
            if endIndex < self.displayedTextStartIndexToNodeIndices.endIndex {
                indexSet.formUnion(self.displayedTextStartIndexToNodeIndices[endIndex])
            }
        }
        if let endIndex = node.inputElementsRange.endIndex {
            if endIndex < self.inputElementsStartIndexToNodeIndices.endIndex {
                indexSet.formUnion(self.inputElementsStartIndexToNodeIndices[endIndex])
            }
        }
        return indexSet.map{ self.nodes[$0] }
    }

    func prevIndices(for node: Node) -> IndexSet {
        var indexSet = IndexSet()
        if let startIndex = node.displayedTextRange.startIndex {
            if startIndex < self.displayedTextEndIndexToNodeIndices.endIndex {
                indexSet.formUnion(self.displayedTextEndIndexToNodeIndices[startIndex])
            }
        }
        if let startIndex = node.inputElementsRange.startIndex {
            if startIndex < self.inputElementsEndIndexToNodeIndices.endIndex {
                indexSet.formUnion(self.inputElementsEndIndexToNodeIndices[startIndex])
            }
        }
        return indexSet
    }

    func prev(for node: Node) -> [Node] {
        prevIndices(for: node).map{ self.nodes[$0] }
    }

    private mutating func _insert(_ node: Node) -> Int {
        // 可能ならdeadNodeIndicesを再利用する
        if let deadIndex = self.deadNodeIndices.popLast() {
            self.nodes[deadIndex] = node
            return deadIndex
        } else {
            self.nodes.append(node)
            return self.nodes.count - 1
        }
    }

    mutating func remove(at index: Int) {
        assert(index != 0, "Node at index 0 is root and must not be removed.")
        self.deadNodeIndices.append(index)
        // FIXME: 多分nodeの情報を使えばもっと効率的にremoveできる
        self.displayedTextStartIndexToNodeIndices.mutatingForeach {
            $0.remove(index)
        }
        self.displayedTextEndIndexToNodeIndices.mutatingForeach {
            $0.remove(index)
        }
        self.inputElementsStartIndexToNodeIndices.mutatingForeach {
            $0.remove(index)
        }
        self.inputElementsEndIndexToNodeIndices.mutatingForeach {
            $0.remove(index)
        }
    }

    mutating func insert(_ node: Node) {
        let index = self._insert(node)
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
                route: [Character],
                inputStyleId: InputStyle.ID
            )
            var stack: [SearchItem] = [
                (correctPrefixTree, index, [], .all),
            ]
            var matches: [Match] = []
            while let (cNode, cIndex, cRoute, cInputStyleId) = stack.popLast() {
                guard cIndex < input.endIndex else {
                    continue
                }
                let inputStyleId = InputStyle(from: input[cIndex].inputStyle).id
                guard cInputStyleId.isCompatible(with: inputStyleId) else {
                    continue
                }
                if let nNode = cNode.find(key: input[cIndex].character) {
                    // valueがあるかないかで分岐
                    matches.append(contentsOf: nNode.value.map{($0, cIndex - index + 1)})
                    stack.append((nNode, cIndex + 1, cRoute + [input[cIndex].character], inputStyleId))
                }
            }
            altItems[index] = matches
        }
        // replaceRuleの適用によって構築する
        for (index, item) in zip(input.indices, input) {
            // backward search
            // まず、すでに登録されているInputGraphのNodeから継続的に置換できるものがないかを確認する
            // たとえば「itta」を打つとき、ittまでの処理で[い][っ][t]が生成されている
            // そこでaを処理するタイミングで、前方の[t]に遡って[a]を追加し、これを[ta]にする処理を行う必要がある
            // TODO: まだtypoの処理が不十分
            typealias Match = (displayedTextStartIndex: Int?, inputElementsStartIndex: Int?, inputElementsEndIndex: Int, value: String, correction: Correction)
            typealias BackSearchMatch = (endNode: ReplacePrefixTree.Node, route: [Character], inputStyleId: InputStyle.ID, correction: Correction, longestMatch: Match)
            var backSearchMatch: [BackSearchMatch] = []
            do {
                if let characterNodes = ReplacePrefixTree.characterNodes[.init(from: item.inputStyle)],
                   let nodes = characterNodes[item.character] {
                    // nodesをそれぞれ遡っていく必要がある
                    typealias SearchItem = (
                        endNode: ReplacePrefixTree.Node,
                        endValue: String?,
                        node: ReplacePrefixTree.Node,
                        route: [Int],
                        inputStyleId: InputStyle.ID,
                        correction: Correction
                    )
                    var stack: [SearchItem] = nodes.map {
                        ($0, $0.value, $0, [], .init(from: item.inputStyle), .none)
                    }
                    while let (endNode, endValue, cNode, cRoute, cInputStyleId, cCorrection) = stack.popLast() {
                        // pNodeがrootでない場合
                        if let pNode = cNode.parent, pNode.parent != nil {
                            // parentNodeがある場合、そのnodeに合ったbeforeGraphNodeが存在するかを確認する
                            let indices = if let first = cRoute.first {
                                inputGraph.prevIndices(for: inputGraph.nodes[first])
                            } else {
                                index < inputGraph.inputElementsEndIndexToNodeIndices.endIndex ? inputGraph.inputElementsEndIndexToNodeIndices[index] : .init()
                            }
                            for prevGraphNodeIndex in indices {
                                guard inputGraph.nodes[prevGraphNodeIndex].character == pNode.character else {
                                    continue
                                }
                                // TODO: InputGraph.NodeにもInputStyle.IDを持たせてここで比較する
                                stack.append(
                                    (
                                        endNode,
                                        endValue,
                                        pNode,
                                        [prevGraphNodeIndex] + cRoute,
                                        cInputStyleId,
                                        cCorrection.isTypo ? .typo : inputGraph.nodes[prevGraphNodeIndex].correction
                                    )
                                )
                            }
                        } else {
                            // parentNodeがない場合、先頭にたどり着いたことになるので、これをmatchesに追加する
                            // matchesはindexの1つ前までを登録する
                            guard let pNode = endNode.parent else { continue }
                            let inputElementsStartIndex = if cRoute.isEmpty { index } else { inputGraph.nodes[cRoute.first!].inputElementsRange.startIndex }
                            let displayedTextStartIndex = cRoute.first.flatMap { inputGraph.nodes[$0].displayedTextRange.startIndex }
                            let characterRoute = cRoute.map{inputGraph.nodes[$0].character}
                            backSearchMatch.append(
                                (
                                    pNode,
                                    characterRoute,
                                    cInputStyleId,
                                    cCorrection,
                                    (displayedTextStartIndex, inputElementsStartIndex, index, "", cCorrection)
                                )
                            )
                        }
                    }
                }
            }
            let replacePrefixTree = InputStyle(from: item.inputStyle).replacePrefixTree
            typealias SearchItem = (
                node: ReplacePrefixTree.Node,
                nextIndex: Int,
                route: [Character],
                inputStyleId: InputStyle.ID,
                longestMatch: Match
            )
            var stack: [SearchItem] = []
            for match in backSearchMatch {
                stack.append((match.endNode, index, match.route, match.inputStyleId, match.longestMatch))
            }
            if stack.isEmpty {
                stack.append((replacePrefixTree, index, [], .all, (nil, index, index, value: "", correction: .none)))
            }
            var matches: [Match] = []
            while let (cNode, cIndex, cRoute, cInputStyleId, cLongestMatch) = stack.popLast() {
                let continuous = cIndex < input.endIndex && cInputStyleId.isCompatible(with: .init(from: input[cIndex].inputStyle))
                if continuous, let nNode = cNode.find(key: input[cIndex].character) {
                    if let value = nNode.value {
                        // valueがある場合longestMatchを更新
                        stack.append((nNode, cIndex + 1, cRoute + [input[cIndex].character], .init(from: input[cIndex].inputStyle), (cLongestMatch.displayedTextStartIndex, cLongestMatch.inputElementsStartIndex, cIndex + 1, value, cLongestMatch.correction)))
                    } else if cRoute.isEmpty {
                        // valueがなくても、1文字だけの場合はlongestMatchを更新
                        stack.append((nNode, cIndex + 1, cRoute + [input[cIndex].character], .init(from: input[cIndex].inputStyle), (cLongestMatch.displayedTextStartIndex, cIndex, cIndex + 1, String(input[cIndex].character), .none)))
                    } else {
                        // それ以外の場合は普通に先に進む
                        stack.append((nNode, cIndex + 1, cRoute + [input[cIndex].character], .init(from: input[cIndex].inputStyle), cLongestMatch))
                    }
                } else {
                    if cLongestMatch.inputElementsStartIndex != cLongestMatch.inputElementsEndIndex {
                        // longestMatch候補があれば、現在地点で打ち切ってmatchを確定する
                        matches.append(cLongestMatch)
                    } else if cRoute.isEmpty {
                        // 1文字目がrootに存在しない場合、character自体をmatchに登録する
                        // これは置換ルールとして正規表現で.->\1が存在していると考えれば良い
                        matches.append((nil, index, index + 1, value: String(input[cIndex].character), correction: .none))
                    }
                }
                // 誤字訂正を追加する
                guard continuous else { continue }
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
                        stack.append(
                            (
                                .init(),
                                cIndex + item.inputCount,
                                cRoute + Array(item.replace),
                                .init(from: input[cIndex].inputStyle),
                                (cLongestMatch.displayedTextStartIndex, cLongestMatch.inputElementsStartIndex, cIndex + item.inputCount, item.replace, .typo)
                            )
                        )
                    }
                    if let node {
                        // valueがあるかないかで分岐
                        if let value = node.value {
                            stack.append(
                                (
                                    node,
                                    cIndex + item.inputCount,
                                    cRoute + Array(item.replace),
                                    .init(from: input[cIndex].inputStyle),
                                    (cLongestMatch.displayedTextStartIndex, cLongestMatch.inputElementsStartIndex, cIndex + item.inputCount, value, .typo)
                                )
                            )
                        } else {
                            stack.append(
                                (
                                    node,
                                    cIndex + item.inputCount,
                                    cRoute + Array(item.replace),
                                    .init(from: input[cIndex].inputStyle),
                                    (cLongestMatch.displayedTextStartIndex, cLongestMatch.inputElementsStartIndex, cIndex + item.inputCount, cLongestMatch.value, .typo)
                                )
                            )
                        }
                    }
                }
            }
            // matchをinsertする
            for match in matches {
                let displayedTextStartIndex = if let d = match.displayedTextStartIndex {
                    d
                } else if let beforeNodeIndex = inputGraph.inputElementsEndIndexToNodeIndices[index].first,
                    let d = inputGraph.nodes[beforeNodeIndex].displayedTextRange.endIndex {
                        d
                } else {
                    Int?.none
                }
                guard let displayedTextStartIndex else { continue }

                let characters = Array(match.value)
                for (i, c) in zip(characters.indices, characters) {
                    let inputElementRange: InputGraph.Range = if i == characters.startIndex && i+1 == characters.endIndex {
                        if let startIndex = match.inputElementsStartIndex {
                            .range(startIndex, match.inputElementsEndIndex)
                        } else {
                            .endIndex(match.inputElementsEndIndex)
                        }
                    } else if i == characters.startIndex {
                        if let startIndex = match.inputElementsStartIndex {
                            .startIndex(startIndex)
                        } else {
                            .unknown
                        }
                    } else if i+1 == characters.endIndex {
                        .endIndex(match.inputElementsEndIndex)
                    } else {
                        .unknown
                    }
                    let node = Node(
                        character: c,
                        displayedTextRange: .range(displayedTextStartIndex + i, displayedTextStartIndex + i + 1),
                        inputElementsRange: inputElementRange,
                        correction: match.correction
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
