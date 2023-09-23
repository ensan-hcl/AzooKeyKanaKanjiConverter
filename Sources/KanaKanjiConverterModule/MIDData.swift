//
//  MIDData.swift
//  azooKey
//
//  Created by ensan on 2022/10/25.
//  Copyright © 2022 ensan. All rights reserved.
//

import Foundation

public enum MIDData: Sendable {
    static var totalCount: Int {
        503
    }
    case BOS
    case EOS
    case 一般
    case 数
    case 英単語
    case 小さい数字
    case 年
    case 絵文字
    case 人名姓
    case 人名名
    case 組織

    public var mid: Int {
        switch self {
        case .BOS: 500
        case .EOS: 500
        case .一般: 501
        case .人名姓: 344
        case .人名名: 370
        case .組織: 378
        case .年: 237
        case .英単語: 40
        case .数: 452
        case .小さい数字: 361
        case .絵文字: 501  // 502を追加する
        }
    }
}
