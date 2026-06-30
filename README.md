# SentencePiece Swift Integration

A Swift integration for Google's SentencePiece tokenizer, packaged as a self-contained XCFramework for macOS and iOS.

`SentencePiece.xcframework` contains the SentencePiece runtime, the required Abseil and protobuf-lite object code, and the C bridge implementation used by Swift. Consumers do not need to build SentencePiece, compile C++, ship Abseil headers, or link Abseil libraries separately.

## Quick Start

```bash
# 1. Build the XCFramework
./build_sentencepiece_framework.sh

# 2. Run Swift tests
./build_and_run_test.sh

# 3. Run Python tests (optional, for comparison)
python tests/test_python_sentencepiece.py
```

**Note:** All commands should be run from the project root directory.

## Project Structure

```
SentencePiece/
├── build_sentencepiece_framework.sh  # Builds the XCFramework
├── build_sentencepiece_cli.sh        # Builds a simple CLI against the framework
├── build_and_run_test.sh            # Builds and runs Swift tests
├── SentencePiece.xcframework/       # Generated framework (multi-platform)
├── SentencePieceWrapper/            # C bridge and Swift wrapper
│   ├── SentencePieceBridge.h       # Public C API shipped in the framework
│   ├── SentencePieceBridge.cpp     # Build input compiled into the framework
│   ├── SentencePieceNative.swift   # Swift API wrapper
│   └── TokenizerSupport.swift      # Minimal tokenizer support types for tests/CLI
├── models/                          # SentencePiece model files
│   └── tokenizer.model             # Test model
└── tests/                          # Test scripts
    ├── SentencePieceCLI.swift
    ├── test_sentencepiece_xcframework.swift
    └── test_python_sentencepiece.py
```

## Features

- ✅ Multi-platform XCFramework (macOS, iOS device, iOS simulator)
- ✅ Self-contained framework binary for SentencePiece, protobuf-lite, Abseil, and the C bridge
- ✅ Public C bridge API with no public Abseil or SentencePiece C++ headers
- ✅ Clean Swift API with automatic memory management
- ✅ Full encode/decode support (text ↔ tokens ↔ IDs)
- ✅ No consumer-side C++ bridge compilation

## Usage

Add these to your app or command-line target:

- `SentencePiece.xcframework`
- `SentencePieceWrapper/SentencePieceNative.swift`
- `SentencePieceWrapper/TokenizerSupport.swift`, unless your project already provides the tokenizer protocol/types it defines

Do not add `SentencePieceBridge.cpp` to consumer targets. It is compiled into `SentencePiece.xcframework` by `build_sentencepiece_framework.sh`.

Do not add Abseil headers or `libabsl_*.a` libraries to consumer targets. The framework already contains the required Abseil object code.

```swift
import Foundation

// Create tokenizer
let tokenizer = try SentencePieceNative(modelPath: "models/sentencepiece.bpe.model")

// Tokenize
let pieces = tokenizer.tokenize(text: "Hello world")
// ["▁Hello", "▁world"]

// Encode to IDs
let ids = tokenizer.encode(text: "Hello world")
// [35377, 8998]

// Decode back
let decoded = tokenizer.decode(ids: ids)
// "Hello world"
```

See [`SentencePieceWrapper/README.md`](SentencePieceWrapper/README.md) for detailed Swift wrapper API notes.

## Consumer Integration

### Xcode

1. Build or obtain `SentencePiece.xcframework`.
2. Add `SentencePiece.xcframework` to your app target's Frameworks, Libraries, and Embedded Content.
3. Add `SentencePieceNative.swift` to your target.
4. Add `TokenizerSupport.swift` to your target if your project does not already provide `PreTrainedTokenizerModel`, `Config`, and `TokenizerError`.
5. Do not add `SentencePieceBridge.cpp` to the target.
6. Do not add Abseil include paths, Abseil libraries, or a SentencePiece source checkout.

The framework exports `SentencePieceBridge.h` for the C ABI and includes the compiled bridge implementation internally.

### Command Line

For a simple Swift command-line build on macOS:

```bash
swiftc -F SentencePiece.xcframework/macos-arm64_x86_64 \
       -framework SentencePiece \
       -I SentencePieceWrapper \
       SentencePieceWrapper/TokenizerSupport.swift \
       SentencePieceWrapper/SentencePieceNative.swift \
       your_program.swift \
       -Xlinker -lc++ \
       -Xlinker -rpath \
       -Xlinker @executable_path \
       -o your_program
```

There is intentionally no `SentencePieceBridge.o` and no `libabsl_*.a` in that command. See `build_sentencepiece_cli.sh` for the current working CLI build.

### Low-Level C API

Advanced consumers can call the C bridge exported by the framework directly via `SentencePieceBridge.h`. The main functions are:

```c
SentencePieceProcessor sentencepiece_create(const char* model_path);
int sentencepiece_encode_as_pieces(SentencePieceProcessor processor, const char* text, char*** pieces);
int sentencepiece_encode_as_ids(SentencePieceProcessor processor, const char* text, int** ids);
char* sentencepiece_decode_ids(SentencePieceProcessor processor, const int* ids, int num_ids);
void sentencepiece_destroy(SentencePieceProcessor processor);
void sentencepiece_free_pieces(char** pieces, int count);
void sentencepiece_free_ids(int* ids);
void sentencepiece_free_string(char* string);
```

Memory returned by the bridge should be released with the matching `sentencepiece_free_*` function.

## Integration with SegmentText

This project was originally created for [`https://github.com/smdesai/SegmentText`](https://github.com/smdesai/SegmentText).

To use in SegmentText:
1. Build the XCFramework: `./build_sentencepiece_framework.sh`
2. Copy `SentencePiece.xcframework` to `SegmentText/Frameworks/`
3. Copy `SentencePieceNative.swift` and, if needed, `TokenizerSupport.swift` to your project
4. Do not copy or compile `SentencePieceBridge.cpp`
5. Use the `SentencePieceNative` class in your Swift code

## Requirements

- macOS 10.15+
- Xcode 12.0+
- Swift 5.3+
- CMake 3.15+ (for building the framework)
- Xcode command-line tools (for `xcodebuild`, `xcrun`, `lipo`, and Apple SDKs)

## Documentation

- [`SentencePieceWrapper/README.md`](SentencePieceWrapper/README.md) - Swift API documentation
- [`tests/README.md`](tests/README.md) - Testing guide
- [`models/README.md`](models/README.md) - Model information

## License

This project wraps Google's SentencePiece library. See the original [SentencePiece repository](https://github.com/google/sentencepiece) for license information.
