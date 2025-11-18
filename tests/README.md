# Tests

This directory contains test scripts for the SentencePiece Swift integration.

**Important:** All tests should be run from the project root directory.

## Test Files

### test_sentencepiece_xcframework.swift

Swift test program demonstrating the SentencePieceNative wrapper.

**Run:**
```bash
# From project root
./build_and_run_test.sh
```

This test:
- Loads a SentencePiece model from `models/sentencepiece.bpe.model`
- Tokenizes various test inputs (English, Unicode, emoji, Chinese)
- Encodes text to token IDs
- Decodes IDs back to text
- Displays vocabulary size

### test_python_sentencepiece.py

Python reference implementation for comparison.

**Run:**
```bash
# From project root
python tests/test_python_sentencepiece.py
```

**Requirements:**
```bash
pip install sentencepiece
```

## Test Model

The tests use a BPE model located at `models/sentencepiece.bpe.model`. This is a pre-trained SentencePiece model with a vocabulary size of 250,000 tokens.

## Adding Your Own Tests

To add new test cases:

1. Add test text to the `testTexts` array in the Swift file
2. Or add to the `test_texts` list in the Python file
3. Run the test script to see results

Example:
```swift
let testTexts = [
    "Hello world",
    "Your new test text here",
    // ...
]
```
