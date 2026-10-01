// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The chat session: asks questions one at a time through [AnswerService].
///
/// Kept alive for the app's lifetime, so going back to the Library doesn't
/// lose the conversation or cancel an answer being written.

@ProviderFor(ChatController)
final chatControllerProvider = ChatControllerProvider._();

/// The chat session: asks questions one at a time through [AnswerService].
///
/// Kept alive for the app's lifetime, so going back to the Library doesn't
/// lose the conversation or cancel an answer being written.
final class ChatControllerProvider
    extends $NotifierProvider<ChatController, ChatState> {
  /// The chat session: asks questions one at a time through [AnswerService].
  ///
  /// Kept alive for the app's lifetime, so going back to the Library doesn't
  /// lose the conversation or cancel an answer being written.
  ChatControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatControllerHash();

  @$internal
  @override
  ChatController create() => ChatController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatState>(value),
    );
  }
}

String _$chatControllerHash() => r'5b080cec016cecc07acc50fc3994480dc8a3442a';

/// The chat session: asks questions one at a time through [AnswerService].
///
/// Kept alive for the app's lifetime, so going back to the Library doesn't
/// lose the conversation or cancel an answer being written.

abstract class _$ChatController extends $Notifier<ChatState> {
  ChatState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ChatState, ChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatState, ChatState>,
              ChatState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
