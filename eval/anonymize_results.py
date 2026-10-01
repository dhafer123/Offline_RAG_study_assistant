"""Makes an answer-eval export from the phone safe to commit.

The eval index includes a private 120-page report as a distractor. Its title
must not appear in the repo, and neither may its content, which a generated
answer can quote whenever one of its chunks was in the prompt. This script:

- renames the private document to an anonymous key everywhere;
- replaces the answer of every question whose prompt held a chunk of it,
  keeping all the other fields (metrics, sources, citations).

Usage:
    python eval/anonymize_results.py PHONE_EXPORT.json OUT.json \
        --private-title "Title as indexed" [--alias distractor_report_120p]

Keep the unredacted export in eval/results/private/ (git-ignored) for grading.
"""

import argparse
import json

REDACTED = "[redacted: the prompt held text from the private distractor document]"


def anonymize(report: dict, private_title: str, alias: str) -> tuple[dict, int]:
    def rename(title: str) -> str:
        return alias if title == private_title else title

    redacted = 0
    report["indexed_documents"] = [rename(t) for t in report["indexed_documents"]]
    for result in report["results"]:
        private = any(s["doc"] == private_title for s in result["sources"])
        for item in result["sources"] + result["citations"]:
            item["doc"] = rename(item["doc"])
        if private and not result["refused_by_gate"]:
            result["answer"] = REDACTED
            result["answer_redacted"] = True
            redacted += 1
    return report, redacted


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("out")
    parser.add_argument("--private-title", required=True)
    parser.add_argument("--alias", default="distractor_report_120p")
    args = parser.parse_args()

    with open(args.source, encoding="utf-8") as f:
        report = json.load(f)
    report, redacted = anonymize(report, args.private_title, args.alias)
    text = json.dumps(report, ensure_ascii=False, indent=2)
    if args.private_title in text:
        raise SystemExit("private title still present, not writing")
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(text + "\n")
    print(f"wrote {args.out}: {redacted} answers redacted")


if __name__ == "__main__":
    main()
