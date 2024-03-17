//
//  extension Kana2Kanji+InputGraph.swift
//  
//
//  Created by miwa on 2024/02/23.
//

import Foundation
@testable import KanaKanjiConverterModule

import XCTest

extension Kana2Kanji {
    struct Result {
        var endNode: ConvertGraph.LatticeNode
        var correctGraph: CorrectGraph
        var inputGraph: InputGraph
        var convertGraph: ConvertGraph
    }
    func _experimental_all(_ inputData: ComposingText, option: ConvertRequestOptions) -> Result {
        // グラフ構築
        print(#file, "start")
        let correctGraph = CorrectGraph.build(input: inputData.input)
        let inputGraph = InputGraph.build(input: correctGraph)
        // 辞書ルックアップによりconvertGraphを構築
        print(#file, "lookup", inputGraph)
        let convertGraph = self.dicdataStore.buildConvertGraph(inputGraph: inputGraph, option: option)
        print(#file, "convert")
        let result = convertGraph.convertAll(option: option, dicdataStore: self.dicdataStore)
        return Result(endNode: result, correctGraph: correctGraph, inputGraph: inputGraph, convertGraph: convertGraph)
    }

    func _experimental_additional(
        composingText: ComposingText,
        additionalInputsStartIndex: Int,
        previousResult: consuming Result,
        option: ConvertRequestOptions
    ) -> Result {
        // グラフ構築
        print(#file, "start")
        var insertedIndexSet = IndexSet()
        for i in additionalInputsStartIndex ..< composingText.input.endIndex {
            insertedIndexSet.formUnion(previousResult.correctGraph.update(with: composingText.input[i], index: i, input: composingText.input))
        }
        // FIXME: inputGraphの差分ベースの構築は困難なため、普通に構築し直す
        let inputGraph = InputGraph.build(input: previousResult.correctGraph)
        // TODO: ここから先も差分ベースにする
        // 辞書ルックアップによりconvertGraphを構築
        print(#file, "lookup", previousResult.inputGraph)
        let convertGraph = self.dicdataStore.buildConvertGraph(inputGraph: previousResult.inputGraph, option: option)
        print(#file, "convert")
        let result = convertGraph.convertAll(option: option, dicdataStore: self.dicdataStore)
        return Result(endNode: result, correctGraph: previousResult.correctGraph, inputGraph: previousResult.inputGraph, convertGraph: convertGraph)
    }
}

private extension ConvertGraph.LatticeNode {
    func joinedPrevs() -> [String] {
        var result: [String] = []
        for prev in self.prevs {
            var words = [self.data.word, prev.data.word]
            var curPrev: (any RegisteredNodeProtocol) = prev
            while let newPrev = curPrev.prev {
                words.append(newPrev.data.word)
                curPrev = newPrev
            }
            result.append(words.reversed().joined())
        }
        return result
    }
}

final class ExperimentalConversionTests: XCTestCase {
    func requestOptions() -> ConvertRequestOptions {
        .withDefaultDictionary(requireJapanesePrediction: false, requireEnglishPrediction: false, keyboardLanguage: .ja_JP, learningType: .nothing, memoryDirectoryURL: URL(fileURLWithPath: ""), sharedContainerURL: URL(fileURLWithPath: ""), metadata: .init(appVersionString: "Test"))
    }

    func testBuildConvertGraph_たいかく() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        var c = ComposingText()
        c.insertAtCursorPosition("たいかく", inputStyle: .direct)
        let correctGraph = CorrectGraph.build(input: c.input)
        let inputGraph = InputGraph.build(input: consume correctGraph)
        let convertGraph = dicdataStore.buildConvertGraph(inputGraph: inputGraph, option: requestOptions())
        XCTAssertEqual(
            convertGraph.nodes.first {
                $0.latticeNodes.contains(where: {$0.data.word == "他"})
            }?.latticeNodes.mapSet {$0.data.ruby}
            .symmetricDifference(["タ", "タイ", "タイカ", "タイガ", "タイカク", "タイガク"]),
            []
        )
    }

    func testConversion_たい() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingText()
        c.insertAtCursorPosition("たい", inputStyle: .direct)
        let result = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(result.endNode.joinedPrevs().contains("タイ")) // たい
        XCTAssertTrue(result.endNode.joinedPrevs().contains("台")) // たい
    }

    func testConversion_いか() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingText()
        c.insertAtCursorPosition("いか", inputStyle: .direct)
        let result = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(result.endNode.joinedPrevs().contains("以下")) // いか
        XCTAssertTrue(result.endNode.joinedPrevs().contains("伊賀")) // いが
        print(result.endNode.joinedPrevs())
    }

    func testConversion_たいか() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingText()
        c.insertAtCursorPosition("たいか", inputStyle: .direct)
        let result = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(result.endNode.joinedPrevs().contains("対価")) // たいか
        XCTAssertTrue(result.endNode.joinedPrevs().contains("大河")) // たいが
        // FIXME: 「たいいか」が入っている
        print(result.endNode.joinedPrevs())
    }

    func testConversion_たいかく() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingText()
        c.insertAtCursorPosition("たいかく", inputStyle: .direct)
        let result = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(result.endNode.joinedPrevs().contains("体格")) // たいかく
        XCTAssertTrue(result.endNode.joinedPrevs().contains("退学")) // たいがく
    }

    func testConversion_むらさき() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingText()
        c.insertAtCursorPosition("むらさき", inputStyle: .direct)
        let result = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(result.endNode.joinedPrevs().contains("紫")) // むらさき
    }

