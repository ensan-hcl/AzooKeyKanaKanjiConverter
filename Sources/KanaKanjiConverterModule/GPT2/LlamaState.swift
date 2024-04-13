//
//  LlamaModel.swift
//  SwiftLlamaApp
//
//  Created by miwa on 2023/11/25.
//

import Foundation
import SwiftUtils
#if os(iOS)
import class UIKit.UIDevice
#endif
@MainActor
class LlamaState {
    package var resourceURL: URL
    private var llamaContext: LlamaContext?
    init(resourceURL: URL) {
        self.resourceURL = resourceURL
        do {
            self.llamaContext = try LlamaContext.createContext(path: resourceURL.path())
            debug("Loaded model \(resourceURL.lastPathComponent)")
        } catch {
            debug(error)
        }
    }

    /// - parameters:
    ///   - prompt: text to give the model
    ///   - createNewContext: `true` if you want to clear the current context
    @MainActor
    func refreshContext() {
        Task {
            try self.llamaContext?.reset_context()
        }
    }

    func evaluate(input: [String]) -> [Float] {
        guard let llamaContext else {
            return []
        }
        var result: [Float] = []
        for text in input {
            let score = llamaContext.evaluate(text: text)
            result.append(score)
        }
        return result
    }
}
