//
//  ComposingTextV2.swift
//  
//
//  Created by miwa on 2024/04/08.
//

import Foundation

struct ComposingTextV2: Hashable, Sendable {
    init() {
        self.input = []
        self.convertTarget = ""
        self.cursorPosition = 0
    }

    var input: [InputElement]
    var convertTarget: String
    var cursorPosition: Int

    struct InputElement: Equatable, Hashable {
        var value: Character
        var inputStyle: InputGraphInputStyle.ID
    }

    mutating func append(_ element: InputElement) {
        self.input.append(element)
        self.convertTarget = Self.buildConvertTarget(input)
    }

    mutating func append(_ string: String, inputStyle: InputGraphInputStyle.ID) {
        self.input.append(contentsOf: string.map {.init(value: $0, inputStyle: inputStyle)})
        self.convertTarget = Self.buildConvertTarget(input)
    }

    mutating func removeLast(_ k: Int = 1) {
        let rest = self.convertTarget.dropLast(k)
        typealias Item = (value: String, inputStyle: InputGraphInputStyle.ID)
        var result: [Item] = []
        var maxSuccess = (index: -1, string: "")
        for elementIndex in input.indices {
            let element = input[elementIndex]
            if let last = result.last {
                if last.inputStyle.isCompatible(with: element.inputStyle) {
                    // 一旦inputStyleは継承することにする
                    result[result.endIndex - 1].value.append(element.value)
                } else {
                    result.append((String(element.value), element.inputStyle))
                }
            } else {
                result.append((String(element.value), element.inputStyle))
            }

            // 置換適用
            var node = InputGraphInputStyle.init(from: element.inputStyle).replaceSuffixTree
            let value = result[result.endIndex - 1].value
            var maxMatch = (count: 0, replace: "")
            var count = 0
            var stack = Array(value)
            while let c = stack.popLast(), let nextNode = node.find(key: c) {
                count += 1
                if let replace = nextNode.value {
                    maxMatch = (count, replace)
                }
                node = nextNode
            }
            if maxMatch.count > 0 {
                result[result.endIndex - 1].value.removeLast(maxMatch.count)
                result[result.endIndex - 1].value.append(contentsOf: maxMatch.replace)
            }
            let current = result.reduce(into: "") { $0.append(contentsOf: $1.value) }
            if rest.hasPrefix(current) {
                maxSuccess = (elementIndex, current)
            }
        }
        self.input = Array(self.input.prefix(maxSuccess.index + 1))
        self.input.append(contentsOf: rest.dropFirst(maxSuccess.string.count).map { .init(value: $0, inputStyle: .none) })
        self.convertTarget = String(rest)
    }

    static func buildConvertTarget(_ input: [InputElement]) -> String {
        typealias Item = (value: String, inputStyle: InputGraphInputStyle.ID)
        var result: [Item] = []
        for element in input {
            if let last = result.last {
                if last.inputStyle.isCompatible(with: element.inputStyle) {
                    // 一旦inputStyleは継承することにする
                    result[result.endIndex - 1].value.append(element.value)
                } else {
                    result.append((String(element.value), element.inputStyle))
                }
            } else {
                result.append((String(element.value), element.inputStyle))
            }

            // 置換適用
            var node = InputGraphInputStyle.init(from: element.inputStyle).replaceSuffixTree
            let value = result[result.endIndex - 1].value
            var maxMatch = (count: 0, replace: "")
            var count = 0
            var stack = Array(value)
            while let c = stack.popLast(), let nextNode = node.find(key: c) {
                count += 1
                if let replace = nextNode.value {
                    maxMatch = (count, replace)
                }
                node = nextNode
            }
            if maxMatch.count > 0 {
                result[result.endIndex - 1].value.removeLast(maxMatch.count)
                result[result.endIndex - 1].value.append(contentsOf: maxMatch.replace)
            }
        }
        return result.reduce(into: "") { $0.append(contentsOf: $1.value) }
    }
}

