import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'display.dart';
import 'models.dart';
import 'srs.dart';
import 'theme.dart';

enum QueueSort { dueDate, deck, created }

/// Single source of truth: decks, cards, review history and settings,
/// persisted to the browser's localStorage via shared_preferences.
class AppStore extends ChangeNotifier {
  static const _key = 'anki_flow_state_v1';

  final decks = <Deck>[];
  final cards = <Flashcard>[];
  final logs = <ReviewLog>[];

  /// Tombstones: id of a deleted deck/card → when it was deleted (for sync).
  final deleted = <String, DateTime>{};

  // ------------------------------------------------- synced settings
  // Daily goals
  bool goalTracking = true;
  int newGoal = 15;
  int reviewGoal = 25;
  int get dailyGoal => newGoal + reviewGoal;

  // Spaced repetition
  SrsPreset srsPreset = SrsPreset.standard;
  SrsParams customSrs = SrsParams.standard;
  SrsParams get srs => SrsParams.forPreset(srsPreset) ?? customSrs;

  // Notifications
  bool notifications = true;
  int reminderMinutes = 13 * 60; // minutes after midnight

  bool autoPlayAudio = false;
  bool onlineSuggestions = true;
  String accent = 'en-GB';
  double speechRate = 0.9;
  QueueSort queueSort = QueueSort.dueDate;
  String? email;

  /// When synced settings last changed; the newer side wins on sync.
  DateTime settingsModified = DateTime(2000);

  // -------------------------------------------- this-device settings
  bool darkMode = true;
  LayoutMode layoutMode = LayoutMode.auto;
  double uiScale = 1.0;
  double textScale = 1.0;

  /// Max width of the phone layout when the window is wider (e.g. phone mode on a Mac).
  double phoneWidth = 520;

  /// Chosen voice name per accent ('' = best available). Voices differ per device.
  final voices = <String, String>{};

  /// Called after every local change (the sync service debounces a push).
  VoidCallback? onLocalChange;

