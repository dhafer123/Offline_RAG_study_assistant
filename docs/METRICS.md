# Metrics

All numbers: release build, real device, median of 10 runs unless noted.

**Device:** Samsung Galaxy A16 (SM-A165F), MediaTek Helio G99 (MT6789), 4 GB RAM, Android 16

## LLM speed

| Date | Model | Load time (s) | Time to first token (s) | Tokens/sec | Peak RAM (MB) |
|---|---|---|---|---|---|
| 2026-09-30 | Gemma 3 1B int4 (`Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm`), CPU | 0.86 | 4.41 | 8.38 | ~1,170 |
| 2026-09-30 | Qwen3 0.6B int8 (`Qwen3-0.6B.litertlm`), CPU | 0.93 | 8.09 | 3.10 | ~1,800 |

How it was measured (benchmark screen, `lib/features/benchmark/llm_benchmark.dart`):

- Each run unloads the model, loads it again, then answers a fixed RAG-shaped prompt (one ~150-word source passage + a question): **184 prompt tokens, 103 output tokens** (identical in all 10 runs: temperature 0.2, fixed seed).
- flutter_gemma 0.16.5 (LiteRT-LM), CPU backend, `maxTokens` 4096.
- **Load time:** `LlmEngine.load()` wall clock. The first load after app start (runtime init, cold file cache) took **1.70 s**; run 2 took 2.09 s; runs 3–10 took 0.82–1.00 s.
- **Time to first token:** from `generate()` to the first streamed chunk. This is almost all prefill, so it grows with prompt length: expect more with the ~2,000-token RAG prompt.
- **Tokens/sec:** decode speed, i.e. (output tokens − 1) / (time from first to last chunk). Token counts come from LiteRT-LM's benchmark info, not from counting chunks. Per-run range: 7.79–8.51.
- **Peak RAM:** whole app process, during the 10 runs. `ProcessInfo.maxRss` = 1,153 MB; `adb shell dumpsys meminfo` sampled every 3 s peaked at 1,166 MB PSS / 1,175 MB RSS, with up to 167 MB of the app swapped out. Android killed other cached apps to make room, but not this one. Not yet cross-checked with the Android Studio profiler.

### Model choice (task 1.5)

**Decision: Gemma 3 1B int4 stays the default.** On the Galaxy A16 (CPU) it's 2.7× faster at decoding and 1.8× faster to the first token than Qwen3 0.6B, and it uses about 600 MB less memory. Qwen3 has fewer parameters, but the only Qwen3 file our runtime can load has INT8 weights, while Gemma's are INT4.

| | Gemma 3 1B int4 | Qwen3 0.6B int8 |
|---|---|---|
| File size | 584 MB | 614 MB |
| Load, median (first load) | 0.86 s (1.70 s) | 0.93 s (5.08 s) |
| Time to first token | 4.41 s | 8.09 s |
| Tokens/sec (per-run range) | 8.38 (7.79–8.51) | 3.10 (2.58–3.19) |
| Prompt / output tokens | 184 / 103 | 195 / 66 |
| Peak RAM: `maxRss` / `dumpsys` PSS | 1,153 / 1,166 MB | 1,711 / 1,845 MB |
| Swapped out at peak | 167 MB | 286 MB |

Same benchmark and settings for both (10 runs, same prompt, temperature 0.2, seed 1, CPU, `maxTokens` 4096, release build, app freshly started).

Notes:

- **Qwen3 thinking.** Qwen3's chat template writes `<think>…</think>` reasoning unless the user turn ends with `/no_think`. `GemmaLlmEngine` appends it for Qwen3, so the reasoning block is empty, but the empty `<think>

</think>` tags still come through in the stream and would need stripping before display.
- **Answer quality on the benchmark prompt:** both answers were correct and cited `[1]`. Qwen3's was shorter (66 tokens).
- **Qwen3 0.6B int4** (`Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm`, 345 MB) would be the like-for-like comparison, but it fails to load: "Failed to create engine. Model may be invalid". flutter_gemma 0.16.5 bundles LiteRT-LM v0.12.0, and this file was re-exported on 2026-09-20 for LiteRT-LM 0.17.1+. Worth retrying if we move to a newer flutter_gemma (that needs Dart 3.12).

## Indexing

| Date | Document | Pages | Chunks | Indexing time (s) |
|---|---|---|---|---|
| 2026-10-01 | `ps_game` (project report, FR, LaTeX) | 34 | 35 | 81.8 (embedding 81.4) |
| 2026-10-01 | `etat_de_l_art` (FR, LaTeX) | 4 | 9 | 22.2 (embedding 22.1) |
| 2026-10-01 | `03_rag_architecture` (EN) | 2 | 3 | 6.9 |
| 2026-10-01 | `02_rag_basics` (EN) | 1 | 2 | 4.7 |
| 2026-10-01 | `01_ai_fundamentals` (EN) | 1 | 1 | 2.7 |

Single runs (task 2.5, retrieval debug screen), not medians; the 100-page measurement comes with task 2.6. Extraction, cleaning, chunking and saving take under 0.5 s even for 34 pages: **embedding is ~99% of indexing time.**

## Embeddings and vector search

| Date | Model | Per chunk (s) | Search: embed question + top-5 (s) | Peak RAM while indexing (MB) |
|---|---|---|---|---|
| 2026-10-01 | EmbeddingGemma 300M, seq512 (`embeddinggemma-300M_seq512_mixed-precision.tflite`), CPU | 2.35 | 2.15 | ~536 RSS |

- **Per chunk:** total embedding time / chunks over the 5 PDFs above (117.4 s / 50 chunks; per document 2.32–2.61 s). Includes loading the model on the first document.
- **Search:** median of 5 queries (2.13–2.38 s), from the Search tap to the results; nearly all of it is embedding the question, since the brute-force search over 50 vectors is negligible. Inputs are padded to 512 tokens, so a short question costs as much as a full chunk.
- **Single-threaded:** `top -H` during indexing shows one thread at 100% while the other 7 cores idle. flutter_gemma 0.16.5 always runs embeddings on CPU with LiteRT's default options and doesn't expose a thread count. Options if 2.6 needs faster indexing: the seq256 model (about half the work, but it truncates 250-word chunks), shorter chunks, or a newer flutter_gemma.
- **RAM:** `dumpsys meminfo` right after indexing 35 chunks (embedder loaded, LLM not loaded): 476 MB PSS / 536 MB RSS. Not measured with the LLM loaded at the same time yet.
- **Quality, spot checks (vector only):** "How does the NPC generate its dialogues?" → `ps_game` p. 28 (0.57); "Quel moteur de jeu a été utilisé pour le projet" → `ps_game` p. 27, the Godot section (0.57); "What are common challenges of RAG systems?" → `03_rag_architecture` p. 1 (0.58). Weak: "probleme du demarrage a froid" (typed without accents) ranks the right page, `etat_de_l_art` p. 1, only 5th (0.15). Exact-term queries like this are what FTS5 keyword search (3.1) should fix. Recall@5 comes with 2.8.

## Retrieval (50 answerable questions)

| Date | Method | Recall@5 |
|---|---|---|
| | Vector only | |
| | Hybrid (vector + FTS5, RRF) | |

## Answers (50 answerable + 10 unanswerable)

| Date | Correct | Partial | Wrong | Citation accuracy | Correct refusals (of 10) |
|---|---|---|---|---|---|
