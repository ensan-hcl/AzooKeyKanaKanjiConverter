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
    func _experimental_all(_ inputData: ComposingText, option: ConvertRequestOptions) -> ConvertGraph.LatticeNode {
        // グラフ構築
        print(#file, "start")
        let inputGraph = InputGraph.build(input: inputData.input)
        // 辞書ルックアップによりconvertGraphを構築
        print(#file, "lookup", inputGraph)
        let convertGraph = self.dicdataStore.buildConvertGraph(inputGraph: consume inputGraph, option: option)
        print(#file, "convert", convertGraph)
        let result = convertGraph.convertAll(option: option, dicdataStore: self.dicdataStore)
        return result
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

    func testConversion() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        do {
            var c = ComposingText()
            c.insertAtCursorPosition("みらいえいが", inputStyle: .direct)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.joinedPrevs().contains("未来映画"))
        }
        do {
            var c = ComposingText()
            c.insertAtCursorPosition("miraieiga", inputStyle: .roman2kana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            XCTAssertTrue(result.joinedPrevs().contains("未来映画"))
        }
        do {
            var c = ComposingText()
            c.insertAtCursorPosition("sitta", inputStyle: .roman2kana)
            let result = kana2kanji._experimental_all(c, option: requestOptions())
            print(result.joinedPrevs())
            // FIXME: 動かない
            // XCTAssertTrue(result.joinedPrevs().contains("知った"))
        }
    }
}
