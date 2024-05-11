import Foundation
import SwiftUtils

@MainActor final class Zenz {
    package var resourceURL: URL
    private var llamaContext: ZenzContext?
    init(resourceURL: URL) throws {
        self.resourceURL = resourceURL
        do {
            self.llamaContext = try ZenzContext.createContext(path: resourceURL.path(percentEncoded: false))
            debug("Loaded model \(resourceURL.lastPathComponent)")
        } catch {
            throw error
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

    func k2kEvaluate(candidates: [Candidate]) -> [Float] {
        guard let llamaContext else {
            return []
        }
        var result: [Float] = []
        for candidate in candidates {
            let ruby = candidate.data.reduce(into: "") { $0.append(contentsOf: $1.ruby) }
            let prompt = "\u{EE00}\(ruby)\u{EE01}"
            let score = llamaContext.evaluate(text: "\(prompt)\(candidate.text)", ignorePrompt: prompt)
            result.append(score)
        }
        try? llamaContext.reset_context()
        return result
    }

    func candidateEvaluate(candidates: [Candidate]) -> ZenzContext.CandidateEvaluationResult {
        guard let llamaContext else {
            return .error
        }
        defer {
            try? llamaContext.reset_context()
        }
        for candidate in candidates {
            let ruby = candidate.data.reduce(into: "") { $0.append(contentsOf: $1.ruby) }
            let result = llamaContext.evaluate_candidate(input: ruby, candidate: candidate.text)
            return result
        }
        return .error
    }
}
