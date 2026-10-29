import 'package:anki_flow/deck_style.dart';
import 'package:anki_flow/models.dart';
import 'package:anki_flow/services/card_generator.dart';
import 'package:anki_flow/services/sync_merge.dart';
import 'package:anki_flow/srs.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _deck(String id, DateTime modified, {String name = 'D'}) =>
    {'id': id, 'name': name, 'language': 'en-GB', 'newPerDay': 20, 'modified': modified.toIso8601String()};

Map<String, dynamic> _card(String id, String deckId, DateTime modified, {String front = 'f'}) => Flashcard(
      id: id,
      deckId: deckId,
      front: front,
      back: 'b',
      created: DateTime(2026, 1, 1),
    ).toJson()
      ..['modified'] = modified.toIso8601String();

void main() {
  group('sync merge', () {
    final t1 = DateTime(2026, 10, 1), t2 = DateTime(2026, 10, 2), t3 = DateTime(2026, 10, 3);

    test('union of both sides, newer edit wins', () {
      final a = {
        'decks': [_deck('d1', t1)],
        'cards': [_card('c1', 'd1', t1, front: 'old'), _card('c2', 'd1', t1)],
        'logs': [],
      };
      final b = {
        'decks': [_deck('d1', t1)],
        'cards': [_card('c1', 'd1', t2, front: 'new'), _card('c3', 'd1', t2)],
        'logs': [],
      };
      final m = mergeSyncPayloads(a, b);
      final cards = {for (final c in m['cards'] as List) c['id']: c};
      expect(cards.keys.toSet(), {'c1', 'c2', 'c3'});
      expect(cards['c1']['front'], 'new');
    });

    test('deleted card stays deleted unless edited later', () {
      final a = {
        'decks': [_deck('d1', t1)],
        'cards': [_card('c1', 'd1', t1), _card('c2', 'd1', t3)],
        'logs': [],
      };
      final b = {
        'decks': [_deck('d1', t1)],
        'cards': [],
        'logs': [],
        'deleted': {'c1': t2.toIso8601String(), 'c2': t2.toIso8601String()},
      };
      final ids = (mergeSyncPayloads(a, b)['cards'] as List).map((c) => c['id']).toSet();
      expect(ids, {'c2'});
    });

    test('logs are de-duplicated and settings take the newer side', () {
      final log = {'c': 'c1', 't': t1.toIso8601String(), 'g': 3};
      final a = {'decks': [], 'cards': [], 'logs': [log], 'settings': {'newGoal': 10}, 'settingsModified': t1.toIso8601String()};
      final b = {'decks': [], 'cards': [], 'logs': [log], 'settings': {'newGoal': 30}, 'settingsModified': t2.toIso8601String()};
      final m = mergeSyncPayloads(a, b);
      expect((m['logs'] as List).length, 1);
      expect(m['settings']['newGoal'], 30);
    });
  });

  group('spaced repetition presets', () {
    final now = DateTime(2026, 10, 24, 12);
    Flashcard review() => Flashcard(id: 'x', deckId: 'd', front: 'f', back: 'b', created: now)
      ..state = CardState.review
      ..interval = 10
      ..ease = 2.5;

    test('higher retention gives shorter intervals', () {
      final strict = Scheduler.fromParams(SrsParams.aggressive).preview(review(), 3, now).interval;
      final normal = Scheduler.fromParams(SrsParams.standard).preview(review(), 3, now).interval;
      final relaxed = Scheduler.fromParams(SrsParams.relaxed).preview(review(), 3, now).interval;
      expect(strict, lessThan(normal));
      expect(normal, lessThan(relaxed));
    });

    test('without short-term steps new cards graduate at once', () {
      final c = Flashcard(id: 'n', deckId: 'd', front: 'f', back: 'b', created: now);
      final p = Scheduler(shortTerm: false).preview(c, 3, now);
      expect(p.state, CardState.review);
      expect(p.interval, 1);
    });
  });

  group('card generator', () {
    test('glossary lines become cards', () {
      final cards = CardGenerator.generate('refute - опровергнуть\ndeceive: обмануть');
      expect(cards.map((c) => c.front), containsAll(['refute', 'deceive']));
      expect(cards.firstWhere((c) => c.front == 'refute').back, 'опровергнуть');
    });

    test('finds inflected collocations with translation and example', () {
      final cards = CardGenerator.generate('Yesterday she made a decision to leave the company. Everyone was surprised.');
      final phrase = cards.firstWhere((c) => c.front == 'make a decision');
      expect(phrase.back, contains('принять решение'));
      expect(phrase.back, contains('made a decision'));
    });

    test('cloze style hides the phrase', () {
      final cards = CardGenerator.generate('We need to take into account the weather forecast.', style: CardStyle.cloze);
      final c = cards.firstWhere((c) => c.term == 'take into account');
      expect(c.front, contains('_____'));
      expect(c.front, isNot(contains('take into account')));
    });

    test('vocabulary skips common words and respects the count', () {
      const text = 'The committee postponed the controversial referendum. '
          'Analysts considered the postponement unprecedented and somewhat irresponsible. '
          'People were going to work in the morning.';
      final cards = CardGenerator.generate(text, count: 3);
      expect(cards.length, 3);
      expect(cards.map((c) => c.front), isNot(contains('people')));
      expect(cards.map((c) => c.front), isNot(contains('morning')));
    });
  });

  group('deck style', () {
    test('icon is guessed from the deck name', () {
      expect(DeckStyle.guessIcon('Work vocabulary'), 'work');
      expect(DeckStyle.guessIcon('Travel phrases'), 'travel');
      expect(DeckStyle.guessIcon('Conditions'), 'grammar');
      expect(DeckStyle.guessIcon('Olympiad'), 'olympiad');
      expect(DeckStyle.guessIcon('English'), 'language');
      expect(DeckStyle.guessIcon('Misc'), 'deck');
    });

    test('decks get different automatic colors and keep a chosen one', () {
      final colors = {for (final id in ['a1', 'b2', 'c3', 'd4', 'e5']) DeckStyle.autoColor(id)};
      expect(colors.length, greaterThan(2));
      expect(colors.contains(0), isFalse); // never the plain grey
      final d = Deck(id: 'x', name: 'X', color: 5);
      expect(DeckStyle.colorOf(Deck.fromJson(d.toJson())), 5);
    });
  });
}
