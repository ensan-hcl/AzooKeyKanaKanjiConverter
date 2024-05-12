import llama
import SwiftUtils
import Foundation

enum ZenzError: LocalizedError {
    case couldNotLoadModel(path: String)
    case couldNotLoadContext

    var errorDescription: String? {
        switch self {
        case .couldNotLoadContext: "failed to load context"
        case .couldNotLoadModel(path: let path): "could not load model weight at \(path)"
        }
    }
}

class ZenzContext {
    private var model: OpaquePointer
    private var context: OpaquePointer
    private var prevInput: [llama_token] = []

    private let n_len: Int32 = 512

    init(model: OpaquePointer, context: OpaquePointer) {
        self.model = model
        self.context = context
    }

    deinit {
        llama_free(context)
        llama_free_model(model)
        llama_backend_free()
    }

    private static var ctx_params: llama_context_params {
        let n_threads = max(1, min(8, ProcessInfo.processInfo.processorCount - 2))
        debug("Using \(n_threads) threads")
        var ctx_params = llama_context_default_params()
        ctx_params.seed = 1234
        ctx_params.n_ctx = 512
        ctx_params.n_threads       = UInt32(n_threads)
        ctx_params.n_threads_batch = UInt32(n_threads)
        ctx_params.n_batch = 256
        return ctx_params
    }

    static func createContext(path: String) throws -> ZenzContext {
        llama_backend_init()
        var model_params = llama_model_default_params()
        model_params.use_mmap = true
        let model = llama_load_model_from_file(path, model_params)
        guard let model else {
            debug("Could not load model at \(path)")
            throw ZenzError.couldNotLoadModel(path: path)
        }

        let context = llama_new_context_with_model(model, ctx_params)
        guard let context else {
            debug("Could not load context!")
            throw ZenzError.couldNotLoadContext
        }

        return ZenzContext(model: model, context: context)
    }

    func reset_context() throws {
        llama_free(self.context)
        let context = llama_new_context_with_model(self.model, Self.ctx_params)
        guard let context else {
            debug("Could not load context!")
            throw ZenzError.couldNotLoadContext
        }
        self.context = context
    }

    private func get_logits(tokens: [llama_token], logits_start_index: Int = 0) -> UnsafeMutablePointer<Float>? {
        // manage kv_cache
        do {
            let commonTokens = self.prevInput.commonPrefix(with: tokens)
            llama_kv_cache_seq_rm(context, 0, llama_pos(commonTokens.count), -1)
        }
        var batch = llama_batch_init(512, 0, 1)
        let n_ctx = llama_n_ctx(context)
        let n_kv_req = tokens.count + (Int(n_len) - tokens.count)
        if n_kv_req > n_ctx {
            debug("error: n_kv_req > n_ctx, the required KV cache size is not big enough")
        }
        for i in tokens.indices {
            llama_batch_add(&batch, tokens[i], Int32(i), [0], logits: logits_start_index <= i)
        }
        // 評価
        if llama_decode(context, batch) != 0 {
            debug("llama_decode() failed")
            return nil
        }
        return llama_get_logits(context)
    }

    func evaluate(text: String, ignorePrompt: String = "") -> Float {
        let tokens_list = self.tokenize(text: text, add_bos: true, add_eos: true)
        guard let logits = self.get_logits(tokens: tokens_list) else {
            debug("logits unavailable")
            return .nan
        }
        let tokenizedPromptCount = ignorePrompt.isEmpty ? 1 : tokenize(text: ignorePrompt, add_bos: true, add_eos: false).count
        let n_vocab = llama_n_vocab(model)

        var sum: Float = 0
        // 最初のプロンプト部分は無視する
        for (i, token_id) in tokens_list.indexed().dropFirst(tokenizedPromptCount) {
            // FIXME: there can be more efficient implementations, poossibly using Accelerate or other frameworks.
            var log_prob: Float = 0
            for index in ((i - 1) * Int(n_vocab)) ..< (i * Int(n_vocab)) {
                log_prob += exp(logits[index])
            }
            log_prob = log(log_prob)
            log_prob = logits[Int((i - 1) * Int(n_vocab) + Int(token_id))] - log_prob
            sum += log_prob
        }
        return sum
    }

    enum CandidateEvaluationResult: Sendable, Equatable, Hashable {
        case error
        case pass(score: Float)
        case fixRequired(prefixConstraint: String)
    }

