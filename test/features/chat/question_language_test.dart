import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_study_assistant/features/chat/question_language.dart';

void main() {
  test('detects French questions', () {
    for (final q in [
      'Quel moteur de jeu a été utilisé ?',
      "Qu'est-ce que le RAG ?",
      'Pourquoi utiliser des embeddings',
      'Combien coûte une licence Unity ?',
      'probleme du demarrage a froid dans les systemes de recommandation',
    ]) {
      expect(detectQuestionLanguage(q), AnswerLanguage.french, reason: q);
    }
  });

  test('detects English questions', () {
    for (final q in [
      'What is the sprint retrospective used for?',
      'Who introduced the transformer architecture?',
      'List some practical techniques that improve a RAG system.',
      'How does the NPC call the remote LLM?',
    ]) {
      expect(detectQuestionLanguage(q), AnswerLanguage.english, reason: q);
    }
  });

  test('accents count for French even without function words', () {
    expect(
      detectQuestionLanguage('Problématique étudiée'),
      AnswerLanguage.french,
    );
  });

  test('defaults to English when there is no clue', () {
    expect(detectQuestionLanguage(''), AnswerLanguage.english);
    expect(detectQuestionLanguage('RAG LLM FAISS'), AnswerLanguage.english);
    expect(detectQuestionLanguage('42 ?'), AnswerLanguage.english);
  });

  test('matches the language of all 60 eval questions', () {
    final json =
        jsonDecode(File('eval/questions.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final q in (json['questions'] as List).cast<Map<String, dynamic>>()) {
      final expected = q['lang'] == 'fr'
          ? AnswerLanguage.french
          : AnswerLanguage.english;
      expect(
        detectQuestionLanguage(q['question'] as String),
        expected,
        reason: '${q['id']}: ${q['question']}',
      );
    }
  });
}
