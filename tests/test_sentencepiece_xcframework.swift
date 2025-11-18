import Foundation

// Minimal protocol definitions (normally these would come from a tokenizer package)
protocol PreTrainedTokenizerModel {
    var unknownTokenId: Int? { get }
    var unknownToken: String? { get }
    func tokenize(text: String) -> [String]
    func encode(text: String) -> [Int]
    func convertTokenToId(_ token: String) -> Int?
    func convertIdToToken(_ id: Int) -> String?
    var vocabSize: Int { get }
}

struct Config {}

enum TokenizerError: Error {
    case missingVocab
}

// SentencePieceNative will be compiled alongside this file
// No import needed when compiling together

// Test program using the high-level wrapper
@main
struct SentencePieceTest {
    static func main() {
        let modelPath = "models/sentencepiece.bpe.model"

        guard let tokenizer = try? SentencePieceNative(modelPath: modelPath) else {
            print("Failed to create tokenizer")
            return
        }

        print("Vocabulary size: \(tokenizer.vocabSize)")
        print()

        let testTexts = [
            "Hello",
            "Hello world",
            "Hello world!",
            "Testing 123",
            "The quick brown fox",
            "🌍🌎🌏",
            "Mixed emoji 😀 text",
            "  spaces  ",
            "\n\nnewlines\n\n",
            "代码测试"
        ]

        print("Swift SentencePiece Test Results:")
        print(String(repeating: "=", count: 50))

        for text in testTexts {
            print("Text: \(text.debugDescription)")

            // Tokenize (encode as pieces)
            let pieces = tokenizer.tokenize(text: text)
            print("Pieces: \(pieces)")

            // Encode (get token IDs)
            let ids = tokenizer.encode(text: text)
            print("IDs: \(ids)")

            // Decode back from IDs
            let decoded = tokenizer.decode(ids: ids)
            print("Decoded: \(decoded.debugDescription)")

            print(String(repeating: "-", count: 30))
        }
    }
}
