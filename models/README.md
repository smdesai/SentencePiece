# Models

This directory contains SentencePiece model files used for testing and development.

## Current Models

### sentencepiece.bpe.model

- **Type:** BPE (Byte Pair Encoding)
- **Vocabulary Size:** 250,000 tokens
- **Usage:** Testing and demonstration of the Swift SentencePiece wrapper

## Using Your Own Models

To use a different SentencePiece model:

1. Place your `.model` file in this directory
2. Update the model path in your code:

```swift
let tokenizer = try SentencePieceNative(modelPath: "models/your_model.model")
```

Or for Python:
```python
sp = spm.SentencePieceProcessor("models/your_model.model")
```

## Training New Models

To train a new SentencePiece model, use the official SentencePiece tools:

```bash
# Install sentencepiece
brew install sentencepiece  # macOS
# or
pip install sentencepiece  # Python

# Train a new model
spm_train --input=data.txt \
          --model_prefix=mymodel \
          --vocab_size=32000 \
          --model_type=bpe

# This creates mymodel.model and mymodel.vocab
```

For more information, see the [SentencePiece documentation](https://github.com/google/sentencepiece).

## .gitignore

Large model files (>100MB) should be added to `.gitignore` to avoid bloating the repository. The current test model (5.1MB) is included for convenience.
