//
//  extension Kana2Kanji+InputGraph.swift
//  
//
//  Created by miwa on 2024/02/23.
//

import Foundation
@testable import KanaKanjiConverterModule


extension Kana2Kanji {
    func _experimental_all(_ inputData: ComposingText, N_best: Int) -> ConvertGraph.LatticeNode {
        // グラフ構築
        let inputGraph = InputGraph.build(input: inputData.input)
        // 辞書ルックアップによりconvertGraphを構築
        let convertGraph = self.dicdataStore.buildConvertGraph(inputGraph: consume inputGraph, option: .default)
        let result = convertGraph.convertAll(N_best: N_best, dicdataStore: self.dicdataStore)
        return result
    }
}

