//
//  ReplacePrefixTree.swift
//
//
//  Created by miwa on 2024/02/23.
//

import Foundation

@testable import KanaKanjiConverterModule
import XCTest

// 置換のためのprefix tree
enum ReplacePrefixTree {
    static var characterNodes: [InputGraphInputStyle.ID: [Character: [Node]]] = [:]

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
        func insert(route: some Collection<Character>, value: consuming String, inputStyle: InputGraphInputStyle.ID) {
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

// 置換のためのprefix tree
enum ReplaceSuffixTree {

    final class Node {
        init(_ children: [Character: Node] = [:], character: Character = "\0", value: String? = nil) {
            self.children = children
            self.value = value
            self.character = character
        }
        var children: [Character: Node] = [:]
        var character: Character
        var value: String?
        func find(key: Character) -> Node? {
            return children[key]
        }
        func insert(route: some Collection<Character>, value: consuming String, inputStyle: InputGraphInputStyle.ID) {
            if let first = route.first {
                if let tree = self.children[first] {
                    tree.insert(route: route.dropFirst(), value: consume value, inputStyle: inputStyle)
                } else {
                    let tree = Node(character: first)
                    tree.insert(route: route.dropFirst(), value: consume value, inputStyle: inputStyle)
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
            tree.insert(route: item.key.reversed(), value: String(item.value), inputStyle: .systemRomanKana)
        }
        // additionals
        for item in ["bb", "cc", "dd", "ff", "gg", "hh", "jj", "kk", "ll", "mm", "pp", "qq", "rr", "ss", "tt", "vv", "ww", "xx", "yy", "zz"] {
            tree.insert(route: Array(item.reversed()), value: "っ" + String(item.last!), inputStyle: .systemRomanKana)
        }
        // additionals
        for item in ["nb", "nc", "nd", "nf", "ng", "nh", "nj", "nk", "nl", "nm", "np", "nq", "nr", "ns", "nt", "nv", "nw", "nx", "nz"] {
            tree.insert(route: Array(item.reversed()), value: "ん" + String(item.last!), inputStyle: .systemRomanKana)
        }
        return tree
    }()
    static let direct: Node = Node()
}

final class ReplaceTreeTests: XCTestCase {
    func testRoman2Kana() throws {
        let t = ReplaceSuffixTree.roman2kana.find(key: "t")
        let tt = t?.find(key: "t")
        XCTAssertEqual(tt?.value, "っt")
        let t2 = ReplaceSuffixTree.roman2kana.find(key: "t")
        let tt2 = t2?.find(key: "t")
        XCTAssertEqual(tt2?.value, "っt")
        let a = ReplaceSuffixTree.roman2kana.find(key: "a")
        let ta = a?.find(key: "t")
        XCTAssertEqual(ta?.value, "た")
    }
}
