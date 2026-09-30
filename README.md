# Offline Study Assistant

Ask questions about your course PDFs and get answers that cite their pages, **fully offline**.
Retrieval (vector search + BM25, fused with RRF) and generation (Gemma 3 1B) both run on the phone.
Tap a citation to open the PDF at that page.

> 🚧 Work in progress. See [TASKS.md](TASKS.md) for the roadmap.

## How it works

1. **Indexing:** PDF → text per page → clean → chunk (~250 words) → embed (EmbeddingGemma) → SQLite (drift + sqlite-vec + FTS5).
2. **Answering:** embed the question → vector top 20 + keyword top 20 → RRF → top 5 → grounded prompt → streamed answer with `[n]` citations.

No network calls at runtime, except the one-time model download.

## Stack

Flutter · Riverpod · go_router · flutter_gemma · sqlite-vec · drift · pdfrx

## Metrics

Measured on a real device in release mode: see [docs/METRICS.md](docs/METRICS.md).

## Run it

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run --release
```

## Development

```bash
flutter analyze
flutter test
```

## License

TBD
