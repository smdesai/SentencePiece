# SentencePiece Swift Integration Guide

This project provides a C bridge to use SentencePiece from Swift via an XCFramework.

## Architecture

The integration uses a three-layer approach:
1. **SentencePieceBridge.h/.cpp**: C bridge wrapping the C++ SentencePiece API
2. **SentencePieceNative.swift**: Swift wrapper providing a clean, type-safe API
3. **SentencePiece.xcframework**: Pre-built framework containing the SentencePiece library

This layered design allows Swift code to use SentencePiece with idiomatic Swift syntax.

## Building the XCFramework

First, build the SentencePiece XCFramework:
```bash
chmod +x build_sentencepiece_framework.sh
./build_sentencepiece_framework.sh
```

This creates `SentencePiece.xcframework` with variants for:
- macOS (arm64 + x86_64)
- iOS device (arm64)
- iOS simulator (x86_64)

## Usage from Swift

### Recommended: High-Level API (SentencePieceNative)

The easiest way to use SentencePiece is through the `SentencePieceNative` class:

```swift
import Foundation

// Create tokenizer
let tokenizer = try SentencePieceNative(modelPath: "model.bpe.model")

// Get vocabulary size
print("Vocab size: \(tokenizer.vocabSize)")

// Tokenize text into pieces
let pieces = tokenizer.tokenize(text: "Hello world")
print("Pieces: \(pieces)") // ["▁Hello", "▁world"]

// Encode text to token IDs
let ids = tokenizer.encode(text: "Hello world")
print("IDs: \(ids)") // [35377, 8998]

// Decode IDs back to text
let decoded = tokenizer.decode(ids: ids)
print("Decoded: \(decoded)") // "Hello world"

// Convert between tokens and IDs
if let id = tokenizer.convertTokenToId("▁Hello") {
    print("Token ID: \(id)")
}

if let token = tokenizer.convertIdToToken(35377) {
    print("Token: \(token)")
}
```

### Low-Level API (C Bridge)

For advanced use cases, you can call the C bridge directly:

<details>
<summary>Click to expand C bridge API</summary>

The C bridge provides these functions:

```c
// Create processor from model file
SentencePieceProcessor sentencepiece_create(const char* model_path);

// Encode text to pieces (token strings)
int sentencepiece_encode_as_pieces(SentencePieceProcessor processor,
                                   const char* text, char*** pieces);

// Encode text to IDs
int sentencepiece_encode_as_ids(SentencePieceProcessor processor,
                               const char* text, int** ids);

// Decode IDs back to text
char* sentencepiece_decode_ids(SentencePieceProcessor processor,
                               const int* ids, int num_ids);

// Get vocabulary size
int sentencepiece_get_piece_size(SentencePieceProcessor processor);

// Clean up
void sentencepiece_destroy(SentencePieceProcessor processor);
void sentencepiece_free_pieces(char** pieces, int count);
```

Example using `@_silgen_name`:

```swift
@_silgen_name("sentencepiece_create")
func sentencepiece_create(_ modelPath: UnsafePointer<CChar>?) -> OpaquePointer?

@_silgen_name("sentencepiece_encode_as_ids")
func sentencepiece_encode_as_ids(_ processor: OpaquePointer?,
                                 _ text: UnsafePointer<CChar>?,
                                 _ ids: UnsafeMutablePointer<UnsafeMutablePointer<Int32>?>?) -> Int32

@_silgen_name("sentencepiece_destroy")
func sentencepiece_destroy(_ processor: OpaquePointer?) -> Void

// Usage (low-level, not recommended)
let processor = sentencepiece_create("model.bpe.model")!
defer { sentencepiece_destroy(processor) }

var idsPtr: UnsafeMutablePointer<Int32>?
let count = sentencepiece_encode_as_ids(processor, "Hello world", &idsPtr)
// ... handle unsafe pointers ...
```

</details>

## Building Swift Projects with the XCFramework

### Command Line Build

The XCFramework requires platform-specific paths when building from command line:

```bash
# Step 1: Compile C++ bridge to object file
clang++ -c SentencePieceWrapper/SentencePieceBridge.cpp \
        -I SentencePieceWrapper \
        -I SentencePiece.xcframework/macos-arm64_x86_64/SentencePiece.framework/Headers \
        -o SentencePieceBridge.o

# Step 2: Compile Swift files and link with C++ object file
swiftc -F SentencePiece.xcframework/macos-arm64_x86_64 \
       -framework SentencePiece \
       -I SentencePieceWrapper \
       SentencePieceWrapper/SentencePieceNative.swift \
       your_swift_file.swift \
       SentencePieceBridge.o \
       -Xlinker -lc++ \
       -o your_program
```

**Important:**
- Include `SentencePieceNative.swift` in your compilation to get the high-level API
- The framework path must point to the platform-specific variant (e.g., `macos-arm64_x86_64`)
- See `build_and_run_test.sh` for a complete working example

### Xcode Integration

1. Drag `SentencePiece.xcframework` into your Xcode project
2. Add these files to your project:
   - `SentencePieceWrapper/SentencePieceBridge.cpp`
   - `SentencePieceWrapper/SentencePieceNative.swift`
3. Add `SentencePieceWrapper/SentencePieceBridge.h` to your bridging header
4. Xcode will automatically select the correct framework variant for your target
5. Use the `SentencePieceNative` class in your Swift code

## Testing

Run the test program:
```bash
./build_and_run_test.sh
```

This demonstrates encoding/decoding with various text inputs including Unicode and emoji.