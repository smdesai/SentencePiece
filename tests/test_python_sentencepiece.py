import sentencepiece as spm

# Load the model
model_path = "models/sentencepiece.bpe.model"
sp = spm.SentencePieceProcessor(model_path)

# Test cases
test_texts = [
    "Hello",
    "Hello world",
    "Hello world!",
    "Testing 123",
    "The quick brown fox",
    "🌍🌎🌏",
    "Mixed emoji 😀 text",
    "  spaces  ",
    "\n\nnewlines\n\n",
    "代码测试"
]

print("Python SentencePiece Test Results:")
print("=" * 50)

for text in test_texts:
    pieces = sp.encode_as_pieces(text)
    ids = sp.encode_as_ids(text)
    decoded = sp.decode_ids(ids)

    print(f"Text: {repr(text)}")
    print(f"Pieces: {pieces}")
    print(f"IDs: {ids}")
    print(f"Decoded: {repr(decoded)}")
    print("-" * 30)
