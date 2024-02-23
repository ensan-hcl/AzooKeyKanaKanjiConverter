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


final class ExperimentalConversionTests: XCTestCase {
    func requestOptions() -> ConvertRequestOptions {
        .withDefaultDictionary(requireJapanesePrediction: false, requireEnglishPrediction: false, keyboardLanguage: .ja_JP, learningType: .nothing, memoryDirectoryURL: .applicationDirectory, sharedContainerURL: .applicationDirectory, metadata: .init(appVersionString: "Test"))
    }

    func testConversion() throws {
        let dicdataStore = DicdataStore(requestOptions: requestOptions())
        let kana2kanji = Kana2Kanji(dicdataStore: dicdataStore)
        var c = ComposingText()
        c.insertAtCursorPosition("あいうえお", inputStyle: .direct) // あいうえお|
        let result = kana2kanji._experimental_all(c, option: requestOptions())
    }
}
