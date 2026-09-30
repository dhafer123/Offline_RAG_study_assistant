# Metrics

Put this file at `docs/METRICS.md` in the repo.
All numbers: release build, real device, median of 10 runs unless noted.

**Device:** Samsung Galaxy A16 (SM-A165F), MediaTek Helio G99 (MT6789), 4 GB RAM, Android 16

## LLM speed

| Date | Model | Load time (s) | Time to first token (s) | Tokens/sec | Peak RAM (MB) |
|---|---|---|---|---|---|

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
