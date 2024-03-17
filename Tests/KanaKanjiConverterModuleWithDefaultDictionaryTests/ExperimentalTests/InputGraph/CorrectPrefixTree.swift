//
//  CorrectPrefixTree.swift
//  
//
//  Created by miwa on 2024/02/23.
//

import Foundation

@testable import KanaKanjiConverterModule
import XCTest

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
            "g": Node([
                "s": .terminal(["ga"]),
                "q": .terminal(["ga"]),
                "d": .terminal(["ge"]),
                "r": .terminal(["ge"]),
                "w": .terminal(["ge"]),
                "k": .terminal(["gi"]),
                "l": .terminal(["go"]),
                "p": .terminal(["go"]),
                "j": .terminal(["gu"])
            ]),
            "m": Node([
                "s": .terminal(["ma"]),
                "q": .terminal(["ma"]),
                "d": .terminal(["me"]),
                "r": .terminal(["me"]),
                "w": .terminal(["me"]),
                "k": .terminal(["mi"]),
                "l": .terminal(["mo"]),
                "p": .terminal(["mo"]),
                "j": .terminal(["mu"])
            ]),
            "t": Node([
                "s": .terminal(["ta"]),
                "q": .terminal(["ta"]),
                "d": .terminal(["te"]),
                "r": .terminal(["te"]),
                "w": .terminal(["te"]),
                "k": .terminal(["ti"]),
                "l": .terminal(["to"]),
                "p": .terminal(["to"]),
                "j": .terminal(["tu"])
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