  Scheduler get scheduler => Scheduler.fromParams(srs);

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw == null) {
      _seed();
      await save();
    } else {
      try {
        _fromJson(jsonDecode(raw));
      } catch (_) {
        _seed();
      }
    }
    AppColors.dark = darkMode;
  }

  Future<void> save() async {
    await _prefs?.setString(_key, jsonEncode(toJson()));
  }

  void _changed({bool settings = false}) {
    if (settings) settingsModified = DateTime.now();
    AppColors.dark = darkMode;
    notifyListeners();
    save();
    onLocalChange?.call();
  }

  /// Call after mutating synced settings fields directly.
  void touch() => _changed(settings: true);

  /// Call after mutating this-device settings (theme, layout, voices).
  void touchDevice() {
    AppColors.dark = darkMode;
    notifyListeners();
    save();
  }

  Map<String, dynamic> settingsJson() => {
        'goalTracking': goalTracking,
        'newGoal': newGoal,
        'reviewGoal': reviewGoal,
        'srsPreset': srsPreset.index,
        'srsRetention': customSrs.retention,
        'srsMaxInterval': customSrs.maxIntervalDays,
        'srsFuzz': customSrs.fuzz,
        'srsShortTerm': customSrs.shortTerm,
        'notifications': notifications,
        'reminderMinutes': reminderMinutes,
        'autoPlayAudio': autoPlayAudio,
        'onlineSuggestions': onlineSuggestions,
        'accent': accent,
        'speechRate': speechRate,
        'queueSort': queueSort.index,
        'email': email,
      };

  void applySettingsJson(Map s) {
    goalTracking = s['goalTracking'] ?? true;
    newGoal = s['newGoal'] ?? 15;
    reviewGoal = s['reviewGoal'] ?? 25;
    srsPreset = SrsPreset.values[s['srsPreset'] ?? 0];
    customSrs = SrsParams(
      retention: (s['srsRetention'] ?? 0.9).toDouble(),
      maxIntervalDays: s['srsMaxInterval'] ?? 365,
      fuzz: s['srsFuzz'] ?? true,
      shortTerm: s['srsShortTerm'] ?? true,
    );
    notifications = s['notifications'] ?? true;
    reminderMinutes = s['reminderMinutes'] ?? 13 * 60;
    autoPlayAudio = s['autoPlayAudio'] ?? false;
    onlineSuggestions = s['onlineSuggestions'] ?? true;
    accent = s['accent'] ?? 'en-GB';
    speechRate = (s['speechRate'] ?? 0.9).toDouble();
    queueSort = QueueSort.values[s['queueSort'] ?? 0];
    email = s['email'];
  }

  /// Everything that is shared between devices.
  Map<String, dynamic> syncJson() => {
        'decks': decks.map((d) => d.toJson()).toList(),
        'cards': cards.map((c) => c.toJson()).toList(),
        'logs': logs.map((l) => l.toJson()).toList(),
        'deleted': deleted.map((k, v) => MapEntry(k, v.toIso8601String())),
        'settings': settingsJson(),
        'settingsModified': settingsModified.toIso8601String(),
      };

  /// Replaces shared data with [j] (a merged sync payload). Device settings stay.
  void applySyncJson(Map<String, dynamic> j) {
    decks
      ..clear()
      ..addAll((j['decks'] as List).map((e) => Deck.fromJson(e)));
    cards
      ..clear()
      ..addAll((j['cards'] as List).map((e) => Flashcard.fromJson(e)));
    logs
      ..clear()
      ..addAll((j['logs'] as List).map((e) => ReviewLog.fromJson(e)));
    deleted
      ..clear()
      ..addAll(((j['deleted'] as Map?) ?? {}).map((k, v) => MapEntry(k as String, DateTime.parse(v))));
    applySettingsJson((j['settings'] as Map?) ?? {});
    settingsModified =
        j['settingsModified'] == null ? DateTime(2000) : DateTime.parse(j['settingsModified']);
  }

  /// Applies a merged payload from sync without triggering another push.
  void replaceFromSync(Map<String, dynamic> j) {
    applySyncJson(j);
    AppColors.dark = darkMode;
    notifyListeners();
    save();
  }

  Map<String, dynamic> toJson() => {
        ...syncJson(),
        'device': {
          'darkMode': darkMode,
          'layoutMode': layoutMode.index,
          'uiScale': uiScale,
          'textScale': textScale,
          'phoneWidth': phoneWidth,
          'voices': voices,
        },
      };

  void _fromJson(Map<String, dynamic> j) {
    applySyncJson(j);
    final s = (j['settings'] as Map?) ?? {};
    // Settings saved by older versions of the app.
    if (s.containsKey('dailyGoal') && !s.containsKey('newGoal')) {
      final g = s['dailyGoal'] as int;
      newGoal = (g * 0.375).round();
      reviewGoal = g - newGoal;
    }
    final d = (j['device'] as Map?) ?? s;
    darkMode = d['darkMode'] ?? true;
    layoutMode = LayoutMode.values[d['layoutMode'] ?? 0];
    uiScale = (d['uiScale'] ?? 1.0).toDouble();
    textScale = (d['textScale'] ?? 1.0).toDouble();
    phoneWidth = (d['phoneWidth'] ?? 520).toDouble();
    voices
      ..clear()
      ..addAll(((d['voices'] as Map?) ?? {}).cast<String, String>());
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  bool importJson(String raw) {
    try {
      _fromJson(jsonDecode(raw));
      _changed();
      return true;
    } catch (_) {
      return false;
    }
  }

  void resetToDemo() {
    final now = DateTime.now();
    for (final c in cards) {
      deleted[c.id] = now;
    }
    for (final d in decks) {
      deleted[d.id] = now;
    }
    _seed(keepTombstones: true);
    _changed();
  }

  void eraseAll() {
    final now = DateTime.now();
    for (final c in cards) {
      deleted[c.id] = now;
    }
    for (final d in decks) {
      deleted[d.id] = now;
    }
    decks.clear();
    cards.clear();
    logs.clear();
    _changed();
  }

  // ---------------------------------------------------------------- queries

  String _id() => '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(9999)}';

  Deck? deckById(String id) => decks.where((d) => d.id == id).firstOrNull;

  List<Flashcard> cardsOf(String deckId) => cards.where((c) => c.deckId == deckId).toList();

  int newStudiedToday(String deckId, DateTime now) {
    final today = dayOnly(now);
    final deckIds = cardsOf(deckId).map((c) => c.id).toSet();
    return logs.where((l) => l.wasNew && !l.time.isBefore(today) && deckIds.contains(l.cardId)).length;
  }

  /// Cards ready to study now, optionally for one deck. New cards are capped by
  /// the deck limit and the daily New cards goal, reviews by the Reviews goal.
  List<Flashcard> queue({String? deckId, DateTime? at}) {
    final now = at ?? DateTime.now();
    final today = dayOnly(now);
    final todays = logs.where((l) => !l.time.isBefore(today));
    // With goal tracking off only the per-deck new card limit applies.
    var newGoalLeft = goalTracking ? max(0, newGoal - todays.where((l) => l.wasNew).length) : 1 << 30;
    final reviewGoalLeft = goalTracking ? max(0, reviewGoal - todays.where((l) => l.wasReview).length) : 1 << 30;
    final result = <Flashcard>[];
    final due = <Flashcard>[];
    for (final deck in decks) {
      if (deckId != null && deck.id != deckId) continue;
      final deckCards = cardsOf(deck.id);
      due.addAll(deckCards.where((c) => c.state != CardState.newCard && !c.due.isAfter(now)));
      final newLeft = max(0, min(deck.newPerDay - newStudiedToday(deck.id, now), newGoalLeft));
      final fresh = deckCards.where((c) => c.state == CardState.newCard).toList()
        ..sort((a, b) => a.created.compareTo(b.created));
      result.addAll(fresh.take(newLeft));
      newGoalLeft -= min(newLeft, fresh.length);
    }
    // Learning cards always come back; graduated reviews are capped by the goal.
    due.sort((a, b) => a.due.compareTo(b.due));
    result.addAll(due.where((c) => c.state == CardState.learning));
    result.addAll(due.where((c) => c.state == CardState.review).take(reviewGoalLeft));
    switch (queueSort) {
      case QueueSort.dueDate:
        // New cards first like the original app, then by due time.
        result.sort((a, b) {
          final an = a.state == CardState.newCard ? 0 : 1;
          final bn = b.state == CardState.newCard ? 0 : 1;
          if (an != bn) return an - bn;
          return a.due.compareTo(b.due);
        });
      case QueueSort.deck:
        result.sort((a, b) =>
            (deckById(a.deckId)?.name ?? '').compareTo(deckById(b.deckId)?.name ?? ''));
      case QueueSort.created:
        result.sort((a, b) => b.created.compareTo(a.created));
    }
    return result;
  }

  int answeredToday() {
    final today = dayOnly(DateTime.now());
    return logs.where((l) => !l.time.isBefore(today)).length;
  }

  /// True while the user hasn't added anything of their own (just the demo decks).
  bool get onlyDemoData =>
      decks.every((d) => d.id.startsWith('english') || d.id.startsWith('olympiad')) &&
      cards.every((c) => c.id.startsWith('seed'));

  int countState(CardState s) => cards.where((c) => c.state == s).length;

  // -------------------------------------------------------------- mutations

  Deck addDeck(String name, {String language = 'en-GB'}) {
    final d = Deck(id: _id(), name: name, language: language);
    decks.add(d);
    _changed();
    return d;
  }

  void updateDeck(Deck d) {
    d.modified = DateTime.now();
    _changed();
  }

  void deleteDeck(String id) {
    final now = DateTime.now();
    deleted[id] = now;
    for (final c in cards.where((c) => c.deckId == id)) {
      deleted[c.id] = now;
    }
    decks.removeWhere((d) => d.id == id);
    cards.removeWhere((c) => c.deckId == id);
    _changed();
  }

  Flashcard addCard(String deckId, String front, String back, {String? imageUrl}) {
    final now = DateTime.now();
    final c = Flashcard(id: _id(), deckId: deckId, front: front.trim(), back: back.trim(), created: now, imageUrl: imageUrl);
    cards.add(c);
    _changed();
    return c;
  }

  void updateCard(Flashcard c) {
    c.modified = DateTime.now();
    _changed();
  }

  void deleteCard(String id) {
    deleted[id] = DateTime.now();
    cards.removeWhere((c) => c.id == id);
    _changed();
  }

  void answer(Flashcard card, int grade) {
    final now = DateTime.now();
    logs.add(ReviewLog(
        cardId: card.id,
        time: now,
        grade: grade,
        wasReview: card.state == CardState.review,
        wasNew: card.state == CardState.newCard));
    scheduler.answer(card, grade, now);
    _changed();
  }

  /// Imports `front;back` (or tab / " - " separated) lines. Returns number of cards created.
  int importLines(String deckId, String text) {
    var n = 0;
    final now = DateTime.now();
    for (final line in const LineSplitter().convert(text)) {
      if (line.trim().isEmpty) continue;
      final sep = line.contains('\t')
          ? '\t'
          : line.contains(';')
              ? ';'
              : line.contains(' - ')
                  ? ' - '
                  : null;
      if (sep == null) continue;
      final i = line.indexOf(sep);
      final front = line.substring(0, i).trim();
      final back = line.substring(i + sep.length).trim();
      if (front.isEmpty) continue;
      cards.add(Flashcard(
          id: _id(), deckId: deckId, front: front, back: back, created: now.add(Duration(microseconds: n))));
      n++;
    }
    if (n > 0) _changed();
    return n;
  }

  // ------------------------------------------------------------------ seed

  void _seed({bool keepTombstones = false}) {
    decks.clear();
    cards.clear();
    logs.clear();
    if (!keepTombstones) deleted.clear();
    final rnd = Random(7);
    final now = DateTime.now();
    // Ids are unique per seeding so demo data on two devices never collides when syncing.
    final tag = now.microsecondsSinceEpoch.toRadixString(36);
    final english = Deck(id: 'english-$tag', name: 'English', language: 'en-GB');
    final olympiad = Deck(id: 'olympiad-$tag', name: 'Olympiad', language: 'en-GB');
    decks.addAll([english, olympiad]);

    const englishCards = [
      ['Refute an evidence', 'Refute - опровергнуть'],
      ["Don't let girls appear to deceive you", 'Deceive - обмануть'],
      ['Foreign affairs', 'affairs - дела, вопросы (государственные)'],
      ['I had a billing issue with my phone company', 'Billing - платёж, оплата'],
      ['I like your attitude', 'Attitude - настрой, отношение'],
      ['An independence country', 'Independent - независимый'],
      ['That was an embarrassing moment', 'Embarrassing - неловкий, смущающий'],
      ['Complete the sentence with the right word', 'Complete - завершить, дополнить'],
      ['She made a decision to quit', 'Make a decision - принять решение'],
      ['Pay attention to the details', 'Pay attention - обращать внимание'],
      ['It takes a lot of effort', 'Effort - усилие'],
      ['We are making progress', 'Make progress - делать успехи'],
      ['I can\'t afford it', 'Afford - позволить себе'],
      ['He gave up smoking', 'Give up - бросить'],
      ['Look forward to seeing you', 'Look forward to - с нетерпением ждать'],
      ['A reliable source', 'Reliable - надёжный'],
      ['Take advantage of the offer', 'Take advantage of - воспользоваться'],
      ['Raise awareness about the problem', 'Raise awareness - повышать осведомлённость'],
      ['I ran out of time', 'Run out of - закончиться'],
      ['Meet the deadline', 'Deadline - крайний срок'],
      ['It\'s worth trying', 'Worth - стоящий'],
      ['Break the habit', 'Habit - привычка'],
      ['Keep in touch', 'Keep in touch - оставаться на связи'],
      ['Draw a conclusion', 'Conclusion - вывод'],
    ];
    const olympiadCards = [
      ['I loved her so much that I decided to see her off at the train station', 'see off - проводить'],
      ['The photo is shot on iPhone 17 Pro', 'shot on - снято на'],
      ['I declined the call', 'decline - отклонить'],
      ['I do have a spare charger', 'spare - запасной'],
      ['The meeting was called off', 'call off - отменить'],
      ['She came up with a brilliant idea', 'come up with - придумать'],
      ['We got cut off in the middle of the call', 'get cut off - прерваться (о звонке)'],
      ['He turned down the job offer', 'turn down - отказаться'],
      ['Let me sleep on it', 'sleep on it - обдумать до завтра'],
      ['The price went up again', 'go up - расти'],
      ['Could you fill in this form?', 'fill in - заполнить'],
      ['I bumped into an old friend', 'bump into - случайно встретить'],
      ['The rumour turned out to be true', 'turn out - оказаться'],
      ['Hold on a second', 'hold on - подождать'],
      ['She takes after her mother', 'take after - быть похожим'],
      ['I am fed up with excuses', 'fed up with - сыт по горло'],
    ];

    var i = 0;
    Flashcard mk(Deck d, List<String> fb, {required bool fresh}) {
      final created = now.subtract(Duration(days: fresh ? 1 : 30 + rnd.nextInt(60), minutes: i++));
      final c = Flashcard(id: 'seed$i-$tag', deckId: d.id, front: fb[0], back: fb[1], created: created);
      if (!fresh) {
        c.state = CardState.review;
        c.interval = [3, 7, 14, 21, 45, 60, 120, 180, 270, 330][rnd.nextInt(10)];
        c.reps = 3 + rnd.nextInt(6);
        c.ease = 2.3 + rnd.nextDouble() * 0.5;
        // A handful are due today, the rest spread into the future.
        c.due = rnd.nextInt(4) == 0
            ? now.subtract(Duration(hours: 1 + rnd.nextInt(30)))
            : now.add(Duration(days: 1 + rnd.nextInt(c.interval)));
      }
      return c;
    }

    for (final fb in englishCards) {
      cards.add(mk(english, fb, fresh: false));
    }
    for (var k = 0; k < olympiadCards.length; k++) {
      cards.add(mk(olympiad, olympiadCards[k], fresh: k < 10));
    }

    // Synthetic review history for the last ~80 days so Insights isn't empty.
    final reviewIds = cards.where((c) => c.state == CardState.review).map((c) => c.id).toList();
    for (var d = 80; d >= 2; d--) {
      if (rnd.nextDouble() < 0.72) continue; // study on roughly 1 day in 4
      final day = dayOnly(now).subtract(Duration(days: d));
      final count = 5 + rnd.nextInt(30);
      final retention = 0.72 + rnd.nextDouble() * 0.27;
      for (var k = 0; k < count; k++) {
        logs.add(ReviewLog(
          cardId: reviewIds[rnd.nextInt(reviewIds.length)],
          time: day.add(Duration(hours: 9 + rnd.nextInt(12), minutes: rnd.nextInt(60))),
          grade: rnd.nextDouble() < retention ? 3 : 1,
          wasReview: true,
        ));
      }
    }
    logs.sort((a, b) => a.time.compareTo(b.time));
  }
}
