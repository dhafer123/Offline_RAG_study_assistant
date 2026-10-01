# Offline Study Assistant

[![CI](https://github.com/dhafer123/Offline_RAG_study_assistant/actions/workflows/ci.yml/badge.svg)](https://github.com/dhafer123/Offline_RAG_study_assistant/actions/workflows/ci.yml)

Ask questions about your course PDFs and get answers that cite their pages, **fully offline**.
Retrieval (EmbeddingGemma vector search) and generation (Gemma 3 1B) both run on the phone.
Tap a citation to open the PDF at that page.

> 🚧 Work in progress. See [TASKS.md](TASKS.md) for the roadmap.

## How it works

1. **Indexing:** PDF → text per page → clean → chunk (~250 words) → embed (EmbeddingGemma) → SQLite (drift + sqlite-vec + FTS5).
2. **Answering:** embed the question → vector top 5 → grounded prompt → streamed answer with `[n]` citations. Hybrid search (vector + BM25 with RRF) was measured and dropped: 84% vs 90% Recall@5, because keyword search can't match a French question to an English course or the reverse ([METRICS.md](docs/METRICS.md)).

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

### Model file

On first launch the app downloads the model (557 MB, Wi-Fi only by default) from this repo's [`models-v1` release](https://github.com/dhafer123/Offline_RAG_study_assistant/releases/tag/models-v1), checks its SHA-256, and then works offline. Interrupted downloads resume.
Gemma is provided under and subject to the Gemma Terms of Use found at ai.google.dev/gemma/terms (see [docs/model_license](docs/model_license/)).

To skip the download during development, copy the file into the app's private storage by hand (debug build required for `run-as`); the app verifies it once on the next launch:

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

### Library

Tap **Import PDF** and pick a file with the system picker: the app copies it into its own storage and indexes it in the background (one document at a time, with progress). A failed document shows why and can be retried from its menu; documents interrupted by closing the app resume on the next launch. Indexing needs the embedding model files below. Expect about 2.3 s per passage on a mid-range phone (5 min for a 120-page PDF).

### Retrieval debug (embeddings + vector search)

Not downloaded by the app yet either. Request access to [litert-community/embeddinggemma-300m](https://huggingface.co/litert-community/embeddinggemma-300m), download `embeddinggemma-300M_seq512_mixed-precision.tflite` and `sentencepiece.model`, and copy both to `files/models` with the same commands as above. Then copy a few PDFs to `files/pdfs`:

```bash
F=notes.pdf
adb push "$F" /data/local/tmp/"$F"
adb shell chmod 644 /data/local/tmp/"$F"
adb shell run-as $P mkdir -p files/pdfs
adb shell run-as $P cp /data/local/tmp/"$F" files/pdfs/"$F"
adb shell rm /data/local/tmp/"$F"
```

Tap the search icon on the Library screen, **Index** a PDF, then type a question and **Search**: it shows the 5 closest chunks with document, page and cosine similarity. Indexing and search times are logged with `[perf]`.

**Retrieval eval:** from that screen, the checklist icon runs every question of `eval/questions.json` through retrieval and shows Recall@5, MRR and the misses. The JSON report is saved where `adb` can read it without `run-as` (works on release builds):

```bash
adb pull /sdcard/Android/data/com.dhafer.offline_study_assistant/files/eval_results/ eval/results/
```

### Benchmark

In a release build (`flutter run --release`), tap the speed icon on the Library screen, pick a model, then **Run benchmark**. To compare with Qwen3 0.6B, push [`Qwen3-0.6B.litertlm`](https://huggingface.co/litert-community/Qwen3-0.6B) (public, no access request) to the same `files/models` folder, using the steps above. It reloads the model and answers a fixed prompt 10 times, then shows the medians. Each run is also logged: `adb logcat -s flutter | grep "\[perf\]"`.

## Development

```bash
flutter analyze
flutter test
```

## License

TBD
