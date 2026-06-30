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
- Loads a SentencePiece model from `models/tokenizer.model`
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

### SentencePieceCLI.swift

A lightweight Swift CLI that mirrors the Python test behavior for a single input.

**Build:**
```bash
./build_sentencepiece_cli.sh
```

**Run:**
```bash
tests/sentencepiece_cli models/tokenizer.model "Hello world"
```

This prints the original text, the token pieces, token IDs, and the decoded text using the supplied model.

## Test Model

The tests use a SentencePiece model located at `models/tokenizer.model`.

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
