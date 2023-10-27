//
//  ConversionResult.swift
//
//
//  Created by miwa on 2023/08/31.
//

public struct ConversionResult: Sendable, ~Copyable {
    /// 変換候補欄にこのままの順で並べることのできる候補
    public var mainResults: [Candidate]
    /// 変換候補のうち最初の文節を変換したもの
    public var firstClauseResults: [Candidate]
    /// キャッシュ
    public var cache: KanaKanjiConverter.Cache

    public var result: (mainResults: [Candidate], firstClauseResults: [Candidate]) {
        (self.mainResults, self.firstClauseResults)
    }
}