import XCTest

class ComposingTextV2Test: XCTestCase {
    func testAppend() throws {
        var c = ComposingTextV2()
        c.append(.init(value: "a", inputStyle: .systemRomanKana))
        XCTAssertEqual(c.convertTarget, "あ")
        c.append(.init(value: "t", inputStyle: .systemRomanKana))
        XCTAssertEqual(c.convertTarget, "あt")
        c.append(.init(value: "t", inputStyle: .systemRomanKana))
        XCTAssertEqual(c.convertTarget, "あっt")
        c.append(.init(value: "a", inputStyle: .systemRomanKana))
        XCTAssertEqual(c.convertTarget, "あった")
    }
    func testDelete_ata() throws {
        var c = ComposingTextV2()
        c.append(.init(value: "a", inputStyle: .systemRomanKana))
        c.append(.init(value: "t", inputStyle: .systemRomanKana))
        c.append(.init(value: "a", inputStyle: .systemRomanKana))
        c.removeLast()
        XCTAssertEqual(c.convertTarget, "あ")
    }
    func testDelete_asha() throws {
        var c = ComposingTextV2()
        c.append(.init(value: "a", inputStyle: .systemRomanKana))
        c.append(.init(value: "s", inputStyle: .systemRomanKana))
        c.append(.init(value: "h", inputStyle: .systemRomanKana))
        c.append(.init(value: "a", inputStyle: .systemRomanKana))
        c.removeLast()
        XCTAssertEqual(c.convertTarget, "あし")
        XCTAssertEqual(c.input.count, 2)
        XCTAssertEqual(c.input[0], .init(value: "a", inputStyle: .systemRomanKana))
        XCTAssertEqual(c.input[1], .init(value: "し", inputStyle: .none))
    }
    func testDelete_atta() throws {
        var c = ComposingTextV2()
        c.append(.init(value: "a", inputStyle: .systemRomanKana))
        c.append(.init(value: "t", inputStyle: .systemRomanKana))
        c.append(.init(value: "t", inputStyle: .systemRomanKana))
        c.append(.init(value: "a", inputStyle: .systemRomanKana))
        c.removeLast()
        XCTAssertEqual(c.convertTarget, "あっ")
        XCTAssertEqual(c.input.count, 2)
        XCTAssertEqual(c.input[0], .init(value: "a", inputStyle: .systemRomanKana))
        XCTAssertEqual(c.input[1], .init(value: "っ", inputStyle: .none))
    }
    func testDelete_aita() throws {
        var c = ComposingTextV2()
        c.append(.init(value: "a", inputStyle: .systemRomanKana))
        c.append(.init(value: "i", inputStyle: .systemRomanKana))
        c.append(.init(value: "t", inputStyle: .systemRomanKana))
        c.append(.init(value: "a", inputStyle: .systemRomanKana))
        c.removeLast()
        XCTAssertEqual(c.convertTarget, "あい")
        XCTAssertEqual(c.input.count, 2)
        XCTAssertEqual(c.input[0], .init(value: "a", inputStyle: .systemRomanKana))
        XCTAssertEqual(c.input[1], .init(value: "i", inputStyle: .systemRomanKana))
    }
    func testBuildConvertTarget() throws {
        XCTAssertEqual(ComposingTextV2.buildConvertTarget([.init(value: "a", inputStyle: .systemRomanKana)]), "あ")
        XCTAssertEqual(ComposingTextV2.buildConvertTarget([.init(value: "t", inputStyle: .systemRomanKana)]), "t")
        XCTAssertEqual(
            ComposingTextV2.buildConvertTarget(
                [
                    .init(value: "a", inputStyle: .systemRomanKana),
                    .init(value: "t", inputStyle: .systemRomanKana),
                    .init(value: "t", inputStyle: .systemRomanKana),
                    .init(value: "a", inputStyle: .systemRomanKana)
                ]
            ),
            "あった"
        )
    }
}
