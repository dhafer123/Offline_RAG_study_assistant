# Offline Study Assistant

[![CI](https://github.com/dhafer123/Offline_RAG_study_assistant/actions/workflows/ci.yml/badge.svg)](https://github.com/dhafer123/Offline_RAG_study_assistant/actions/workflows/ci.yml)

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
dart run build_runner build --force-jit --delete-conflicting-outputs
flutter run --release
```

### Model file (development)

Until the in-app model download lands, push the model to the phone by hand:

1. Request access to [litert-community/Gemma3-1B-IT](https://huggingface.co/litert-community/Gemma3-1B-IT) on Hugging Face and download `Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm`.
2. Install and open the app once, then push the file into its storage folder:

```bash
adb shell mkdir -p /sdcard/Android/data/com.dhafer.offline_study_assistant/files/models
adb push Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm /sdcard/Android/data/com.dhafer.offline_study_assistant/files/models/
```

3. Tap the bug icon on the Library screen → **Generate**.

## Development

```bash
flutter analyze
flutter test
```

## License

TBD
