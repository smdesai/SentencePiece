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

# Check if the bridge source exists
if [ ! -f "SentencePieceWrapper/SentencePieceBridge.cpp" ]; then
    echo "❌ SentencePieceBridge.cpp not found!"
    exit 1
fi

# Check if test model exists
if [ ! -f "models/sentencepiece.bpe.model" ]; then
    echo "❌ Test model not found at models/sentencepiece.bpe.model"
    exit 1
fi

# Determine the platform-specific framework path within the XCFramework
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    FRAMEWORK_PATH="SentencePiece.xcframework/macos-arm64_x86_64/SentencePiece.framework"
else
    FRAMEWORK_PATH="SentencePiece.xcframework/macos-arm64_x86_64/SentencePiece.framework"
fi

# Step 1: Compile the C++ bridge to object file
echo "Compiling C++ bridge..."
clang++ -c SentencePieceWrapper/SentencePieceBridge.cpp \
        -I SentencePieceWrapper \
        -I "${FRAMEWORK_PATH}/Headers" \
        -o SentencePieceWrapper/SentencePieceBridge.o

# Step 2: Compile Swift and link with the C++ object file
echo "Compiling Swift and linking..."
swiftc -F SentencePiece.xcframework/macos-arm64_x86_64 \
       -framework SentencePiece \
       -I SentencePieceWrapper \
       SentencePieceWrapper/SentencePieceNative.swift \
       tests/test_sentencepiece_xcframework.swift \
       SentencePieceWrapper/SentencePieceBridge.o \
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
rm -f tests/test_sentencepiece
rm -f SentencePieceWrapper/SentencePieceBridge.o
