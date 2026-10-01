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
| 2026-10-01 | `Rapport_PFE` (end-of-study report, FR), Library import | 120 | 132 | **310.6** (embedding 309.5) |
| 2026-10-01 | `ps_game` (project report, FR, LaTeX) | 34 | 35 | 81.8 (embedding 81.4) |
| 2026-10-01 | `etat_de_l_art` (FR, LaTeX) | 4 | 9 | 22.2 (embedding 22.1) |
| 2026-10-01 | `03_rag_architecture` (EN) | 2 | 3 | 6.9 |
| 2026-10-01 | `02_rag_basics` (EN) | 1 | 2 | 4.7 |
| 2026-10-01 | `01_ai_fundamentals` (EN) | 1 | 1 | 2.7 |

Single runs, not medians: the first row through the Library screen (task 2.6), the others through the retrieval debug screen (task 2.5).

**100+ page document (task 2.6):** 120 pages, 1 without text, 132 chunks. Extraction 0.65 s, cleaning and chunking 0.13 s (background isolate), embedding 309.5 s (2.34 s per chunk), saving 0.26 s: **5 min 11 s** in total. Peak RAM 563 MB RSS (`dumpsys meminfo` every ~30 s).

**UI while indexing it:** the app was used the whole time (53 trips to the retrieval debug screen and back, plus a progress bar updated after every chunk). Flutter frame timings (`FrameMonitor`, collected only while a document indexes): **4,468 frames, 8 over the 16.7 ms budget (0.18%)**; build p50/p90/p99/max = 0.7/1.9/6.7/23.2 ms, raster = 2.3/6.2/11.3/36.3 ms. `dumpsys gfxinfo` can't be used for this: Flutter renders into a SurfaceView it doesn't track. Extraction, cleaning, chunking and saving take under 0.5 s even for 34 pages: **embedding is ~99% of indexing time.**

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

Questions: `eval/questions.json` (50 answerable + 10 unanswerable, 5 PDFs, 31 EN / 29 FR). They were written by Claude at the author's request, not by hand; see the file's `method` field for how bias toward the retriever was limited.

| Date | Method | Recall@5 | MRR | Same-language (26) | Cross-language (24) |
|---|---|---|---|---|---|
| 2026-10-01 | Vector only | **90.0%** (45/50) | 0.687 | 25 | 20 |
| 2026-10-01 | Keyword only (FTS5 BM25) | 60.0% (30/50) | 0.492 | 24 | 6 |
| 2026-10-01 | Hybrid (vector + FTS5, RRF k = 60) | 84.0% (42/50) | 0.649 | **26** | 16 |

Hybrid is **6 points worse** than vector only overall (−3 questions): it fixes the exact-term questions but loses cross-language ones. See the hybrid section below. **Decision (2026-10-01): the app uses vector only.**

**Vector only (task 2.8)**, retrieval eval screen, release build, single run (deterministic: same index, same questions): `eval/results/retrieval_vector_20261001-123211.json`.

- Index: the 5 eval PDFs (50 chunks) plus a 120-page French report that is not in the eval set (132 chunks), as a distractor. Its title is anonymized in the committed JSON (`distractor_report_120p`).
- **MRR 0.687.** First correct chunk at rank 1 for 28 questions, 2 for 7, 3 for 6, 4–5 for 4; 5 misses.
- By language: EN 23/26, FR 22/24. Cross-language questions (asked in the other language than the document): 20/24.
- By document: `01_ai_fundamentals` 3/3, `02_rag_basics` 4/4, `03_rag_architecture` 6/7, `etat_de_l_art` 11/12, `ps_game` 21/24.
- **Misses:** q05/q06 (Scrum events, sprint retrospective): the distractor report also describes Scrum and outranks the right page. q36 (author of the hybrid recommender paper): reference list chunks of both documents compete. q43 (French "groundedness" question on an English document): weak cross-language match, top similarity 0.27. q11 (performance requirement): matched the latency section (p. 28) instead of the requirements page (p. 18). Exact terms (Burke, groundedness, rétrospective) are what FTS5 should add in 3.1.
- **Median 2.13 s per question**, nearly all of it embedding the question.
- **For the "not found" gate (3.3/3.7):** best similarity per question, answerable median 0.506 (min 0.265), unanswerable median 0.475 (max 0.592). The two ranges overlap a lot: a similarity threshold alone will either refuse many answerable questions or let most unanswerable ones through.

