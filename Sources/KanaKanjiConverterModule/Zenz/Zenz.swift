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

    func startSession() {}

    func endSession() {
        try? self.zenzContext?.reset_context()
    }

    func candidateEvaluate(convertTarget: String, candidates: [Candidate]) -> ZenzContext.CandidateEvaluationResult {
        guard let zenzContext else {
            return .error
        }
        for candidate in candidates {
            let result = zenzContext.evaluate_candidate(input: convertTarget.toKatakana(), candidate: candidate.text)
            return result
        }
        return .error
    }
}
