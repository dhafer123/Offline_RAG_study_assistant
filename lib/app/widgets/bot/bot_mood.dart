/// What the assistant bot is showing. Each mood is a face; some animate.
enum BotMood {
  /// Waiting. Blinks now and then.
  idle,

  /// "^ ^" eyes and a smile: greetings, an answer that's done.
  happy,

  /// Eyes up, antenna pulsing: the model reads the sources (prefill).
  thinking,

  /// Eyes moving along a line: indexing a document.
  reading,

  /// Eyes looking around: searching the documents.
  searching,

  /// Mouth moving: the answer is streaming.
  talking,

  /// Head tilted, one eye squinted: nothing found.
  confused,

  /// Drooping eyes: something failed.
  sad,

  /// Round eyes: something new, a warning.
  surprised
  ;

  /// Length of one animation cycle, or null for a still face.
  Duration? get loop => switch (this) {
    thinking => const Duration(milliseconds: 1800),
    reading => const Duration(milliseconds: 2600),
    searching => const Duration(milliseconds: 2200),
    talking => const Duration(milliseconds: 420),
    _ => null,
  };

  /// Whether the eyes blink from time to time (open, rectangular eyes only).
  bool get blinks => switch (this) {
    idle || reading || searching || talking => true,
    _ => false,
  };

  /// For screen readers.
  String get label => switch (this) {
    idle => 'Assistant',
    happy => 'Assistant, happy',
    thinking => 'Assistant, thinking',
    reading => 'Assistant, reading',
    searching => 'Assistant, searching',
    talking => 'Assistant, answering',
    confused => 'Assistant, confused',
    sad => 'Assistant, sad',
    surprised => 'Assistant, surprised',
  };
}
