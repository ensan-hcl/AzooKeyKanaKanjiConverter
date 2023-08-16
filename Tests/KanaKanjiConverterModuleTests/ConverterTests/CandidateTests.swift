//
//  CandidateTests.swift
//  
//
//  Created by miwa on 2023/08/16.
//

import XCTest
@testable import KanaKanjiConverterModule

@MainActor final class CandidateTests: XCTestCase {
    // テンプレートのパース
    func testParseTemplate() throws {
        do {
            let text = #"<random type="int" value="1,3">"#
            let candidate = Candidate(
                text: text,
                value: -40,
                correspondingCount: 4,
                lastMid: 5,
                data: [DicdataElement(word: text, ruby: "サイコロ", cid: 0, mid: 5, value: -40)]
            )
            // ランダムなので繰り返し実行しておく
            for _ in 0 ..< 10 {
                var candidate2 = candidate
                candidate2.parseTemplate()
                print(candidate2.text)
                XCTAssertTrue(Set((1...3).map(String.init)).contains(candidate2.text))
                XCTAssertEqual(candidate.value, candidate2.value)
                XCTAssertEqual(candidate.correspondingCount, candidate2.correspondingCount)
                XCTAssertEqual(candidate.lastMid, candidate2.lastMid)
                XCTAssertEqual(candidate.data, candidate2.data)
                XCTAssertEqual(candidate.actions, candidate2.actions)
            }
        }
        do {
            let text = #"\n"#
            let candidate = Candidate(
                text: text,
                value: 0,
                correspondingCount: 0,
                lastMid: 0,
                data: [DicdataElement(word: text, ruby: "", cid: 0, mid: 0, value: 0)]
            )
            var candidate2 = candidate
                candidate2.parseTemplate()
            XCTAssertEqual(candidate.text, candidate2.text)
        }
    }
}
