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

Until the in-app model download lands, copy the model into the app's private storage by hand (debug build required for `run-as`):

1. Request access to [litert-community/Gemma3-1B-IT](https://huggingface.co/litert-community/Gemma3-1B-IT) on Hugging Face and download `Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm`.
2. Install the app (`flutter run`), then:

```bash
F=Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm
P=com.dhafer.offline_study_assistant
adb push $F /data/local/tmp/$F
adb shell chmod 644 /data/local/tmp/$F
adb shell run-as $P mkdir -p files/models
adb shell run-as $P cp /data/local/tmp/$F files/models/$F
adb shell rm /data/local/tmp/$F
```

On Git Bash for Windows, run `export MSYS_NO_PATHCONV=1` first so the device paths aren't rewritten.
The file survives reinstalls (including `flutter run --release`, which uses the same debug signing key) but not an uninstall.

3. Tap the bug icon on the Library screen → **Generate**.

### Benchmark

In a release build (`flutter run --release`), tap the speed icon on the Library screen, pick a model, then **Run benchmark**. To compare with Qwen3 0.6B, push [`Qwen3-0.6B.litertlm`](https://huggingface.co/litert-community/Qwen3-0.6B) (public, no access request) to the same `files/models` folder, using the steps above. It reloads the model and answers a fixed prompt 10 times, then shows the medians. Each run is also logged: `adb logcat -s flutter | grep "\[perf\]"`.

## Development

```bash
flutter analyze
flutter test
```

## License

TBD
