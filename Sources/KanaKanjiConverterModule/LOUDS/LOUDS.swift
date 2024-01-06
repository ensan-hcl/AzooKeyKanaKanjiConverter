//
//  LOUDS.swift
//  Keyboard
//
//  Created by ensan on 2020/09/30.
//  Copyright © 2020 ensan. All rights reserved.
//

import Foundation

/// LOUDS
struct LOUDS: Sendable {
    private typealias Unit = UInt64
    private static let unit = 64
    private static let uExp = 6

    private let bits: [Unit]
    private let char2nodeIndices: [[Int]]
    /// 0の数（1の数ではない）
    ///
    /// LOUDSのサイズが4GBまでは`UInt32`で十分
    private let rankLarge: [UInt32]

    @inlinable init(bytes: [UInt64], nodeIndex2ID: [UInt8]) {
        self.bits = bytes
        self.char2nodeIndices = nodeIndex2ID.enumerated().reduce(into: .init(repeating: [], count: 1 << 8)) { list, data in
            list[Int(data.element)].append(data.offset)
        }
        self.rankLarge = bytes.reduce(into: [0]) {
            $0.append($0.last! &+ UInt32(Self.unit &- $1.nonzeroBitCount))
        }
    }

    /// parentNodeIndex個の0を探索し、その次から1個増えるまでのIndexを返す。
    @inlinable func childNodeIndices(from parentNodeIndex: Int) -> Range<Int> {
        // 求めるのは、
        // startIndex == 自身の左側にparentNodeIndex個の0があるような最小のindex
        // endIndex == 自身の左側にparentNodeIndex+1個の0があるような最小のindex
        // すなわち、childNodeIndicesである。
        // まずstartIndexを発見し、そこから0が現れる点を探すことでendIndexを見つける方針で実装している。

        // 探索パート①
        // rankLargeは左側の0の数を示すので、difを取っている
        // まず最低限の絞り込みを行う。leftを探索する。
        // 探しているのは、startIndexが含まれるbitsのindex `i`
        var left = (parentNodeIndex >> Self.uExp) &- 1
        while true {
            let dif = parentNodeIndex &- Int(self.rankLarge[Int(left) &+ 1])
            if dif >= Self.unit {
                left &+= dif >> Self.uExp
            } else {
                break
            }
        }
        var i: Int?
        for index in left &+ 1 ..< self.bits.endIndex where self.rankLarge[index &+ 1] >= parentNodeIndex {
            i = index
            break
        }
        guard let i else {
            return 0 ..< 0
        }

        return self.bits.withUnsafeBufferPointer {(buffer: UnsafeBufferPointer<Unit>) -> Range<Int> in
            // 探索パート②
            // 目標はparentNodeIndex番目の0の位置である`k`の発見
            let byte = buffer[i]
            var k = 0
            for _ in  0 ..< parentNodeIndex - Int(self.rankLarge[i]) {
                k = (~(byte << k)).leadingZeroBitCount &+ k &+ 1
            }
            let start = (i << Self.uExp) &+ k &- parentNodeIndex &+ 1
            // ちょうどparentNodeIndex個の0がi番目にあるかどうか
            if self.rankLarge[i &+ 1] == parentNodeIndex {
                var j = i &+ 1
                while buffer[j] == Unit.max {
                    j &+= 1
                }
                // 最初の0を探す作業
                // 反転して、先頭から0の数を数えると最初の0の位置が出てくる
                // Ex. 1110_0000 => [000]1_1111 => 3
                let byte2 = buffer[j]
                let a = (~byte2).leadingZeroBitCount % Self.unit
                return start ..< (j << Self.uExp) &+ a &- parentNodeIndex &+ 1
            } else {
                // difが0以上の場合、k番目以降の初めての0を発見したい
                // 例えばk=1の場合
                // Ex. 1011_1101 => 0111_1010 => 1000_0101 => 1 => 2
                let a = ((~(byte << k)).leadingZeroBitCount &+ k) % Self.unit
                return start ..< (i << Self.uExp) &+ a &- parentNodeIndex &+ 1
            }
        }
    }

    /// charIndexを取得する
    /// `childNodeIndices`と差し引きして、二分探索部分の速度への影響は高々0.02秒ほど
    @inlinable func searchCharNodeIndex(from parentNodeIndex: Int, char: UInt8) -> Int? {
        // char2nodeIndicesには単調増加性があるので二分探索が成立する
        let childNodeIndices = self.childNodeIndices(from: parentNodeIndex)
        let nodeIndices = self.char2nodeIndices[Int(char)]
        var left = nodeIndices.startIndex
        var right = nodeIndices.endIndex
        while left < right {
            let mid = (left + right) >> 1
            if childNodeIndices.startIndex <= nodeIndices[mid] {
                right = mid
            } else {
                left = mid + 1
            }
        }
        if left < nodeIndices.endIndex && childNodeIndices.contains(nodeIndices[left]) {
            return nodeIndices[left]
        } else {
            return nil
        }
    }

    /// 完全一致検索を実行する
    /// - Parameter chars: CharIDに変換した文字列
    /// - Returns: 対応するloudstxt3ファイル内のインデックス
    @inlinable func searchNodeIndex(chars: [UInt8]) -> Int? {
        var index = 1
        for char in chars {
            if let nodeIndex = self.searchCharNodeIndex(from: index, char: char) {
                index = nodeIndex
            } else {
                return nil
            }
        }
        return index
    }

    @inlinable func prefixNodeIndices(nodeIndex: Int, depth: Int = 0, maxDepth: Int) -> [Int] {
        var childNodeIndices = Array(self.childNodeIndices(from: nodeIndex))
        if depth == maxDepth {
            return childNodeIndices
        }
        for index in childNodeIndices {
            childNodeIndices.append(contentsOf: self.prefixNodeIndices(nodeIndex: index, depth: depth + 1, maxDepth: maxDepth))
        }
        return childNodeIndices
    }

    /// 前方一致検索を実行する
    ///
    /// 「しかい」を入力した場合、そこから先の「しかいし」「しかいしゃ」「しかいいん」なども探す。
    /// - Parameter chars: CharIDに変換した文字列
    /// - Parameter maxDepth: 先に進む深さの最大値
    /// - Returns: 対応するloudstxt3ファイル内のインデックスのリスト
    @inlinable func prefixNodeIndices(chars: [UInt8], maxDepth: Int) -> [Int] {
        guard let nodeIndex = self.searchNodeIndex(chars: chars) else {
            return []
        }
        return self.prefixNodeIndices(nodeIndex: nodeIndex, maxDepth: maxDepth)
    }

    /// 部分前方一致検索を実行する
    ///
    /// 「しかい」を入力した場合、「しかい」だけでなく「し」「しか」の検索も行う。
    /// - Parameter chars: CharIDに変換した文字列
    /// - Returns: 対応するloudstxt3ファイル内のインデックスのリスト
    /// - Note: より適切な名前に変更したい
    @inlinable func byfixNodeIndices(chars: [UInt8]) -> [Int] {
        var indices = [1]
        for char in chars {
            if let nodeIndex = self.searchCharNodeIndex(from: indices.last!, char: char) {
                indices.append(nodeIndex)
            } else {
                break
            }
        }
        return indices
    }
}
