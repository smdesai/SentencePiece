//
//  SentencePieceNative.swift
//  Native Swift wrapper for Google's SentencePiece
//
//  Usage:
//  1. Install SentencePiece: brew install sentencepiece
//  2. Add to build settings:
//     - Header Search Paths: /opt/homebrew/include (Apple Silicon) or /usr/local/include (Intel)
//     - Library Search Paths: /opt/homebrew/lib (Apple Silicon) or /usr/local/lib (Intel)
//     - Other Linker Flags: -lsentencepiece -lc++
//

import Foundation

// C Bridge functions
@_silgen_name("sentencepiece_create")
fileprivate func sentencepiece_create(_ modelPath: UnsafePointer<CChar>) -> OpaquePointer?

@_silgen_name("sentencepiece_encode_as_pieces")
fileprivate func sentencepiece_encode_as_pieces(_ processor: OpaquePointer, 
                                               _ text: UnsafePointer<CChar>,
                                               _ pieces: UnsafeMutablePointer<UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?>) -> Int32

@_silgen_name("sentencepiece_encode_as_ids")
fileprivate func sentencepiece_encode_as_ids(_ processor: OpaquePointer,
                                            _ text: UnsafePointer<CChar>,
                                            _ ids: UnsafeMutablePointer<UnsafeMutablePointer<Int32>?>) -> Int32

@_silgen_name("sentencepiece_piece_to_id")
fileprivate func sentencepiece_piece_to_id(_ processor: OpaquePointer, _ piece: UnsafePointer<CChar>) -> Int32

@_silgen_name("sentencepiece_id_to_piece")
fileprivate func sentencepiece_id_to_piece(_ processor: OpaquePointer, _ id: Int32) -> UnsafePointer<CChar>?

@_silgen_name("sentencepiece_get_piece_size")
fileprivate func sentencepiece_get_piece_size(_ processor: OpaquePointer) -> Int32

@_silgen_name("sentencepiece_decode_ids")
fileprivate func sentencepiece_decode_ids(_ processor: OpaquePointer, _ ids: UnsafePointer<Int32>, _ numIds: Int32) -> UnsafeMutablePointer<CChar>?

@_silgen_name("sentencepiece_destroy")
fileprivate func sentencepiece_destroy(_ processor: OpaquePointer)

@_silgen_name("sentencepiece_free_pieces")
fileprivate func sentencepiece_free_pieces(_ pieces: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>, _ count: Int32)

@_silgen_name("sentencepiece_free_ids")
fileprivate func sentencepiece_free_ids(_ ids: UnsafeMutablePointer<Int32>)

/// Native Swift wrapper for Google's SentencePiece
public class SentencePieceNative: PreTrainedTokenizerModel {
    private let processor: OpaquePointer
    private let modelPath: String
    
    public let unknownTokenId: Int? = 0
    public var unknownToken: String? { "<unk>" }
    
    public init(modelPath: String) throws {
        self.modelPath = modelPath
        
        guard let proc = sentencepiece_create(modelPath) else {
            throw TokenizerError.missingVocab
        }
        
        self.processor = proc
    }
    
    deinit {
        sentencepiece_destroy(processor)
    }

    public func decode(ids: [Int]) -> String {
        let ids32 = ids.map { Int32($0) }
        guard let decoded = sentencepiece_decode_ids(processor, ids32, Int32(ids32.count)) else {
            return ""
        }
        defer { free(decoded) }
        return String(cString: decoded)
    }
    
    public func tokenize(text: String) -> [String] {
        var piecesPtr: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?
        let count = sentencepiece_encode_as_pieces(processor, text, &piecesPtr)
        
        guard count > 0, let pieces = piecesPtr else {
            return []
        }
        
        var result: [String] = []
        for i in 0..<Int(count) {
            if let piece = pieces[i] {
                result.append(String(cString: piece))
            }
        }
        
        sentencepiece_free_pieces(pieces, count)
        return result
    }
    
    public func encode(text: String) -> [Int] {
        var idsPtr: UnsafeMutablePointer<Int32>?
        let count = sentencepiece_encode_as_ids(processor, text, &idsPtr)
        
        guard count > 0, let ids = idsPtr else {
            return []
        }
        
        let result = Array(UnsafeBufferPointer(start: ids, count: Int(count)))
            .map { Int($0) }
        
        sentencepiece_free_ids(ids)
        return result
    }
    
    public func convertTokenToId(_ token: String) -> Int? {
        let id = sentencepiece_piece_to_id(processor, token)
        return id >= 0 ? Int(id) : nil
    }
    
    public func convertIdToToken(_ id: Int) -> String? {
        guard let piece = sentencepiece_id_to_piece(processor, Int32(id)) else {
            return nil
        }
        return String(cString: piece)
    }
    
    public var vocabSize: Int {
        Int(sentencepiece_get_piece_size(processor))
    }
}

// MARK: - Convenience Initializer

extension SentencePieceNative {
    /// Initialize from tokenizer config (for compatibility with existing tokenizer interface)
    convenience init(tokenizerConfig: Config, tokenizerData: Config, addedTokens: [String: Int]) throws {
        // Try to find the model file
        let possiblePaths = [
            "/Users/sdesai/ERNIE-4.5-0.3B-PT-bf16.bak/tokenizer.model",
            "./tokenizer.model",
            "tokenizer.model"
        ]
        
        var modelPath: String?
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                modelPath = path
                break
            }
        }
        
        guard let path = modelPath else {
            throw TokenizerError.missingVocab
        }
        
        try self.init(modelPath: path)
    }
}