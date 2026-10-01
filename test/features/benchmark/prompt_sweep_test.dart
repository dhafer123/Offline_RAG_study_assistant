import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/core/ai/llm_engine.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/features/benchmark/prompt_sweep.dart';
import 'package:offline_study_assistant/features/chat/prompt_builder.dart';
import 'package:offline_study_assistant/features/chat/retrieval_service.dart';

import '../../helpers/fake_llm_engine.dart';

final List<RetrievedChunk> _chunks = [
  for (var i = 0; i < 20; i++)
    RetrievedChunk(
      chunk: Chunk(
        id: i,
        docId: 1,
        page: i + 1,
        ordinal: i,
        text: List.filled(150, 'word').join(' '),
      ),
      documentTitle: 'a.pdf',
      score: 0,
    ),
];

void main() {
  test('builds bigger prompts for bigger targets, within ~1.1x', () {
    final sizes = [
      for (final t in defaultSweepTargets)
        sweepPrompt(_chunks, t).estimatedTokens,
    ];

    for (var i = 1; i < sizes.length; i++) {
      expect(sizes[i], greaterThan(sizes[i - 1]));
    }
    for (final t in defaultSweepTargets) {
      expect(
        sweepPrompt(_chunks, t).estimatedTokens,
        lessThanOrEqualTo((t * 1.1).round()),
      );
    }
    expect(sweepPrompt(_chunks, 2450).text, contains(sweepQuestion));
    expect(estimateTokens(sweepPrompt(_chunks, 2450).text), greaterThan(2400));
  });

  test('warms up once, then runs every target `repeats` times', () async {
    final llm = FakeLlmEngine(
      tokens: ['A ', 'b.'],
      usage: const LlmUsage(promptTokens: 300, outputTokens: 2),
    );
    final progress = <int>[];

    final runs = await PromptSweep(llm).run(
      _chunks,
      targets: [240, 300],
      repeats: 2,
      onRun: (done, total, _) {
        progress.add(done);
        expect(total, 4);
      },
    );

    expect(llm.loadCalls, 1);
    expect(llm.prompts, hasLength(5));
    expect(llm.prompts.first, llm.prompts[1]);
    expect([for (final r in runs) r.target], [240, 240, 300, 300]);
    expect(progress, [1, 2, 3, 4]);
    expect(runs.first.promptTokens, 300);
    expect(runs.first.toJson()['output_tokens'], 2);
  });

  test('stops when cancelled', () async {
    final llm = FakeLlmEngine(tokens: ['x']);
    var calls = 0;

    final runs = await PromptSweep(
      llm,
    ).run(_chunks, targets: [240, 300], isCancelled: () => ++calls > 1);

    expect(runs, hasLength(1));
  });
}
