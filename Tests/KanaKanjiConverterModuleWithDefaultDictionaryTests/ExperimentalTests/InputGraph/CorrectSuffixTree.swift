//
//  CorrectSuffixTree.swift
//  
//
//  Created by miwa on 2024/02/23.
//

import Foundation

@testable import KanaKanjiConverterModule
import XCTest

/// 誤字訂正のためのsuffix tree
enum CorrectSuffixTree {
    final class Node {
        struct Item {
            init(_ replace: String, weight: PValue) {
                self.replace = replace
                self.weight = weight
            }

            var replace: String
            var weight: PValue
        }
        init(_ children: [Character: Node] = [:], value: [Item] = []) {
            self.children = children
            self.value = value
        }

        static func terminal(_ value: [Item]) -> Node {
            Node(value: value)
        }

        static func terminal(_ replace: String, weight: PValue) -> Node {
            Node(value: [Item(replace, weight: weight)])
        }

        var children: [Character: Node] = [:]
        var value: [Item]
        func find(key: Character) -> Node? {
            return children[key]
        }
    }

    static let roman2kana: Node = {
        Node([
            "s": Node([
                "g": .terminal("ga", weight: -3),
                "m": .terminal("ma", weight: -3),
                "t": .terminal("ta", weight: -3),
                "y": .terminal("ya", weight: -3)
            ]),
            "q": Node([
                "g": .terminal("ga", weight: -3),
                "m": .terminal("ma", weight: -3),
                "t": .terminal("ta", weight: -3),
                "y": .terminal("ya", weight: -3)
            ]),
            "d": Node([
                "g": .terminal("ge", weight: -3),
                "m": .terminal("me", weight: -3),
                "t": .terminal("te", weight: -3),
                "y": .terminal("ya", weight: -3)
            ]),
            "r": Node([
                "g": .terminal("ge", weight: -3),
                "m": .terminal("me", weight: -3),
                "t": .terminal("te", weight: -3),
                "y": .terminal("ya", weight: -3)
            ]),
            "w": Node([
                "g": .terminal("ge", weight: -3),
                "m": .terminal("me", weight: -3),
                "t": .terminal("te", weight: -3),
                "y": .terminal("ya", weight: -3)
            ]),
            "k": Node([
                "g": .terminal("gi", weight: -3),
                "m": .terminal("mi", weight: -3),
                "t": .terminal("ti", weight: -3),
                "y": .terminal("ya", weight: -3)
            ]),
            "l": Node([
                "g": .terminal("go", weight: -3),
                "m": .terminal("mo", weight: -3),
                "t": .terminal("to", weight: -3),
                "y": .terminal("ya", weight: -3)
            ]),
            "p": Node([
                "g": .terminal("go", weight: -3),
                "m": .terminal("mo", weight: -3),
                "t": .terminal("to", weight: -3),
                "y": .terminal("ya", weight: -3)
            ]),
            "j": Node([
                "g": .terminal("gu", weight: -3),
                "m": .terminal("mu", weight: -3),
                "t": .terminal("tu", weight: -3),
                "y": .terminal("ya", weight: -3)
            ])
        ])
    }()

    static let direct: Node = {
        Node([
            "か": .terminal("が", weight: -3),
            "た": .terminal("だ", weight: -3),
            "は": .terminal([.init("ば", weight: -3), .init("ぱ", weight: -6)])
        ])
    }()
}
