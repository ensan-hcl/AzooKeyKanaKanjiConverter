//
//  JapaneseNumberConversionTests.swift
//  KanaKanjiConverterModuleTests
//
//  Created by ensan on 2023/04/18.
//  Copyright © 2023 ensan. All rights reserved.
//

@testable import KanaKanjiConverterModule
import XCTest

final class JapaneseNumberConversionTests: XCTestCase {
    func testJapaneseNumberConversion() async throws {
        let dicdataStore = DicdataStore()
        do {
            let result = await dicdataStore.getJapaneseNumberDicdata(head: "イチマン")
            XCTAssertEqual(result.count, 2)
            XCTAssertTrue(result.contains(where: {$0.word == "一万"}))
            XCTAssertTrue(result.contains(where: {$0.word == "10000"}))
        }
        do {
            let result = await dicdataStore.getJapaneseNumberDicdata(head: "ニオクロクセンヨンヒャクマンキュウ")
            XCTAssertEqual(result.count, 2)
            XCTAssertTrue(result.contains(where: {$0.word == "二億六千四百万九"}))
            XCTAssertTrue(result.contains(where: {$0.word == "264000009"}))
        }
        do {
            
            await XCTAssertEqualAsync(await dicdataStore.getJapaneseNumberDicdata(head: "マルマン").count, 0)
            await XCTAssertEqualAsync(await dicdataStore.getJapaneseNumberDicdata(head: "アマン").count, 0)
            await XCTAssertEqualAsync(await dicdataStore.getJapaneseNumberDicdata(head: "イチリン").count, 0)
            await XCTAssertEqualAsync(await dicdataStore.getJapaneseNumberDicdata(head: "ニムリョウタイスウサンガイ").count, 0)
        }
    }
}
