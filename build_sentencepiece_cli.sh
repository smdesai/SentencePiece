#!/bin/bash
# Build the SentencePiece Swift CLI utility.

set -e

echo "Building SentencePiece CLI..."

if [ ! -d "SentencePiece.xcframework" ]; then
    echo "❌ SentencePiece.xcframework not found!"
    echo "Please run ./build_sentencepiece_framework.sh first."
    exit 1
fi

FRAMEWORK_PATH="SentencePiece.xcframework/macos-arm64_x86_64/SentencePiece.framework"

# The framework exposes the stable C bridge and embeds its implementation.
if [ ! -f "${FRAMEWORK_PATH}/Headers/SentencePieceBridge.h" ]; then
    echo "❌ Framework is missing SentencePieceBridge.h!"
    echo "Please rebuild it with ./build_sentencepiece_framework.sh."
    exit 1
fi

MODULE_CACHE=$(mktemp -d .swift-module-cache.XXXXXX)
trap 'rm -rf "$MODULE_CACHE"' EXIT

echo "Compiling Swift sources..."
swiftc -F SentencePiece.xcframework/macos-arm64_x86_64 \
       -I SentencePieceWrapper \
       -module-cache-path "$MODULE_CACHE" \
       SentencePieceWrapper/TokenizerSupport.swift \
       SentencePieceWrapper/SentencePieceNative.swift \
       tests/SentencePieceCLI.swift \
       -framework SentencePiece \
       -Xlinker -lc++ \
       -Xlinker -rpath \
       -Xlinker @executable_path \
       -o tests/sentencepiece_cli

echo "✅ CLI built at tests/sentencepiece_cli"
echo "Run it with: tests/sentencepiece_cli <model-path> \"your text\""
