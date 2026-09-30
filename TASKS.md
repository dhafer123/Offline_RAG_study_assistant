# TASKS.md — Offline Study Assistant

One task = one Claude Code session = one commit. Work top to bottom.
Prompt to use: **"Do task X.Y from TASKS.md. Plan first, then implement, then run analyze and tests."**
Each task lists what "done" means. Don't tick a box until that's true.

Legend: `[ ]` todo · `[x]` done · **Gate** = must pass before the next week starts.

---

## Week 1 (Oct 1–7): prove the model runs on the phone

- [x] **1.1 Project setup**
  Flutter project, folder layout from CLAUDE.md, Riverpod, go_router, lints (`very_good_analysis` or `flutter_lints`), `.gitignore` that excludes model files, and a README stub.
  *Done when:* the app runs, and `flutter analyze` and `flutter test` pass.
  *Notes:* very_good_analysis (without `public_member_api_docs`). Riverpod stays at flutter_riverpod 3.1 / riverpod_annotation 4.0 because newer versions need a newer Dart SDK than Flutter 3.38.9. Generated `*.g.dart` files are committed so CI doesn't need build_runner. Android + iOS platforms only.

- [x] **1.2 CI**
  GitHub Actions workflow running `flutter analyze` and `flutter test` on push and on pull requests.
  *Done when:* the badge in the README is green.
  *Notes:* Flutter pinned to 3.38.9 in CI. The workflow also checks `dart format` and that the committed `*.g.dart` files are up to date.

- [x] **1.3 LlmEngine interface + Gemma implementation**
  `LlmEngine` has `load()`, `generate(prompt) -> Stream<String>` and `unload()`. The implementation uses flutter_gemma, following its README for the installed version.
  *Done when:* a debug screen streams an answer to a hardcoded prompt on the real phone.
  *Notes:* flutter_gemma 0.16.5 (1.x needs Dart 3.12). Model loads from a file pushed with adb until 1.6 (see README). build_runner now needs `--force-jit` because flutter_gemma uses native-asset build hooks. Default backend is CPU: on the 4 GB test phone the GPU path hit ~1.7 GB RSS + 0.5 GB swap and was killed by lmkd at the first decode step; CPU streams fine with maxTokens 4096.

- [x] **1.4 Perf helper + first measurements**
  Measure time to first token, tokens/sec and load time. Record peak RAM from the Android Studio profiler. Release build only.
  *Done when:* `docs/METRICS.md` has the numbers (median of 10 runs), the phone model and the date.
  *Notes:* `Perf` + `GenerationTimer` in `lib/core/perf.dart`; benchmark screen (speed icon on Library). `LlmEngine.lastUsage` exposes real token counts from LiteRT-LM. Peak RAM from `ProcessInfo.maxRss` + `dumpsys meminfo`, not the Android Studio profiler. Release builds needed R8 keep rules (`android/app/proguard-rules.pro`). Median: 0.86 s load, 4.41 s TTFT, 8.38 tok/s, ~1.17 GB peak.

- [x] **1.5 Model comparison (only if 1.4 is slow)**
  Run the same measurements with Qwen3 0.6B, then pick the default model.
  *Done when:* the decision and the numbers are in METRICS.md.
  *Notes:* Gemma 3 1B stays the default: 8.38 vs 3.10 tok/s, 4.41 vs 8.09 s to the first token, ~600 MB less RAM than Qwen3 0.6B (the loadable file is INT8). The INT4 Qwen3 file needs LiteRT-LM 0.17+ (flutter_gemma 0.16.5 bundles 0.12.0). The benchmark screen has a model picker; `GemmaLlmEngine` appends `/no_think` for Qwen3.

- [ ] **1.6 ModelManager**
  First-launch download with a progress bar, resume after interruption, checksum check, and a Wi-Fi-only option. Handle states: not downloaded → downloading → ready → error.
  *Done when:* a fresh install downloads the model, then the app works in airplane mode.

**Gate 1:** at least 5 tok/s on your phone and no crash, with the chosen model.

---

## Week 2 (Oct 8–14): indexing and retrieval

- [ ] **2.1 Database schema (drift)**
  Tables `documents` (id, title, path, pageCount, indexedAt, status) and `chunks` (id, docId, page, ordinal, text), plus an FTS5 virtual table over the chunk text.
  *Done when:* there's a migration test and the insert and query tests pass.

- [ ] **2.2 PDF text extraction**
  pdfrx extracts text per page. Detect empty pages (scanned PDFs) and flag them.
  *Done when:* it works on 3 of your real course PDFs, with a test using a small fixture PDF.

- [ ] **2.3 Text cleaner**
  Remove repeated headers and footers and page numbers, rejoin hyphenated line breaks, and normalize whitespace.
  *Done when:* unit tests cover each rule.

- [ ] **2.4 Chunker**
  About 250 words with about 50 words of overlap, never across a page, and keep page + ordinal.
  *Done when:* unit tests cover short pages, long pages and empty pages.