    func testBuildConvertGraph_youshouki() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        var c = ComposingText()
        c.insertAtCursorPosition("youshouki", inputStyle: .roman2kana)
        let correctGraph = CorrectGraph.build(input: c.input)
        let inputGraph = InputGraph.build(input: consume correctGraph)
        let convertGraph = dicdataStore.buildConvertGraph(inputGraph: inputGraph, option: requestOptions())
        XCTAssertEqual(
            convertGraph.nodes.first {
                $0.latticeNodes.contains(where: {$0.data.word == "世"})
            }?.latticeNodes.mapSet {$0.data.ruby}
                .symmetricDifference(["ヨ", "ヨウ", "ヨウシ", "ヨウショ", "ヨウショウ", "ヨウショウキ"]),
            []
        )
    }

    func testConversion_youshouki() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingText()
        c.insertAtCursorPosition("youshouki", inputStyle: .roman2kana)
        let result = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(result.endNode.joinedPrevs().contains("幼少期")) // ようしょうき
    }

    func testConversion_みらいえいが() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        do {
            var c = ComposingText()
            c.insertAtCursorPosition("みらいえいが", inputStyle: .direct)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("未来映画"))
        }
        do {
            var c = ComposingText()
            c.insertAtCursorPosition("miraieiga", inputStyle: .roman2kana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("未来映画"))
        }
    }

    func testConversion() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        do {
            var c = ComposingText()
            c.insertAtCursorPosition("sitta", inputStyle: .roman2kana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("知った"))
        }
        do {
            var c = ComposingText()
            c.insertAtCursorPosition("unda", inputStyle: .roman2kana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("産んだ"))
        }
        do {
            var c = ComposingText()
            c.insertAtCursorPosition("ixtsuta", inputStyle: .roman2kana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("言った"))
        }
        do {
            var c = ComposingText()
            c.insertAtCursorPosition("its", inputStyle: .roman2kana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("いた"))
        }
        do {
            var c = ComposingText()
            c.insertAtCursorPosition("itsi", inputStyle: .roman2kana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            print(result.endNode.joinedPrevs())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("痛い"))
        }
    }

    func testConversion_incremental_たい() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingText()
        c.insertAtCursorPosition("たい", inputStyle: .direct)
        let firstResult = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(firstResult.endNode.joinedPrevs().contains("タイ")) // たい
        XCTAssertTrue(firstResult.endNode.joinedPrevs().contains("台")) // たい
        c.insertAtCursorPosition("こ", inputStyle: .direct)
        let secondResult = kana2kanji._experimental_additional(
            composingText: c,
            additionalInputsStartIndex: 2,
            previousResult: firstResult,
            option: requestOptions()
        )
        XCTAssertTrue(secondResult.endNode.joinedPrevs().contains("太鼓")) // たいこ
        XCTAssertTrue(secondResult.endNode.joinedPrevs().contains("太古")) // たいこ
    }
}
