import Foundation

@main
struct SentencePieceCLI {
    static func main() {
        let arguments = CommandLine.arguments
        let commandName = URL(fileURLWithPath: arguments.first ?? "sentencepiece-cli").lastPathComponent

        guard arguments.count >= 3 else {
            fputs("Usage: \(commandName) <model-path> <text>\n", stderr)
            fputs("Example: \(commandName) models/sentencepiece.bpe.model \"Hello world\"\n", stderr)
            exit(1)
        }

        let modelPath = arguments[1]
        let text = arguments.dropFirst(2).joined(separator: " ")

        guard !text.isEmpty else {
            fputs("Error: text argument cannot be empty.\n", stderr)
            exit(1)
        }

        guard FileManager.default.fileExists(atPath: modelPath) else {
            fputs("Error: no model found at \(modelPath)\n", stderr)
            exit(1)
        }

        do {
            let tokenizer = try SentencePieceNative(modelPath: modelPath)
            let pieces = tokenizer.tokenize(text: text)
            let ids = tokenizer.encode(text: text)
            let decoded = tokenizer.decode(ids: ids)

            print("Text: \(text.debugDescription)")
            print("Pieces: \(pieces)")
            print("IDs: \(ids)")
            print("Decoded: \(decoded.debugDescription)")
        } catch {
            fputs("Failed to initialize SentencePiece with \(modelPath): \(error)\n", stderr)
            exit(1)
        }
    }
}
