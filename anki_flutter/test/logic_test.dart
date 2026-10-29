import 'package:anki_flow/models.dart';
import 'package:anki_flow/services/pronunciation.dart';
import 'package:anki_flow/services/suggestions.dart';
import 'package:anki_flow/srs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PronunciationChecker', () {
    test('perfect repeat scores 100', () {
      final r = PronunciationChecker.check('I declined the call.', [SpeechAlternative('I declined the call', 0)]);
      expect(r.score, 100);
      expect(r.words.every((w) => w.status == WordStatus.correct), isTrue);
    });

    test('contractions are normalised', () {
      final r = PronunciationChecker.check("I can't afford it", [SpeechAlternative('I cannot afford it', 0)]);
      expect(r.score, 100);
    });

    test('a mispronounced word is marked close or wrong', () {
      final r = PronunciationChecker.check('refute the evidence', [SpeechAlternative('refuse the evidence', 0)]);
      expect(r.score, lessThan(100));
      expect(r.score, greaterThan(60));
      expect(r.words.first.status, WordStatus.close);
    });

    test('missing words are reported', () {
      final r = PronunciationChecker.check('see her off at the station', [SpeechAlternative('see her off', 0)]);
      expect(r.words.where((w) => w.status == WordStatus.missing).length, 3);
      expect(r.score, lessThan(60));
    });

    test('best alternative wins', () {
      final r = PronunciationChecker.check('get cut off', [
        SpeechAlternative('get caught off', 0),
        SpeechAlternative('get cut off', 0),
      ]);
      expect(r.score, 100);
    });
  });

  group('SuggestionService', () {
    final s = SuggestionService();
    test('offline collocations for a noun', () {
      final r = s.offline('decision');
      expect(r.map((e) => e.phrase), contains('make a decision'));
      expect(r.first.translation, isNotNull);
    });
    test('lemmatises inflected forms', () {
      expect(SuggestionService.lemma('decisions'), 'decision');
      expect(SuggestionService.lemma('made'), 'make');
      expect(SuggestionService.lemma('refuted'), 'refute');
    });
    test('picks the content word in a sentence', () {
      final r = s.offline('I had a billing issue');
      expect(r.map((e) => e.phrase), contains('billing address'));
    });
  });

  group('Scheduler (SM-2)', () {
    final now = DateTime(2026, 10, 20, 12);
    Flashcard fresh() => Flashcard(id: '1', deckId: 'd', front: 'f', back: 'b', created: now);

    test('new card goes through learning steps then graduates', () {
      final c = fresh();
      final sch = Scheduler();
      sch.answer(c, 3, now);
      expect(c.state, CardState.learning);
      expect(c.due, now.add(const Duration(minutes: 10)));
      sch.answer(c, 3, now);
      expect(c.state, CardState.review);
      expect(c.interval, 1);
    });

    test('review interval grows by ease, lapses on Again', () {
      final c = fresh()
        ..state = CardState.review
        ..interval = 10
        ..ease = 2.5;
      final sch = Scheduler();
      sch.answer(c, 3, now);
      expect(c.interval, 25);
      sch.answer(c, 1, now);
      expect(c.state, CardState.learning);
      expect(c.lapses, 1);
      expect(c.ease, closeTo(2.3, 1e-9));
    });

    test('max interval is respected', () {
      final c = fresh()
        ..state = CardState.review
        ..interval = 300;
      Scheduler(maxIntervalDays: 365).answer(c, 4, now);
      expect(c.interval, 365);
    });
  });
}
