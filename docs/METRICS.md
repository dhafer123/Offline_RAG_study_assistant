# Metrics

All numbers: release build, real device, median of 10 runs unless noted.

**Device:** Samsung Galaxy A16 (SM-A165F), MediaTek Helio G99 (MT6789), 4 GB RAM, Android 16

## LLM speed

| Date | Model | Load time (s) | Time to first token (s) | Tokens/sec | Peak RAM (MB) |
|---|---|---|---|---|---|
| 2026-09-30 | Gemma 3 1B int4 (`Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm`), CPU | 0.86 | 4.41 | 8.38 | ~1,170 |

How it was measured (benchmark screen, `lib/features/benchmark/llm_benchmark.dart`):

- Each run unloads the model, loads it again, then answers a fixed RAG-shaped prompt (one ~150-word source passage + a question): **184 prompt tokens, 103 output tokens** (identical in all 10 runs: temperature 0.2, fixed seed).
- flutter_gemma 0.16.5 (LiteRT-LM), CPU backend, `maxTokens` 4096.
- **Load time:** `LlmEngine.load()` wall clock. The first load after app start (runtime init, cold file cache) took **1.70 s**; run 2 took 2.09 s; runs 3–10 took 0.82–1.00 s.
- **Time to first token:** from `generate()` to the first streamed chunk. This is almost all prefill, so it grows with prompt length: expect more with the ~2,000-token RAG prompt.
- **Tokens/sec:** decode speed, i.e. (output tokens − 1) / (time from first to last chunk). Token counts come from LiteRT-LM's benchmark info, not from counting chunks. Per-run range: 7.79–8.51.
- **Peak RAM:** whole app process, during the 10 runs. `ProcessInfo.maxRss` = 1,153 MB; `adb shell dumpsys meminfo` sampled every 3 s peaked at 1,166 MB PSS / 1,175 MB RSS, with up to 167 MB of the app swapped out. Android killed other cached apps to make room, but not this one. Not yet cross-checked with the Android Studio profiler.

## Indexing

| Date | Document | Pages | Chunks | Indexing time (s) |
|---|---|---|---|---|

## Retrieval (50 answerable questions)

| Date | Method | Recall@5 |
|---|---|---|
| | Vector only | |
| | Hybrid (vector + FTS5, RRF) | |

## Answers (50 answerable + 10 unanswerable)

| Date | Correct | Partial | Wrong | Citation accuracy | Correct refusals (of 10) |
|---|---|---|---|---|---|
