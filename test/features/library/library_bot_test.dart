import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/features/library/library_bot.dart';
import 'package:offline_study_assistant/features/library/library_controller.dart';

void main() {
  Document doc(int id, DocumentStatus status, {String title = 'Graphs'}) =>
      Document(
        id: id,
        title: title,
        path: '/$id.pdf',
        pageCount: 3,
        status: status,
      );

  LibraryState state(
    List<Document> docs, {
    int? runningId,
    List<int> queued = const [],
  }) => LibraryState(
    loading: false,
    documents: docs,
    runningId: runningId,
    queued: queued,
  );

  test('invites questions about the ready documents', () {
    final one = libraryGreeting(state([doc(1, DocumentStatus.ready)]));
    expect(one.mood, BotMood.happy);
    expect(one.title, 'Ask me about your document!');

    final two = libraryGreeting(
      state([doc(1, DocumentStatus.ready), doc(2, DocumentStatus.ready)]),
    );
    expect(two.title, 'Ask me about your 2 documents!');
    expect(two.body, contains('pages'));
  });

  test('reads while a document is indexed, naming it', () {
    final g = libraryGreeting(
      state(
        [
          doc(1, DocumentStatus.ready),
          doc(2, DocumentStatus.indexing, title: 'Algebra'),
          doc(3, DocumentStatus.pending),
        ],
        runningId: 2,
        queued: [3],
      ),
    );

    expect(g.mood, BotMood.reading);
    expect(g.title, 'Reading "Algebra"…');
    expect(g.body, startsWith('Then 1 more.'));
  });

  test('points to Retry when documents failed', () {
    final none = libraryGreeting(state([doc(1, DocumentStatus.failed)]));
    expect(none.mood, BotMood.sad);
    expect(none.body, contains('Retry'));

    final some = libraryGreeting(
      state([doc(1, DocumentStatus.ready), doc(2, DocumentStatus.failed)]),
    );
    expect(some.mood, BotMood.happy);
    expect(some.body, contains('Retry'));
  });
}
