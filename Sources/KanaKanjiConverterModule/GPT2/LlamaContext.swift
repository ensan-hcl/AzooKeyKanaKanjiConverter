//
//  LlamaContext.swift
//  SwiftLlamaApp
//
//  Created by miwa on 2023/12/16.
//
import llama
import SwiftUtils
import Foundation

enum LlamaError: Error {
    case couldNotInitializeContext
}

class LlamaContext {
    private var model: OpaquePointer
    private var context: OpaquePointer
    private var batch: llama_batch
    private var tokens_list: [llama_token]

    var n_len: Int32 = 2048
    var n_cur: Int32 = 0
    var n_decode: Int32 = 0

    init(model: OpaquePointer, context: OpaquePointer) {
        self.model = model
        self.context = context
        self.tokens_list = []
        self.batch = llama_batch_init(2048, 0, 1)
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
        ctx_params.n_batch = 1024
        // required to evaluate all logits
        ctx_params.logits_all = true
        return ctx_params
    }

    static func createContext(path: String) throws -> LlamaContext {
        llama_backend_init()
        let model_params = llama_model_default_params()

        let model = llama_load_model_from_file(path, model_params)
        guard let model else {
            debug("Could not load model at \(path)")
            throw LlamaError.couldNotInitializeContext
        }

        let context = llama_new_context_with_model(model, ctx_params)
        guard let context else {
            debug("Could not load context!")
            throw LlamaError.couldNotInitializeContext
        }

        return LlamaContext(model: model, context: context)
    }

    func reset_context() throws {
        llama_free(self.context)
        let context = llama_new_context_with_model(self.model, Self.ctx_params)
        guard let context else {
            debug("Could not load context!")
            throw LlamaError.couldNotInitializeContext
        }
        self.context = context
    }

    func evaluate(text: String) -> Float {
        debug("attempting to complete \"\(text)\"")

        tokens_list = tokenize(text: text, add_bos: true, add_eos: true)

        let n_ctx = llama_n_ctx(context)
        let n_kv_req = tokens_list.count + (Int(n_len) - tokens_list.count)

        debug("n_len = \(n_len), n_ctx = \(n_ctx), n_kv_req = \(n_kv_req)")

        if n_kv_req > n_ctx {
            debug("error: n_kv_req > n_ctx, the required KV cache size is not big enough")
        }

        for id in tokens_list {
            debug(String(cString: token_to_piece(token: id) + [0]))
        }

        llama_batch_clear(&batch)
        for i1 in 0..<tokens_list.count {
            let i = Int(i1)
            llama_batch_add(&batch, tokens_list[i], Int32(i), [0], false)
        }
        let n_vocab = llama_n_vocab(model)

        for i in 0 ..< batch.n_tokens {
            batch.logits[Int(i)] = 1 // true
        }
        // 評価
        if llama_decode(context, batch) != 0 {
            debug("llama_decode() failed")
        }

        guard let logits = llama_get_logits(context) else {
            debug("logits unavailable")
            return .nan
        }
        var sum: Float = 0
        // 流石にもう少しマシな方法で計算したいが、一旦
        // 最初の一トークンはBOSで無駄なので無視して良い
        for (i, token_id) in tokens_list.indexed().dropFirst() {
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

    func clear() {
        self.tokens_list.removeAll()
        try? self.reset_context()
    }

    func llama_batch_clear(_ batch: inout llama_batch) {
        batch.n_tokens = 0
    }

    func llama_batch_add(_ batch: inout llama_batch, _ id: llama_token, _ pos: llama_pos, _ seq_ids: [llama_seq_id], _ logits: Bool) {
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
        let nTokens = llama_token_to_piece(model, token, result, 8)

        if nTokens < 0 {
            let newResult = UnsafeMutablePointer<Int8>.allocate(capacity: Int(-nTokens))
            newResult.initialize(repeating: Int8(0), count: Int(-nTokens))
            defer {
                newResult.deallocate()
            }
            let nNewTokens = llama_token_to_piece(model, token, newResult, -nTokens)
            let bufferPointer = UnsafeBufferPointer(start: newResult, count: Int(nNewTokens))
            return Array(bufferPointer)
        } else {
            let bufferPointer = UnsafeBufferPointer(start: result, count: Int(nTokens))
            return Array(bufferPointer)
        }
    }
}
