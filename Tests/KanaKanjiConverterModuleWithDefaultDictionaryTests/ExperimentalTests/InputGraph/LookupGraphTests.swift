//
//  LookupGraphTests.swift
//
//
//  Created by miwa on 2024/02/23.
//

import XCTest
import Foundation
@testable import KanaKanjiConverterModule

final class LookupGraphTests: XCTestCase {
    func requestOptions() -> ConvertRequestOptions {
        .withDefaultDictionary(requireJapanesePrediction: false, requireEnglishPrediction: false, keyboardLanguage: .ja_JP, learningType: .nothing, memoryDirectoryURL: URL(fileURLWithPath: ""), sharedContainerURL: URL(fileURLWithPath: ""), metadata: .init(appVersionString: "Test"))
    }

    func setup() -> (dicdataStore: DicdataStore, character2CharId: (Character) -> UInt8) {
        let dicdataStore = DicdataStore(convertRequestOptions: requestOptions())
        let character2CharId: (Character) -> UInt8 = { dicdataStore.character2charId($0.toKatakana()) }
        return (dicdataStore, character2CharId)
    }

    func testByfixNodeIndices_しかい() throws {
        let values = setup()
        guard let louds = LOUDS.load("シ", option: requestOptions()) else {
            XCTFail()
            return
        }
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "し", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        var lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: values.character2CharId)
        let startNodeIndex = inputGraph.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph.nodes[$0].character == "し" })
        XCTAssertNotNil(startNodeIndex)
        let (loudsNodeIndices, _) = lookupGraph.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex ?? 0)
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "シ", indices: loudsNodeIndices, option: requestOptions())
        let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
        // シ
        XCTAssertTrue(dicdata.contains {$0.word == "死"})
        // シカ
        XCTAssertTrue(dicdata.contains {$0.word == "鹿"})
        XCTAssertTrue(dicdata.contains {$0.word == "歯科"})
        // シガ
        XCTAssertTrue(dicdata.contains {$0.word == "滋賀"})
        // シカイ
        XCTAssertTrue(dicdata.contains {$0.word == "司会"})
        XCTAssertTrue(dicdata.contains {$0.word == "視界"})
        XCTAssertTrue(dicdata.contains {$0.word == "死界"})
        // シガイ
        XCTAssertTrue(dicdata.contains {$0.word == "市外"})
        XCTAssertTrue(dicdata.contains {$0.word == "市街"})
        XCTAssertTrue(dicdata.contains {$0.word == "死骸"})

        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["シ", "シカ", "シカイ", "シガ", "シガイ"]),
            []
        )
    }

    func testByfixNodeIndices_みらい() throws {
        let values = setup()
        guard let louds = LOUDS.load("ミ", option: requestOptions()) else {
            XCTFail()
            return
        }
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "み", inputStyle: .direct),
            .init(character: "ら", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        var lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: values.character2CharId)
        let startNodeIndex = lookupGraph.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph.nodes[$0].character == "み" })
        XCTAssertNotNil(startNodeIndex)
        let (loudsNodeIndices, _) = lookupGraph.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex ?? 0)
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "ミ", indices: loudsNodeIndices, option: requestOptions())
        let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
        // ミ
        XCTAssertTrue(dicdata.contains {$0.word == "見"})
        // ミラ
        XCTAssertTrue(dicdata.contains {$0.word == "ミラ"})
        // ミライ
        XCTAssertTrue(dicdata.contains {$0.word == "未来"})

        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["ミ", "ミラ", "ミライ"]),
            []
        )
    }

    func testByfixNodeIndices_たいかく() throws {
        let values = setup()
        guard let louds = LOUDS.load("タ", option: requestOptions()) else {
            XCTFail()
            return
        }
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "た", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct),
            .init(character: "く", inputStyle: .direct)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        var lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: values.character2CharId)
        let startNodeIndex = lookupGraph.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph.nodes[$0].character == "た" })
        XCTAssertNotNil(startNodeIndex)
        let (loudsNodeIndices, _) = lookupGraph.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex ?? 0)
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "タ", indices: loudsNodeIndices, option: requestOptions())
        let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
        // タ
        XCTAssertTrue(dicdata.contains {$0.word == "他"})
        // タイ
        XCTAssertTrue(dicdata.contains {$0.word == "タイ"})
        XCTAssertTrue(dicdata.contains {$0.word == "他意"})
        // タイカ
        XCTAssertTrue(dicdata.contains {$0.word == "対価"})
        // タイガ
        XCTAssertTrue(dicdata.contains {$0.word == "大河"})
        // タイカク
        XCTAssertTrue(dicdata.contains {$0.word == "体格"})
        // タイガク
        XCTAssertTrue(dicdata.contains {$0.word == "退学"})
        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["タ", "タイ", "タイカ", "タイガ", "タイカク", "タイガク"]),
            []
        )
    }

    func testByfixNodeIndices_sittai() throws {
        let values = setup()
        guard let louds = LOUDS.load("シ", option: requestOptions()) else {
            XCTFail()
            return
        }
        // 「しっ」の候補が存在するかどうかを確認
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "a", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        var lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: values.character2CharId)
        let startNodeIndex = lookupGraph.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph.nodes[$0].character == "し" })
        XCTAssertNotNil(startNodeIndex)
        let (loudsNodeIndices, _) = lookupGraph.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex ?? 0)
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "シ", indices: loudsNodeIndices, option: requestOptions())
        let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
        // シ
        XCTAssertTrue(dicdata.contains {$0.word == "死"})
        // シッ
        XCTAssertTrue(dicdata.contains {$0.word == "知っ"})
        XCTAssertTrue(dicdata.contains {$0.word == "しっ"})
        // シッタ
        XCTAssertTrue(dicdata.contains {$0.word == "叱咤"})
        // シッタイ
        XCTAssertTrue(dicdata.contains {$0.word == "失態"})
        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["シ", "シッ", "シッタ", "シッタイ"]),
            []
        )
    }

    func testByfixNodeIndices_sitsi() throws {
        let values = setup()
        guard let louds = LOUDS.load("シ", option: requestOptions()) else {
            XCTFail()
            return
        }
        // ts -> ta
        let correctGraph = CorrectGraph.build(input: [
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana),
            .init(character: "t", inputStyle: .roman2kana),
            .init(character: "s", inputStyle: .roman2kana),
            .init(character: "i", inputStyle: .roman2kana)
        ])
        let inputGraph = InputGraph.build(input: correctGraph)
        var lookupGraph = LookupGraph.build(input: inputGraph, character2CharId: values.character2CharId)
        let startNodeIndex = lookupGraph.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph.nodes[$0].character == "し" })
        XCTAssertNotNil(startNodeIndex)
        let (loudsNodeIndices, _) = lookupGraph.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex ?? 0)
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "シ", indices: loudsNodeIndices, option: requestOptions())
        let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
        // シ
        XCTAssertTrue(dicdata.contains {$0.word == "死"})
        // [シツ]ィ
        XCTAssertTrue(dicdata.contains {$0.word == "質"})
        XCTAssertTrue(dicdata.contains {$0.word == "室"})
        // シタ
        XCTAssertTrue(dicdata.contains {$0.word == "下"})
        XCTAssertTrue(dicdata.contains {$0.word == "舌"})
        // シタイ
        XCTAssertTrue(dicdata.contains {$0.word == "死体"})
        XCTAssertTrue(dicdata.contains {$0.word == "肢体"})
        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["シ", "シツ", "シタ", "シタイ"]),
            []
        )
    }

    func testByfixNodeIndices_たいか_add_く() throws {
        let values = setup()
        guard let louds = LOUDS.load("タ", option: requestOptions()) else {
            XCTFail()
            return
        }
        let correctGraph1 = CorrectGraph.build(input: [
            .init(character: "た", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct)
        ])
        let inputGraph1 = InputGraph.build(input: correctGraph1)
        var lookupGraph1 = LookupGraph.build(input: inputGraph1, character2CharId: values.character2CharId)
        let startNodeIndex1 = lookupGraph1.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph1.nodes[$0].character == "た" })
        XCTAssertNotNil(startNodeIndex1)
        _ = lookupGraph1.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex1 ?? 0)

        let correctGraph2 = CorrectGraph.build(input: [
            .init(character: "た", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct),
            .init(character: "く", inputStyle: .direct) // added
        ])
        let inputGraph2 = InputGraph.build(input: correctGraph2)
        var lookupGraph2 = LookupGraph.build(input: inputGraph2, character2CharId: values.character2CharId)
        let startNodeIndex2 = lookupGraph2.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph2.nodes[$0].character == "た" })
        XCTAssertNotNil(startNodeIndex2)
        var matchInfo: [Int: Int] = [:]
        let (loudsNodeIndices2, _) = lookupGraph2.differentialByfixSearch(in: louds, cacheLookupGraph: lookupGraph1, graphNodeIndex: (startNodeIndex2 ?? 0, startNodeIndex1 ?? 0), lookupGraphMatch: &matchInfo)
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "タ", indices: loudsNodeIndices2, option: requestOptions())
        let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
        // タ
        XCTAssertTrue(dicdata.contains {$0.word == "他"})
        // タイ
        XCTAssertTrue(dicdata.contains {$0.word == "タイ"})
        XCTAssertTrue(dicdata.contains {$0.word == "他意"})
        // タイカ
        XCTAssertTrue(dicdata.contains {$0.word == "対価"})
        // タイガ
        XCTAssertTrue(dicdata.contains {$0.word == "大河"})
        // タイカク
        XCTAssertTrue(dicdata.contains {$0.word == "体格"})
        // タイガク
        XCTAssertTrue(dicdata.contains {$0.word == "退学"})
        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["タ", "タイ", "タイカ", "タイガ", "タイカク", "タイガク"]),
            []
        )
    }

    func testByfixNodeIndices_たいか_remove_く() throws {
        let values = setup()
        guard let louds = LOUDS.load("タ", option: requestOptions()) else {
            XCTFail()
            return
        }
        let correctGraph1 = CorrectGraph.build(input: [
            .init(character: "た", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct),
            .init(character: "か", inputStyle: .direct)
        ])
        let inputGraph1 = InputGraph.build(input: correctGraph1)
        var lookupGraph1 = LookupGraph.build(input: inputGraph1, character2CharId: values.character2CharId)
        let startNodeIndex1 = lookupGraph1.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph1.nodes[$0].character == "た" })
        XCTAssertNotNil(startNodeIndex1)
        _ = lookupGraph1.byfixNodeIndices(in: louds, startGraphNodeIndex: startNodeIndex1 ?? 0)

        let correctGraph2 = CorrectGraph.build(input: [
            .init(character: "た", inputStyle: .direct),
            .init(character: "い", inputStyle: .direct)
        ])
        let inputGraph2 = InputGraph.build(input: correctGraph2)
        var lookupGraph2 = LookupGraph.build(input: inputGraph2, character2CharId: values.character2CharId)
        let startNodeIndex2 = lookupGraph2.allowedNextIndex[0, default: IndexSet()].first(where: { lookupGraph2.nodes[$0].character == "た" })
        XCTAssertNotNil(startNodeIndex2)
        var matchInfo: [Int: Int] = [:]
        let (loudsNodeIndices2, _) = lookupGraph2.differentialByfixSearch(in: louds, cacheLookupGraph: lookupGraph1, graphNodeIndex: (startNodeIndex2 ?? 0, startNodeIndex1 ?? 0), lookupGraphMatch: &matchInfo)
        let dicdataWithIndex = values.dicdataStore.getDicdataFromLoudstxt3(identifier: "タ", indices: loudsNodeIndices2, option: requestOptions())
        let dicdata = dicdataWithIndex.flatMapSet { $0.dicdata }
        // タ
        XCTAssertTrue(dicdata.contains {$0.word == "他"})
        // タイ
        XCTAssertTrue(dicdata.contains {$0.word == "タイ"})
        XCTAssertTrue(dicdata.contains {$0.word == "他意"})
        // タイカ
        XCTAssertFalse(dicdata.contains {$0.ruby == "タイカ"})
        // タイガ
        XCTAssertFalse(dicdata.contains {$0.ruby == "タイガ"})
        // all keys
        XCTAssertEqual(
            dicdata.mapSet {$0.ruby}.symmetricDifference(["タ", "タイ"]),
            []
        )
    }
}
