# CLAUDE.md — Offline Study Assistant

Project context for Claude Code. Read this before every task. The task list lives in `TASKS.md`.

## What we're building

A Flutter app that answers questions about the user's course PDFs **fully offline**, using an on-device LLM and retrieval (RAG). Every answer cites the pages it came from. Tapping a citation opens the PDF at that page.

It's a portfolio project, so these matter as much as features: clean architecture, tests, measured metrics, and a strong README.

## Hard rules

- **No network calls at runtime**, except the model manager's one-time model download. Never add analytics, crash reporting, or cloud APIs.
- **Every AI or storage component sits behind an interface** in `lib/core/`. Screens never import `flutter_gemma`, `sqlite-vec`, or `pdfrx` directly.
- **Don't add a dependency without asking first.** Say why it's needed and what the alternative is.
- **Pure logic gets unit tests**: chunker, text cleaner, RRF fusion, citation parser, prompt builder.
- **Check package APIs against the installed version.** `flutter_gemma` changes often, so read its README or source in the pub cache instead of relying on memory.
- **Work on one task from `TASKS.md` at a time.** When it's done, tick its checkbox and add a short "Notes" line if anything changed.

## Stack

| Concern | Choice |
|---|---|
| App | Flutter, Dart 3, Riverpod (with code generation), go_router |
| LLM | Gemma 3 1B int4 through `flutter_gemma`; fallback Qwen3 0.6B |
| Embeddings | EmbeddingGemma (768-dim) through `flutter_gemma` |
| Vector store | `flutter_gemma_rag_sqlite` (sqlite-vec) |
| Keyword search | SQLite FTS5 (BM25) |
| Database access | drift |
| PDF text + viewer | pdfrx |
| Evaluation | in-app benchmark screen → JSON; `eval/analyze.ipynb` (Python) |
| CI | GitHub Actions: `flutter analyze`, `flutter test` |

## Architecture

Three layers, all on the device:

```
Screens (Library, Chat, PDF viewer, Benchmark)       <- Riverpod providers
   │
Services (Ingestion, Retrieval, Answering, ModelManager)
   │
Core (LlmEngine, Embedder, AppDatabase, VectorIndex)  <- flutter_gemma, drift, sqlite-vec, pdfrx
```

**Indexing a PDF:** extract text per page (pdfrx) → clean → chunk (~250 words, ~50 overlap, never across pages) → embed → store the chunk in drift, its vector in sqlite-vec, and its text in FTS5. Extraction and chunking run in a background isolate.

**Answering a question:**
1. Embed the question.
2. Take the vector top 20 and the FTS5 top 20.
3. Merge them with RRF (k = 60) and keep the top 5.
4. Gate: if the best similarity is below the threshold, answer "Not found in your documents" without calling the LLM.
5. Build the prompt with sources numbered [1]–[5], within a budget of about 2,000 tokens.
6. Stream the answer at low temperature.
7. Parse the `[n]` markers and turn them into citation chips (document + page).

## Folder layout

```
lib/
  main.dart
  app/                      # router, theme, top-level providers
  core/
    ai/        llm_engine.dart, gemma_llm_engine.dart, embedder.dart, model_manager.dart
    db/        app_database.dart (drift: documents, chunks, FTS5), vector_index.dart
  features/
    library/   ingestion_service.dart, text_cleaner.dart, chunker.dart, UI
    chat/      retrieval_service.dart, rrf.dart, answer_service.dart, prompt_builder.dart, citation_parser.dart, UI
    viewer/    pdf viewer opened at a page
    benchmark/ debug-only eval runner
test/          mirrors lib/
eval/          questions.json, analyze.ipynb, results/
docs/          METRICS.md, architecture diagram, screenshots
```

## Conventions

- Feature-first folders. File names in snake_case. Tests mirror the `lib/` path.
- Immutable models (freezed or plain `final` classes). No business logic in widgets.
- Errors: services return typed results or throw domain exceptions. The UI always shows a message, never a blank screen.
- Prompts live in `prompt_builder.dart` only, never inline in services.
- Log timing (time to first token, tokens/sec, indexing time) with one small `Perf` helper, so the benchmark screen can reuse it.
- Every measured number goes into `docs/METRICS.md`, with the phone model and date.

## Commands

```bash
flutter pub get
dart run build_runner build --force-jit --delete-conflicting-outputs   # drift / riverpod / freezed codegen
flutter analyze
flutter test
flutter run --release        # always measure performance in release mode, on a real device
```

## Test device

- Phone: Samsung Galaxy A16 (SM-A165F), MediaTek Helio G99 (MT6789), 4 GB RAM (3.7 GB usable), Android 16
- Memory is the main constraint: the GPU backend gets OOM-killed, so the LLM runs on CPU.
- All performance numbers must come from this device, in release mode.
