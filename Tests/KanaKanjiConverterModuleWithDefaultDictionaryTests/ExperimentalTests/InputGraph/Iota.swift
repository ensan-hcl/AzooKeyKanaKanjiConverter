//
//  Iota.swift
//
//
//  Created by miwa on 2024/02/25.
//

import Foundation

struct Iota: CustomStringConvertible {
    private var next: Int = 0
    mutating func new() -> Int {
        let result = next
        next += 1
        return result
    }

    var description: String {
        "Iota()"
    }
}
