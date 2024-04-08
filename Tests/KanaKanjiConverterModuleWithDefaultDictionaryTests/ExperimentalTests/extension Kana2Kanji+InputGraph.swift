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
        var lookupGraph: LookupGraph
        var convertGraph: ConvertGraph
    }
    func _experimental_all(_ inputData: ComposingTextV2, option: ConvertRequestOptions) -> Result {
        // グラフ構築
        print(#file, "start")
        let correctGraph = CorrectGraph.build(input: inputData.input)
        let inputGraph = InputGraph.build(input: correctGraph)
        // 辞書ルックアップによりconvertGraphを構築
        print(#file, "lookup", inputGraph)
        let (lookupGraph, convertGraph) = self.dicdataStore.buildConvertGraph(inputGraph: inputGraph, option: option)
        print(#file, "convert")
        let result = convertGraph.convertAll(option: option, dicdataStore: self.dicdataStore)
        return Result(endNode: result, correctGraph: correctGraph, inputGraph: inputGraph, lookupGraph: lookupGraph, convertGraph: convertGraph)
    }

    func _experimental_additional(
        composingText: ComposingTextV2,
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
        // 辞書ルックアップによりconvertGraphを構築
        print(#file, "lookup", previousResult.inputGraph)
        var (lookupGraph, convertGraph, matchInfo) = self.dicdataStore.buildConvertGraphDifferential(inputGraph: inputGraph, cacheLookupGraph: previousResult.lookupGraph, option: option)
        print(#file, "convert")
        let result = convertGraph.convertAllDifferential(cacheConvertGraph: previousResult.convertGraph, option: option, dicdataStore: self.dicdataStore, lookupGraphMatchInfo: matchInfo)
        return Result(endNode: result, correctGraph: previousResult.correctGraph, inputGraph: inputGraph, lookupGraph: lookupGraph, convertGraph: convertGraph)
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
        var c = ComposingTextV2()
        c.append("たいかく", inputStyle: .systemFlickDirect)
        let correctGraph = CorrectGraph.build(input: c.input)
        let inputGraph = InputGraph.build(input: consume correctGraph)
        let (_, convertGraph) = dicdataStore.buildConvertGraph(inputGraph: inputGraph, option: requestOptions())
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
        var c = ComposingTextV2()
        c.append("たい", inputStyle: .systemFlickDirect)
        let result = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(result.endNode.joinedPrevs().contains("タイ")) // たい
        XCTAssertTrue(result.endNode.joinedPrevs().contains("台")) // たい
    }

    func testConversion_いか() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingTextV2()
        c.append("いか", inputStyle: .systemFlickDirect)
        let result = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(result.endNode.joinedPrevs().contains("以下")) // いか
        XCTAssertTrue(result.endNode.joinedPrevs().contains("伊賀")) // いが
    }

    func testConversion_かかく() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingTextV2()
        c.append("かかく", inputStyle: .systemFlickDirect)
        let result = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(result.endNode.joinedPrevs().contains("価格")) // かかく
        XCTAssertTrue(result.endNode.joinedPrevs().contains("科学")) // かがく
        XCTAssertTrue(result.endNode.joinedPrevs().contains("画角")) // がかく
        XCTAssertTrue(result.endNode.joinedPrevs().contains("雅楽")) // ががく
    }

    func testConversion_たいか() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingTextV2()
        c.append("たいか", inputStyle: .systemFlickDirect)
        let result = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(result.endNode.joinedPrevs().contains("対価")) // たいか
        XCTAssertTrue(result.endNode.joinedPrevs().contains("大河")) // たいが
    }

    func testConversion_たいかく() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingTextV2()
        c.append("たいかく", inputStyle: .systemFlickDirect)
        let result = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(result.endNode.joinedPrevs().contains("体格")) // たいかく
        XCTAssertTrue(result.endNode.joinedPrevs().contains("退学")) // たいがく
    }

    func testConversion_むらさき() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingTextV2()
        c.append("むらさき", inputStyle: .systemFlickDirect)
        let result = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(result.endNode.joinedPrevs().contains("紫")) // むらさき
    }

    func testBuildConvertGraph_youshouki() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        var c = ComposingTextV2()
        c.append("youshouki", inputStyle: .systemRomanKana)
        let correctGraph = CorrectGraph.build(input: c.input)
        let inputGraph = InputGraph.build(input: consume correctGraph)
        let (_, convertGraph) = dicdataStore.buildConvertGraph(inputGraph: inputGraph, option: requestOptions())
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
        var c = ComposingTextV2()
        c.append("youshouki", inputStyle: .systemRomanKana)
        let result = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(result.endNode.joinedPrevs().contains("幼少期")) // ようしょうき
    }

    func testConversion_みらいえいが() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        do {
            var c = ComposingTextV2()
            c.append("みらいえいが", inputStyle: .systemFlickDirect)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("未来映画"))
        }
        do {
            var c = ComposingTextV2()
            c.append("miraieiga", inputStyle: .systemRomanKana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("未来映画"))
        }
    }

    func testConversion() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        do {
            var c = ComposingTextV2()
            c.append("sitta", inputStyle: .systemRomanKana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("知った"))
        }
        do {
            var c = ComposingTextV2()
            c.append("unda", inputStyle: .systemRomanKana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("産んだ"))
        }
        do {
            var c = ComposingTextV2()
            c.append("ixtsuta", inputStyle: .systemRomanKana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("言った"))
        }
        do {
            var c = ComposingTextV2()
            c.append("its", inputStyle: .systemRomanKana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("いた"))
        }
        do {
            var c = ComposingTextV2()
            c.append("itsi", inputStyle: .systemRomanKana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.endNode.joinedPrevs().contains("痛い"))
        }
    }

    func testConversion_incremental_たい() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingTextV2()
        c.append("たい", inputStyle: .systemFlickDirect)
        let firstResult = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(firstResult.endNode.joinedPrevs().contains("タイ")) // たい
        XCTAssertTrue(firstResult.endNode.joinedPrevs().contains("台")) // たい
        c.append("こ", inputStyle: .systemFlickDirect)
        let secondResult = kana2kanji._experimental_additional(
            composingText: c,
            additionalInputsStartIndex: 2,
            previousResult: firstResult,
            option: requestOptions()
        )
        XCTAssertTrue(secondResult.endNode.joinedPrevs().contains("太鼓")) // たいこ
        XCTAssertTrue(secondResult.endNode.joinedPrevs().contains("太古")) // たいこ
        c.append("く", inputStyle: .systemFlickDirect)
        let thirdResult = kana2kanji._experimental_additional(
            composingText: c,
            additionalInputsStartIndex: 3,
            previousResult: secondResult,
            option: requestOptions()
        )
        XCTAssertTrue(thirdResult.endNode.joinedPrevs().contains("大国")) // たいこく
    }

    func testConversion_incremental_intai() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingTextV2()
        c.append("i", inputStyle: .systemRomanKana)
        let firstResult = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(firstResult.endNode.joinedPrevs().contains("胃")) // い
        c.append("n", inputStyle: .systemRomanKana)
        let secondResult = kana2kanji._experimental_additional(
            composingText: c,
            additionalInputsStartIndex: 1,
            previousResult: firstResult,
            option: requestOptions()
        )
        print(secondResult.endNode.joinedPrevs())
        c.append("t", inputStyle: .systemRomanKana)
        let thirdResult = kana2kanji._experimental_additional(
            composingText: c,
            additionalInputsStartIndex: 2,
            previousResult: secondResult,
            option: requestOptions()
        )
        print(thirdResult.endNode.joinedPrevs())
        c.append("a", inputStyle: .systemRomanKana)
        let forthResult = kana2kanji._experimental_additional(
            composingText: c,
            additionalInputsStartIndex: 3,
            previousResult: thirdResult,
            option: requestOptions()
        )
        XCTAssertTrue(forthResult.endNode.joinedPrevs().contains("インタ")) // インタ
        c.append("i", inputStyle: .systemRomanKana)
        let fifthResult = kana2kanji._experimental_additional(
            composingText: c,
            additionalInputsStartIndex: 4,
            previousResult: forthResult,
            option: requestOptions()
        )
        XCTAssertTrue(fifthResult.endNode.joinedPrevs().contains("引退")) // インタイ
    }

    func testConversion_incremental_intsi() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingTextV2()
        c.append("i", inputStyle: .systemRomanKana)
        let firstResult = kana2kanji._experimental_all(c, option: requestOptions())
        XCTAssertTrue(firstResult.endNode.joinedPrevs().contains("胃")) // い
        c.append("n", inputStyle: .systemRomanKana)
        let secondResult = kana2kanji._experimental_additional(
            composingText: c,
            additionalInputsStartIndex: 1,
            previousResult: firstResult,
            option: requestOptions()
        )
        //        XCTAssertTrue(secondResult.endNode.joinedPrevs().contains("胃n")) // in
        c.append("t", inputStyle: .systemRomanKana)
        let thirdResult = kana2kanji._experimental_additional(
            composingText: c,
            additionalInputsStartIndex: 2,
            previousResult: secondResult,
            option: requestOptions()
        )
        //        XCTAssertTrue(thirdResult.endNode.joinedPrevs().contains("インt")) // int
        c.append("s", inputStyle: .systemRomanKana)
        let forthResult = kana2kanji._experimental_additional(
            composingText: c,
            additionalInputsStartIndex: 3,
            previousResult: thirdResult,
            option: requestOptions()
        )
        XCTAssertTrue(forthResult.endNode.joinedPrevs().contains("インタ")) // インタ
        c.append("i", inputStyle: .systemRomanKana)
        let fifthResult = kana2kanji._experimental_additional(
            composingText: c,
            additionalInputsStartIndex: 4,
            previousResult: forthResult,
            option: requestOptions()
        )
        XCTAssertTrue(fifthResult.endNode.joinedPrevs().contains("引退")) // インタイ
    }
}
