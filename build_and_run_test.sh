#!/bin/bash
# Build and run the SentencePiece XCFramework test

set -e

echo "Building test program..."

# Check if the XCFramework exists
if [ ! -d "SentencePiece.xcframework" ]; then
    echo "❌ SentencePiece.xcframework not found!"
    echo "Please run ./build_sentencepiece_framework.sh first"
    exit 1
fi

# Check if test model exists
if [ ! -f "models/tokenizer.model" ]; then
    echo "❌ Test model not found at models/tokenizer.model"
    exit 1
fi

# Determine the platform-specific framework path within the XCFramework
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    FRAMEWORK_PATH="SentencePiece.xcframework/macos-arm64_x86_64/SentencePiece.framework"
else
    FRAMEWORK_PATH="SentencePiece.xcframework/macos-arm64_x86_64/SentencePiece.framework"
fi

if [ ! -f "${FRAMEWORK_PATH}/Headers/SentencePieceBridge.h" ]; then
    echo "❌ Framework is missing SentencePieceBridge.h"
    echo "Please run ./build_sentencepiece_framework.sh first"
    exit 1
fi

MODULE_CACHE=$(mktemp -d .swift-module-cache.XXXXXX)
trap 'rm -rf "$MODULE_CACHE"' EXIT

# Compile Swift and link with the self-contained framework.
echo "Compiling Swift and linking..."
swiftc -F SentencePiece.xcframework/macos-arm64_x86_64 \
       -framework SentencePiece \
       -I SentencePieceWrapper \
       -module-cache-path "$MODULE_CACHE" \
       SentencePieceWrapper/TokenizerSupport.swift \
       SentencePieceWrapper/SentencePieceNative.swift \
       tests/test_sentencepiece_xcframework.swift \
       -Xlinker -lc++ \
       -Xlinker -rpath \
       -Xlinker @executable_path \
       -o tests/test_sentencepiece

echo "✅ Build successful!"
echo ""
echo "Running tests..."
echo ""

# Run the test
./tests/test_sentencepiece

# Clean up
#rm -f tests/test_sentencepiece