- [ ] **2.5 Embedder + VectorIndex**
  `Embedder` interface with an EmbeddingGemma implementation, and `VectorIndex` wrapping flutter_gemma_rag_sqlite (`add`, `search(vector, k)`, `deleteByDoc`).
  *Done when:* you can search an indexed document from a debug screen.

- [ ] **2.6 IngestionService + Library screen**
  Pick a PDF → extract → clean → chunk (in a background isolate) → embed → store. Show a document list with per-document progress, and support deleting a document.
  *Done when:* the UI stays smooth while a 100-page PDF indexes, and the indexing time is logged in METRICS.md.

- [ ] **2.7 Eval set**
  Write `eval/questions.json`: 50 answerable questions from 3–4 of your PDFs, each with `doc` + `page` + the expected answer, plus 10 unanswerable questions. Mix French and English.
  *Done when:* the file is committed. (Write the questions yourself, not with AI, so the eval stays honest.)

- [ ] **2.8 Vector-only Recall@5**
  Add a benchmark screen that runs retrieval for every question and exports JSON.
  *Done when:* the Recall@5 number is in METRICS.md.

**Gate 2:** Recall@5 is measured and all tests pass.

---

## Week 3 (Oct 15–21): answers with citations

- [ ] **3.1 Keyword search + RRF**
  FTS5 top 20 plus vector top 20, merged by RRF (k = 60) into the top 5, in a pure `rrf.dart` file with unit tests.
  *Done when:* hybrid Recall@5 and its gain over vector-only are in METRICS.md.

- [ ] **3.2 Prompt builder**
  Numbered sources, rules (answer only from the sources, cite `[n]`, answer in the question's language, say you don't know if the answer isn't there), and a token budget that trims the sources.
  *Done when:* unit tests check the output and the budget.

- [ ] **3.3 AnswerService + "not found" gate**
  Check the similarity threshold, then build the prompt and stream the answer. Put the threshold in config.
  *Done when:* an unanswerable question returns "Not found in your documents" without calling the LLM.

- [ ] **3.4 Citation parser**
  Turn `[n]` markers into chunk → document + page. Drop numbers that match no source.
  *Done when:* unit tests cover `[1]`, `[1][3]`, `[1, 2]`, `[7]` (invalid) and no citations.

- [ ] **3.5 Chat screen**
  Question input, streamed answer, citation chips, a stop button, and a loading state while the model loads.
  *Done when:* a full question → answer → chip flow works on the phone.

- [ ] **3.6 PDF viewer at a page**
  Tapping a chip opens the document at that page, ideally with the chunk text highlighted.
  *Done when:* it opens on the correct page.

- [ ] **3.7 Tune the gate threshold**
  Use the 10 unanswerable and 50 answerable questions to pick the threshold.
  *Done when:* the chosen value and the refusal rate are in METRICS.md.

**Gate 3:** a cited answer works end to end in airplane mode.

---

## Week 4 (Oct 22–28): evaluate, polish, ship

- [ ] **4.1 Full benchmark run**
  Run all 60 questions and export answers, citations, time to first token and tokens/sec to `eval/results/*.json`.
- [ ] **4.2 Grade answers by hand**
  Mark each one correct / partial / wrong / correctly declined, and check citation accuracy.
- [ ] **4.3 Notebook charts**
  `eval/analyze.ipynb` produces the metrics table and 2–3 charts (vector vs hybrid Recall@5, latency distribution).
- [ ] **4.4 UI polish**
  Empty states, error messages, dark mode, app icon and splash screen, plus a first-launch screen explaining the download.
- [ ] **4.5 README**
  GIF at the top, architecture diagram, metrics table with the phone model, how to run it, the v2 list, and a license.
- [ ] **4.6 Demo video** (60–90 s)
  Import a PDF → turn on airplane mode → ask 3 questions → tap a citation.
- [ ] **4.7 Release**
  Signed APK on GitHub Releases, then a Play Store internal or closed test.
- [ ] **4.8 Update CV and LinkedIn**
  Add the real numbers to the CV line.

**Gate 4:** APK released and demo video published.

---

## v2 backlog (don't start before Gate 4)

- OCR for scanned PDFs (ML Kit text recognition)
- Flashcards and quizzes generated from a chapter
- Chat history per course, multi-turn follow-ups
- Arabic and Darija questions

## Notes

- 2026-09-30: LLM runs on CPU by default (GPU backend OOM-killed on the 4 GB Galaxy A16).
- 2026-09-30: Gemma 3 1B reaches 8.4 tok/s on CPU (Gate 1 needs 5). Compared with Qwen3 0.6B anyway (1.5): Gemma 3 1B stays the default.

<!-- Add a short dated line whenever a decision changes the plan, e.g. "2026-10-05: switched to Qwen3 0.6B, Gemma 3 1B only reached 3 tok/s." -->