    func evaluate_candidate(input: String, candidate: String) -> CandidateEvaluationResult {
        // For zenz-v1 model, \u{EE00} is a token used for 'start query', and \u{EE01} is a token used for 'start answer'
        // We assume \u{EE01}\(candidate) is always splitted into \u{EE01}_\(candidate) by zenz-v1 tokenizer
        let prompt = "\u{EE00}\(input)\u{EE01}"
        // Therefore, tokens = prompt_tokens + candidate_tokens is an appropriate operation.
        let prompt_tokens = self.tokenize(text: prompt, add_bos: true, add_eos: false)
        let candidate_tokens = self.tokenize(text: candidate, add_bos: false, add_eos: false)
        let tokens = prompt_tokens + candidate_tokens
        let startOffset = prompt_tokens.count - 1
        let pos_max = llama_kv_cache_seq_pos_max(self.context, 0)
        print("pos max:", pos_max)
        guard let logits = self.get_logits(tokens: tokens, logits_start_index: startOffset) else {
            debug("logits unavailable")
            return .error
        }
        let n_vocab = llama_n_vocab(model)

        var score: Float = 0
        for (i, token_id) in tokens.indexed().dropFirst(prompt_tokens.count) {
            // それぞれのトークンが、一つ前の予測において最も確率の高いトークンであるかをチェックする
            // softmaxはmaxなので、単にlogitsの中で最も大きいものを選べば良い
            // 一方実用的にはlog_probも得ておきたい。このため、ここでは明示的にsoftmaxも計算している
            var exp_sum: Float = 0
            var max_token: llama_token = 0
            var max_exp: Float = .infinity * -1
            let startIndex = (i - 1 - startOffset) * Int(n_vocab)
            let endIndex = (i - startOffset) * Int(n_vocab)
            for index in startIndex ..< endIndex {
                let v = exp(logits[index])
                exp_sum += v
                if max_exp < v {
                    max_exp = v
                    max_token = llama_token(index - startIndex)
                }
            }
            // ここで最も良い候補であったかをチェックする
            if max_token != token_id {
                var cchars = tokens[..<i].reduce(into: []) {
                    $0.append(contentsOf: token_to_piece(token: $1))
                }
                // adding "\0"
                cchars += token_to_piece(token: max_token) + [0]
                let string = String(cString: cchars)
                // 要求するべき制約を記述する
                let prefixConstraint = String(string.dropFirst(prompt.count))
                return .fixRequired(prefixConstraint: prefixConstraint)
            }
            score += log(max_exp) - log(exp_sum)
        }
        return .pass(score: score)
    }

    private func llama_batch_add(_ batch: inout llama_batch, _ id: llama_token, _ pos: llama_pos, _ seq_ids: [llama_seq_id], logits: Bool) {
        batch.token   [Int(batch.n_tokens)] = id
        batch.pos     [Int(batch.n_tokens)] = pos
        batch.n_seq_id[Int(batch.n_tokens)] = Int32(seq_ids.count)
        for i in 0..<seq_ids.count {
            batch.seq_id[Int(batch.n_tokens)]![Int(i)] = seq_ids[i]
        }
        batch.logits  [Int(batch.n_tokens)] = logits ? 1 : 0
        batch.n_tokens += 1
    }

    private func tokenize(text: String, add_bos: Bool, add_eos: Bool = false) -> [llama_token] {
        let text = text.lowercased()
        let utf8Count = text.utf8.count
        let n_tokens = utf8Count + (add_bos ? 1 : 0)
        let tokens = UnsafeMutablePointer<llama_token>.allocate(capacity: n_tokens)
        let tokenCount = llama_tokenize(model, text, Int32(utf8Count), tokens, Int32(n_tokens), add_bos, false)
        var swiftTokens: [llama_token] = if tokenCount < 0 {
            [llama_token_bos(model)]
        } else {
            (0..<tokenCount).map{tokens[Int($0)]}
        }
        tokens.deallocate()
        if add_eos {
            swiftTokens.append(llama_token_eos(model))
        }
        return swiftTokens
    }

    /// - note: The result does not contain null-terminator
    private func token_to_piece(token: llama_token) -> [CChar] {
        let result = UnsafeMutablePointer<Int8>.allocate(capacity: 8)
        result.initialize(repeating: Int8(0), count: 8)
        defer {
            result.deallocate()
        }
        let nTokens = llama_token_to_piece(model, token, result, 8, false)

        if nTokens < 0 {
            let newResult = UnsafeMutablePointer<Int8>.allocate(capacity: Int(-nTokens))
            newResult.initialize(repeating: Int8(0), count: Int(-nTokens))
            defer {
                newResult.deallocate()
            }
            let nNewTokens = llama_token_to_piece(model, token, newResult, -nTokens, false)
            let bufferPointer = UnsafeBufferPointer(start: newResult, count: Int(nNewTokens))
            return Array(bufferPointer)
        } else {
            let bufferPointer = UnsafeBufferPointer(start: result, count: Int(nTokens))
            return Array(bufferPointer)
        }
    }
}
