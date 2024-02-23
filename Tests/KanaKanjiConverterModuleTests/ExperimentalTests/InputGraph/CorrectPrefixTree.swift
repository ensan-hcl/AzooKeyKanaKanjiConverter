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
