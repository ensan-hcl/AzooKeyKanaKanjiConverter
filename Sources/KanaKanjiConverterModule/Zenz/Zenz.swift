import Foundation
import SwiftUtils

@MainActor final class Zenz {
    package var resourceURL: URL
    private var zenzContext: ZenzContext?
    init(resourceURL: URL) throws {
        self.resourceURL = resourceURL
        do {
            self.zenzContext = try ZenzContext.createContext(path: resourceURL.path(percentEncoded: false))
            debug("Loaded model \(resourceURL.lastPathComponent)")
        } catch {
            throw error
        }
    }

    func candidateEvaluate(candidates: [Candidate]) -> ZenzContext.CandidateEvaluationResult {
        guard let zenzContext else {
            return .error
        }
        defer {
            try? zenzContext.reset_context()
        }
        for candidate in candidates {
            let ruby = candidate.data.reduce(into: "") { $0.append(contentsOf: $1.ruby) }
            let result = zenzContext.evaluate_candidate(input: ruby, candidate: candidate.text)
            return result
        }
        return .error
    }
}
