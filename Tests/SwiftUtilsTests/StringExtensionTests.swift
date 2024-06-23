//
//  StringExtensionTests.swift
//  azooKeyTests
//
//  Created by ensan on 2022/12/23.
//  Copyright © 2022 ensan. All rights reserved.
//

@testable import SwiftUtils
import XCTest

final class StringExtensionTests: XCTestCase {

    func testToKatakana() throws {
        XCTAssertEqual("かゔぁあーんじょ123+++リスク".toKatakana(), "カヴァアーンジョ123+++リスク")
        XCTAssertEqual("".toKatakana(), "")
        XCTAssertEqual("コレハロン".toKatakana(), "コレハロン")
    }

    func testToHiragana() throws {
        XCTAssertEqual("カヴァアーンじょ123+++リスク".toHiragana(), "かゔぁあーんじょ123+++りすく")
        XCTAssertEqual("".toHiragana(), "")
        XCTAssertEqual("これはろん".toHiragana(), "これはろん")
    }
}
