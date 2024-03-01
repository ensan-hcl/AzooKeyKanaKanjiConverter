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
    private var llamaContext: LlamaContext?
    private var modelUrl: URL? {
#if os(macOS)
        Bundle.module.url(forResource: "llama_models/rinna_Q2_K", withExtension: "gguf")
#elseif os(iOS)
        Bundle.module.url(forResource: "llama_models/rinna", withExtension: "gguf")
#endif
    }
    init() {
        do {
            if let modelUrl {
                self.llamaContext = try LlamaContext.createContext(path: modelUrl.path())
                debug("Loaded model \(modelUrl.lastPathComponent)")
            } else {
                debug("Could not find model of specified url in bundle \(Bundle.module.bundleURL)")
            }
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
            try await self.llamaContext?.reset_context()
        }
    }

    func evaluate(input: [String]) async -> [Float] {
        guard let llamaContext else {
            return []
        }
        var result: [Float] = []
        for text in input {
            let score = await llamaContext.evaluate(text: text)
            result.append(score)
        }
        return result
    }
}
