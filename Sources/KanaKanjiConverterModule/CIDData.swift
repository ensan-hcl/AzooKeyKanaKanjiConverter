//
//  CIDData.swift
//  azooKey
//
//  Created by ensan on 2022/05/05.
//  Copyright © 2022 ensan. All rights reserved.
//

import Foundation

public enum CIDData: Sendable {
    static var totalCount: Int {
        1319
    }
    case BOS
    case 記号
    case 係助詞ハ
    case 助動詞デス基本形
    case 一般名詞
    case 固有名詞
    case 人名一般
    case 人名姓
    case 人名名
    case 固有名詞組織
    case 地名一般
    case 数
    case EOS
    public var cid: Int {
        switch self {
        case .BOS: 0
        case .記号: 5
        case .係助詞ハ: 261
        case .助動詞デス基本形: 460
        case .一般名詞: 1285
        case .固有名詞: 1288
        case .人名一般: 1289
        case .人名姓: 1290
        case .人名名: 1291
        case .固有名詞組織: 1292
        case .地名一般: 1293
        case .数: 1295
        case .EOS: 1316
        }
    }

    public static func isJoshi(cid: Int) -> Bool {
        return 147 <= cid && cid <= 368
    }
}
