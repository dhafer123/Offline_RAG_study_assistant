import 'package:offline_study_assistant/app/widgets/bot/bot_mood.dart';
import 'package:offline_study_assistant/core/db/document_store.dart';
import 'package:offline_study_assistant/features/library/library_controller.dart';

/// What the bot says at the top of a library that has documents.
typedef LibraryGreeting = ({BotMood mood, String title, String body});

LibraryGreeting libraryGreeting(LibraryState state) {
  final ready = state.documents
      .where((d) => d.status == DocumentStatus.ready && !state.isBusy(d.id))
      .length;
  final failed = state.documents
      .where((d) => d.status == DocumentStatus.failed && !state.isBusy(d.id))
      .length;

  if (state.runningId case final id?) {
    final title = state.documents
        .where((d) => d.id == id)
        .map((d) => d.title)
        .firstOrNull;
    final waiting = state.queued.length;
    return (
      mood: BotMood.reading,
      title: title == null ? 'Reading a document…' : 'Reading "$title"…',
      body: waiting == 0
          ? 'You can keep using the app while I read.'
          : 'Then $waiting more. You can keep using the app while I read.',
    );
  }
  if (state.queued.isNotEmpty) {
    return (
      mood: BotMood.reading,
      title: 'Getting ready to read…',
      body: 'You can keep using the app while I read.',
    );
  }
  if (ready == 0) {
    return (
      mood: BotMood.sad,
      title: failed == 1
          ? "I couldn't read your document."
          : "I couldn't read your documents.",
      body: 'Open its menu and tap Retry, or import another PDF.',
    );
  }
  return (
    mood: BotMood.happy,
    title: ready == 1
        ? 'Ask me about your document!'
        : 'Ask me about your $ready documents!',
    body: switch (failed) {
      0 => 'Every answer shows the pages it comes from.',
      1 => "I couldn't read one of them: tap Retry in its menu.",
      _ => "I couldn't read $failed of them: tap Retry in their menus.",
    },
  );
}
