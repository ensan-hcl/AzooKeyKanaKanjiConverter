import Foundation
import SwiftUtils

@MainActor final class Zenz {
    package var resourceURL: URL
    private var zenzContext: ZenzContext?
    init(resourceURL: URL) throws {
        self.resourceURL = resourceURL
        do {
            #if canImport(Darwin)
            if #available(iOS 16, macOS 13, *) {
                self.zenzContext = try ZenzContext.createContext(path: resourceURL.path(percentEncoded: false))
            } else {
                // this is not percent-encoded
                self.zenzContext = try ZenzContext.createContext(path: resourceURL.path)
            }
            #elseif canImport(WinSDK)
            // remove first "/" from path (for windows)
            self.zenzContext = try ZenzContext.createContext(path: String(resourceURL.path.dropFirst()))
            #else
            // this is not percent-encoded
            self.zenzContext = try ZenzContext.createContext(path: resourceURL.path)
            #endif
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
            let result = zenzContext.evaluate_candidate(input: convertTarget.toKatakana(), candidate: candidate)
            return result
        }
        return .error
    }
}
