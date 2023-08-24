//
//  extension Data.swift
//  Keyboard
//
//  Created by ensan on 2020/09/30.
//  Copyright © 2020 ensan. All rights reserved.
//

import Foundation
import SwiftUtils

extension LOUDS {
    private static func loadLOUDSBinary(from url: borrowing URL) -> [UInt64]? {
        do {
            let binaryData = try Data(contentsOf: url, options: [.uncached,  .mappedIfSafe]) // 2度読み込むことはないのでキャッシュ不要
            let ui64array = binaryData.toArray(of: UInt64.self)
            return ui64array
        } catch {
            debug(error)
            return nil
        }
    }

    private static func getLOUDSURL(_ identifier: String, option: borrowing ConvertRequestOptions) -> (chars: URL, louds: URL) {

        if identifier == "user"{
            return (
                option.sharedContainerURL.appendingPathComponent("user.loudschars2", isDirectory: false),
                option.sharedContainerURL.appendingPathComponent("user.louds", isDirectory: false)
            )
        }
        if identifier == "memory"{
            return (
                option.memoryDirectoryURL.appendingPathComponent("memory.loudschars2", isDirectory: false),
                option.memoryDirectoryURL.appendingPathComponent("memory.louds", isDirectory: false)
            )
        }
        return (
            option.dictionaryResourceURL.appendingPathComponent("louds/\(identifier).loudschars2", isDirectory: false),
            option.dictionaryResourceURL.appendingPathComponent("louds/\(identifier).louds", isDirectory: false)
        )
    }

    private static func getLoudstxt3URL(_ identifier: String, option: borrowing ConvertRequestOptions) -> URL {
        if identifier.hasPrefix("user") {
            return option.sharedContainerURL.appendingPathComponent("\(identifier).loudstxt3", isDirectory: false)
        }
        if identifier.hasPrefix("memory") {
            return option.memoryDirectoryURL.appendingPathComponent("\(identifier).loudstxt3", isDirectory: false)
        }
        return option.dictionaryResourceURL.appendingPathComponent("louds/\(identifier).loudstxt3", isDirectory: false)
    }

    /// LOUDSをファイルから読み込む関数
    /// - Parameter identifier: ファイル名
    /// - Returns: 存在すればLOUDSデータを返し、存在しなければ`nil`を返す。
    @inlinable
    static func load(_ identifier: String, option: borrowing ConvertRequestOptions) -> LOUDS? {
        let (charsURL, loudsURL) = getLOUDSURL(identifier, option: option)
        let nodeIndex2ID: [UInt8]
        do {
            nodeIndex2ID = try Array(Data(contentsOf: charsURL, options: [.uncached, .mappedIfSafe]))   // 2度読み込むことはないのでキャッシュ不要
        } catch {
            debug("ファイルが存在しません: \(error)")
            return nil
        }

        if let bytes = LOUDS.loadLOUDSBinary(from: loudsURL) {
            let louds = LOUDS(bytes: bytes.map {$0.littleEndian}, nodeIndex2ID: nodeIndex2ID)
            return louds
        }
        return nil
    }

    @inlinable
    static func parseBinary(binary: Data) -> [DicdataElement] {
        // 最初の2byteがカウント
        let count = binary[binary.startIndex ..< binary.startIndex + 2].toArray(of: UInt16.self)[0]
        var index = binary.startIndex + 2
        var dicdata: [DicdataElement] = []
        dicdata.reserveCapacity(Int(count))
        for _ in 0 ..< count {
            let ids = binary[index ..< index + 6].toArray(of: UInt16.self)
            let value = binary[index + 6 ..< index + 10].toArray(of: Float32.self)[0]
            dicdata.append(DicdataElement(word: "", ruby: "", lcid: Int(ids[0]), rcid: Int(ids[1]), mid: Int(ids[2]), value: PValue(value)))
            index += 10
        }

        let substrings = binary[index...].split(separator: UInt8(ascii: "\t"), omittingEmptySubsequences: false)
        guard let ruby = String(data: substrings[0], encoding: .utf8) else {
            debug("getDataForLoudstxt3: failed to parse", dicdata)
            return []
        }
        for (index, substring) in substrings[1...].enumerated() {
            guard let word = String(data: substring, encoding: .utf8) else {
                debug("getDataForLoudstxt3: failed to parse", ruby)
                continue
            }
            withMutableValue(&dicdata[index]) {
                $0.ruby = ruby
                $0.word = word.isEmpty ? ruby : word
            }
        }
        return dicdata

    }

    internal static func getDataForLoudstxt3(_ identifier: String, indices: [Int], option: borrowing ConvertRequestOptions) -> [DicdataElement] {
        let binary: Data
        do {
            let url = getLoudstxt3URL(identifier, option: option)
            binary = try Data(contentsOf: url)
        } catch {
            debug("getDataForLoudstxt3: \(error)")
            return []
        }

        let lc = binary[0..<2].toArray(of: UInt16.self)[0]
        let header_endIndex: UInt32 = 2 + UInt32(lc) * UInt32(MemoryLayout<UInt32>.size)
        let ui32array = binary[2..<header_endIndex].toArray(of: UInt32.self)

        let result: [DicdataElement] = indices.flatMap {(index: Int) -> [DicdataElement] in
            let startIndex = Int(ui32array[index])
            let endIndex = index == (lc - 1) ? binary.endIndex : Int(ui32array[index + 1])
            return parseBinary(binary: binary[startIndex ..< endIndex])
        }
        return result
    }
}
