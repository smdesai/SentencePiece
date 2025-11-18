# SentencePiece Swift Integration

A complete Swift integration for Google's SentencePiece tokenizer, packaged as an XCFramework for macOS and iOS.

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
├── build_and_run_test.sh            # Builds and runs Swift tests
├── SentencePiece.xcframework/       # Generated framework (multi-platform)
├── SentencePieceWrapper/            # C bridge and Swift wrapper
│   ├── SentencePieceBridge.h/.cpp  # C API wrapping C++ SentencePiece
│   └── SentencePieceNative.swift   # Swift API wrapper
├── models/                          # SentencePiece model files
│   └── sentencepiece.bpe.model     # Test model (250k vocab)
└── tests/                          # Test scripts
    ├── test_sentencepiece_xcframework.swift
    └── test_python_sentencepiece.py
```

## Features

- ✅ Multi-platform XCFramework (macOS, iOS device, iOS simulator)
- ✅ Clean Swift API with automatic memory management
- ✅ Full encode/decode support (text ↔ tokens ↔ IDs)
- ✅ Type-safe wrapper around C++ library
- ✅ Pre-built framework ready to use

## Usage

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

See [`SentencePieceWrapper/README.md`](SentencePieceWrapper/README.md) for detailed usage instructions.

## Integration with SegmentText

This project was originally created for [`https://github.com/smdesai/SegmentText`](https://github.com/smdesai/SegmentText).

To use in SegmentText:
1. Build the XCFramework: `./build_sentencepiece_framework.sh`
2. Copy `SentencePiece.xcframework` to `SegmentText/Frameworks/`
3. Copy `SentencePieceWrapper/` files to your project
4. Use the `SentencePieceNative` class in your Swift code

## Requirements

- macOS 10.15+
- Xcode 12.0+
- Swift 5.3+
- CMake 3.15+ (for building the framework)

## Documentation

- [`SentencePieceWrapper/README.md`](SentencePieceWrapper/README.md) - Swift API documentation
- [`tests/README.md`](tests/README.md) - Testing guide
- [`models/README.md`](models/README.md) - Model information

## License

This project wraps Google's SentencePiece library. See the original [SentencePiece repository](https://github.com/google/sentencepiece) for license information.
