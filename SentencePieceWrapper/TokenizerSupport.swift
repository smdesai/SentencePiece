import Foundation

/// Minimal tokenizer protocol used by the Swift wrappers.
public protocol PreTrainedTokenizerModel {
    var unknownTokenId: Int? { get }
    var unknownToken: String? { get }
    func tokenize(text: String) -> [String]
    func encode(text: String) -> [Int]
    func convertTokenToId(_ token: String) -> Int?
    func convertIdToToken(_ id: Int) -> String?
    var vocabSize: Int { get }
}

/// Placeholder types to mirror the existing tokenizer interface.
public struct Config {}

public enum TokenizerError: Error {
    case missingVocab
}
