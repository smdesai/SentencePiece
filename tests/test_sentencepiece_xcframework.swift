import Foundation

// Test program using the high-level wrapper
@main
struct SentencePieceTest {
    static func main() {
        //let modelPath = "models/sentencepiece.bpe.model"
        let modelPath = "models/tokenizer.model"

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
            "代码测试",
            "Saoirse",
            "Ronan",
            "Timotee",
            "Chalamet",
            "Wojciechowski",
            "Xarelto",
            "VR",
            "Zyrtec",
            "Siobhan",
            "Schaumburg",
            "Häagen-Dazs",
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