**Hybrid (task 3.1)**, same index, same build, same session, release build. Vector top 20 + FTS5 top 20 (question words OR-ed, BM25), fused with RRF (k = 60), top 5 kept. Files: `eval/results/retrieval_hybrid_20261001-201612.json`, plus `retrieval_vector_20261001-201837.json` (vector re-run in the same session: identical ranks to the 2.8 run, so the index hadn't changed) and `retrieval_keyword_20261001-201851.json`.

- **Recall@5 84.0% (42/50), MRR 0.649** vs 90.0% / 0.687 for vector only. Rank 1 for 27 questions, 2 for 6, 3 for 4, 4–5 for 5; 8 misses.
- **Gained (4):** q05 (Scrum events, now rank 5), q11 (performance requirement, 4), q36 (author "Burke", 4), q43 ("groundedness", 3). Moved up: q38 4→1; q13, q27, q39, q47 2→1; q09, q22 3→2; q31, q42 5→3. Moved down but still found: q04, q19, q45 1→2; q40 1→3; q32 2→5.
- **Lost (7):** q10, q21, q26, q28, q30, q34, q49, all found by vector only at rank 1–3, and all 7 cross-language (EN question on a FR document, or the reverse for q49). FTS5 finds none of their right chunks (keyword-only: 6/24 on cross-language questions).
- **Why:** with k = 60 and two lists of 20, a chunk in *both* lists scores at least 2/80 = 0.025, more than a chunk at rank 1 of a single list (1/61 = 0.016). When the keyword list is noise (matches on common words of the question), the chunks that happen to be in both lists push the right vector-only hits out of the top 5. Only 5 of the 300 hybrid hits are keyword-only chunks; the damage comes from the overlap, not from keyword-only chunks.
- By language: EN 19/26, FR 23/24. By document: `01_ai_fundamentals` 2/3, `02_rag_basics` 4/4, `03_rag_architecture` 7/7, `etat_de_l_art` 8/12, `ps_game` 21/24. `etat_de_l_art` (FR) is asked mostly in English, hence its drop.
- **Latency:** median 2.11 s per question (vector 2.10 s): FTS5 takes ~4 ms (keyword-only median), so hybrid costs nothing measurable.
- **Possible fixes (not done in 3.1, to avoid tuning on the only eval set):** drop stop words from the FTS5 query, weight the vector list higher in the fusion, or only fuse the keyword list when its best BM25 score is strong. Any of them should be checked on new questions, not just these 50.
- **For the gate (3.3):** the best similarity among the hybrid top 5 differs from the vector top 1 on 11 of 60 questions (vector top 1 left out of the top 5). The gate should read the vector search's top similarity, not the fused list's.

## Prompt size (task 3.2)

2026-10-01, measured on the host with Gemma 3's own SentencePiece tokenizer (262,144 pieces, read from the `.litertlm` model file), on the 50 chunks of the 5 eval PDFs as the app's pipeline produces them.

- **Chunks:** median 4.6 characters per Gemma token (EN 4.6–6.0, FR 4.4–5.2), 1.47 tokens per word; median 200 tokens, max 352. A table-of-contents chunk is 2.4 characters per token, because Gemma splits numbers into single digits.
- **Instructions:** 116 tokens.
- **Prompt with 5 sources** (500 random draws of 5 chunks + an eval question): median 1,267 tokens, max 1,790. The 2,000-token budget normally keeps all 5 sources; trimming only kicks in for long, dense chunks.
- **Estimator** (`estimateTokens`, used because the real tokenizer needs the loaded model): one token per word, plus one per 6 further letters, plus one per digit or punctuation mark. On those 500 prompts it gives 0.98–1.23× the real count (median 1.12). "Characters / 3" was 1.54× on prose and still too low on the table-of-contents chunk, so it was dropped.

## First answers on the phone (task 3.3)

2026-10-01, Galaxy A16, release build, retrieval debug screen → **Answer**, vector retrieval, gate threshold 0.30, 5 sources, Gemma 3 1B on CPU. Same 6-document index as the retrieval eval. Single runs, not medians: the speed benchmark over many questions is task 4.1.

| Question | Gate (best similarity) | Prompt tokens (real / estimated) | Retrieval | Time to first token | Decode | Answer |
|---|---|---|---|---|---|---|
| "Who introduced the transformer architecture?" (u07, unanswerable) | **refused** (0.252) | – | 4.47 s (incl. embedder load) | – | – | "Not found in your documents.", LLM not called |
| "Why did the team pick Godot 4 to build the game?" (EN question, FR document) | passed (0.505) | 1,587 / 1,758 | 2.16 s | **49.3 s** (+1.7 s model load) | 7.85 tok/s, 109 tokens | Correct, in English, cites [1]–[3] |
| "Quel est le role du GameManager dans NeoQuest 2D ?" | passed (0.607) | 1,190 / 1,307 | 2.45 s | **44.9 s** | 7.06 tok/s, 48 tokens | Correct, in French, no citation marker |

- **Memory:** peak 1.59 GB PSS with the embedder and the LLM both loaded (sampled every 2 s with `dumpsys meminfo`); no crash.
- **The token estimate holds on the real model:** 1.10–1.11× the count LiteRT-LM reports, which also includes the chat-template tokens.
- **Time to first token is the problem:** 45–49 s for a 1,200–1,600-token prompt (184 tokens took 4.4 s in 1.4), about 26–32 prompt tokens/s on CPU. The two prompts differ by 400 tokens but only by 4.4 s, so prefill may run in fixed-size blocks (the model file is "multi-prefill-seq"). This needs a dedicated measurement of TTFT against prompt size before the chat screen.
- **Citations to check in 3.4:** the English answer numbered its markers [1], [2], [3] one per sentence, which may follow the sentence order rather than the sources. The French answer cited nothing.

## Time to first token vs prompt size

2026-10-01, Galaxy A16, release build, Gemma 3 1B int4 on CPU, LLM benchmark screen → **Run sweep**. RAG prompts built by `buildAnswerPrompt` from the indexed chunks, with a one-sentence question; model kept loaded, one warm-up, then 3 runs per size. Prompt tokens are the counts LiteRT-LM reports (chat template included). File: `eval/results/prompt_sweep_20261001-211618.json`.

| Prompt tokens | Prefill size used | Time to first token (median of 3) |
|---|---|---|
| 242 | 256 | **4.2 s** |
| 300 | 512 | 8.3 s |
| 469 | 512 | **8.6 s** |
| 546 | 1024 | 16.9 s |
| 860 | 1024 | 16.8 s |
| 987 | 1024 | **16.8 s** |
| 1,412 | 2560 | 43.8 s |
| 2,001 | 2560 | 43.7 s |
| 2,496 | 2560 | 44.7 s (one run took 126 s) |

- **Time to first token is a staircase, not a slope.** The model file was exported with fixed prefill sizes (32, 64, 128, 256, 512, 1024, 2560 tokens, found in the `.litertlm` file), and LiteRT-LM pads every prompt up to the next one. Within a step the size makes no difference (546 and 987 tokens both take 16.8 s); crossing a step costs 2–2.6× more.
- Cost is proportional to the padded size: about **60 padded tokens/s** at every step (256 / 4.2 s, 512 / 8.5 s, 1024 / 16.8 s, 2560 / 44 s).
- **This explains 3.3's 45–49 s:** the 1,190- and 1,587-token prompts both ran as 2,560.
- Decoding speed doesn't depend on prompt size: 8.3–8.9 tok/s (6.5 in the 126 s outlier run, the first at 2,496 tokens: probably memory pressure or thermal throttling).
- **Consequence for the prompt budget:** keep the real prompt at or under 1,024 tokens (~17 s), or under 512 (~8.5 s), and fill the step: going from 3 to 4 sources inside the same step is free. The 2,000-token budget from 3.2 always lands in the 2,560 step (~44 s).
- The token estimate was 1.08–1.23× the reported count on these prompts (template included), so it errs on the safe side.
- **Decision (2026-10-01): prompt budget 2,000 → 1,000 estimated tokens**, to stay in the 1,024 step. Check on the phone, same question as in 3.3 ("Why did the team pick Godot 4 to build the game?"): 3 sources, 910 real prompt tokens (999 estimated), **time to first token 18.4 s instead of 49.3 s**, 26.6 s in total. The answer was correct, in English, and cited only [1] (the Godot page), where the 5-source answer had cited [1]–[3] one per sentence.

## "Not found" gate threshold (task 3.7)

2026-10-01. The gate refuses a question when the best vector similarity is below the threshold, without calling the LLM. With vector retrieval that's the top-1 similarity, recorded for all 60 eval questions in `eval/results/retrieval_vector_20261001-201837.json` (same 6-document index as the app), so the threshold was chosen from that run.

The 10 unanswerable questions are 4 off-topic (u01 Unity price, u05 accuracy results, u07 transformers, u10 Celeste) and 6 near misses (the topic is in the documents, the asked fact isn't). "In the prompt" means the right page was in the top 3, about what fits the 1,000-token prompt.

| Threshold | Answerable refused | …of which answer was in the prompt | Unanswerable refused | Off-topic refused | Near misses refused |
|---|---|---|---|---|---|
| 0.26 | 0/50 | 0 | 1/10 | 1/4 | 0/6 |
| **0.30** | **2/50 (4%)** | **1** | **2/10 (20%)** | **2/4** | **0/6** |
| 0.32 | 2/50 | 1 | 3/10 | 3/4 | 0/6 |
| 0.36 | 5/50 | 3 | 3/10 | 3/4 | 0/6 |
| 0.40 | 9/50 | 7 | 3/10 | 3/4 | 0/6 |
| 0.46 | 16/50 | 13 | 5/10 | 3/4 | 2/6 |
| 0.52 | 28/50 | 24 | 8/10 | 3/4 | 5/6 |

- **Chosen: 0.30** (the value set provisionally in 3.3). Refusal rate: **20% of unanswerable questions (2/10), 4% of answerable ones (2/50)**. Of the 2 answerable refusals, only q45 (French question on an English document, right page at rank 1, similarity 0.265) loses an answer; q43 (0.272) was a retrieval miss anyway.
- **Why not higher:** a gate refusal is final and instant, while an unanswerable question that passes still meets the prompt's "reply Not found" rule. Refusing an answerable question costs more than letting an unanswerable one through. Above 0.34 the real losses grow quickly (3 at 0.36, 7 at 0.40) and no further off-topic question is caught until 0.54.
- **Why not 0.26 or 0.32:** both sit within ~0.01 of an answerable question (q45 at 0.265, q38 at 0.323); with 60 questions that's noise. 0.30 has 0.023–0.028 of margin to the nearest answerable questions on both sides.
- **Near misses can't be gated by similarity:** they score like answerable questions (0.41–0.59) because the topic really is there. Catching them is the model's job; its own refusal rate is measured with the full answer benchmark (4.1–4.2).
- **The gate saves time too:** a refusal comes after retrieval only (~2.2–4.5 s), instead of ~20 s before the model's first word.
- Both answerable questions below the threshold are French questions on English documents: cross-language similarities run lower. A per-language threshold would need more questions than this set has.

## Answers (50 answerable + 10 unanswerable)

| Date | Correct | Partial | Wrong | Citation accuracy | Correct refusals (of 10) |
|---|---|---|---|---|---|
