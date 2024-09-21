//
//  DicdataElement.swift
//  Keyboard
//
//  Created by ensan on 2020/09/10.
//  Copyright © 2020 ensan. All rights reserved.
//

import Foundation

public struct DicdataElement: Equatable, Hashable, Sendable {
    static let BOSData = Self(word: "", ruby: "", cid: CIDData.BOS.cid, mid: MIDData.BOS.mid, value: 0, adjust: 0)
    static let EOSData = Self(word: "", ruby: "", cid: CIDData.EOS.cid, mid: MIDData.EOS.mid, value: 0, adjust: 0)

    public init(word: String, ruby: String, lcid: Int, rcid: Int, mid: Int, value: PValue, adjust: PValue = .zero, metadata: DicdataElementMetadata = .empty) {
        self.word = word
        self.ruby = ruby
        self.lcid = lcid
        self.rcid = rcid
        self.mid = mid
        self.baseValue = value
        self.adjust = adjust
        self.metadata = metadata
    }

    public init(word: String, ruby: String, cid: Int, mid: Int, value: PValue, adjust: PValue = .zero, metadata: DicdataElementMetadata = .empty) {
        self.word = word
        self.ruby = ruby
        self.lcid = cid
        self.rcid = cid
        self.mid = mid
        self.baseValue = value
        self.adjust = adjust
        self.metadata = metadata
    }

    public init(ruby: String, cid: Int, mid: Int, value: PValue, adjust: PValue = .zero, metadata: DicdataElementMetadata = .empty) {
        self.word = ruby
        self.ruby = ruby
        self.lcid = cid
        self.rcid = cid
        self.mid = mid
        self.baseValue = value
        self.adjust = adjust
        self.metadata = metadata
    }

    public consuming func adjustedData(_ adjustValue: PValue) -> Self {
        self.adjust += adjustValue
        return self
    }

    public var word: String
    public var ruby: String
    public var lcid: Int
    public var rcid: Int
    public var mid: Int
    var baseValue: PValue
    public var adjust: PValue
    public var metadata: DicdataElementMetadata

    public func value() -> PValue {
        min(.zero, self.baseValue + self.adjust)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.word == rhs.word && lhs.ruby == rhs.ruby && lhs.lcid == rhs.lcid && lhs.mid == rhs.mid && lhs.rcid == rhs.rcid && lhs.metadata == rhs.metadata
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(word)
        hasher.combine(ruby)
        hasher.combine(lcid)
        hasher.combine(rcid)
        hasher.combine(metadata)
    }
}

extension DicdataElement: CustomDebugStringConvertible {
    public var debugDescription: String {
        "("
        + "ruby: \(self.ruby), "
        + "word: \(self.word), "
        + "cid: (\(self.lcid), \(self.rcid)), "
        + "mid: \(self.mid), "
        + "value: \(self.baseValue)+\(self.adjust)=\(self.value()), "
        + "metadata: ("
        + "isLearned: \(self.metadata.contains(.isLearned)), "
        + "isFromUserDictionary: \(self.metadata.contains(.isFromUserDictionary))"
        + ")"
        + ")"
    }
}

public struct DicdataElementMetadata: OptionSet, Sendable, Hashable, Equatable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public static let empty: Self = []
    /// 学習データから得られた候補にはこのフラグを立てる
    public static let isLearned = DicdataElementMetadata(rawValue: 1 << 0) // 1
    /// ユーザ辞書から得られた候補にはこのフラグを立てる
    public static let isFromUserDictionary = DicdataElementMetadata(rawValue: 1 << 1) // 2
}
