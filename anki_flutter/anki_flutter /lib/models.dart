enum CardState { newCard, learning, review }

class Deck {
  Deck({
    required this.id,
    required this.name,
    this.language = 'en-GB',
    this.newPerDay = 20,
    this.color,
    this.icon,
    DateTime? modified,
  }) : modified = modified ?? DateTime.now();

  final String id;
  String name;

  /// BCP-47 language of the card fronts; used for text-to-speech and recognition.
  String language;
  int newPerDay;

  /// Tile color (index into DeckStyle.palette); null = automatic.
  int? color;

  /// Topic icon key (see DeckStyle.icons); null = guessed from the name.
  String? icon;

  /// Last local change; used to merge decks when syncing devices.
  DateTime modified;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'language': language,
        'newPerDay': newPerDay,
        if (color != null) 'color': color,
        if (icon != null) 'icon': icon,
        'modified': modified.toIso8601String(),
      };

  factory Deck.fromJson(Map<String, dynamic> j) => Deck(
        id: j['id'],
        name: j['name'],
        language: j['language'] ?? 'en-GB',
        newPerDay: j['newPerDay'] ?? 20,
        color: j['color'],
        icon: j['icon'],
        modified: j['modified'] == null ? DateTime(2000) : DateTime.parse(j['modified']),
      );
}

class Flashcard {
  Flashcard({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    required this.created,
    DateTime? due,
    this.state = CardState.newCard,
    this.interval = 0,
    this.ease = 2.5,
    this.reps = 0,
    this.lapses = 0,
    this.step = 0,
    this.imageUrl,
    DateTime? modified,
  })  : due = due ?? created,
        modified = modified ?? created;

  final String id;
  String deckId;
  String front;
  String back;
  final DateTime created;
  DateTime due;
  CardState state;

  /// Current interval in days (review cards).
  int interval;
  double ease;
  int reps;
  int lapses;

  /// Index into the learning steps while [state] is learning.
  int step;
  String? imageUrl;

  /// Last local change (edit or review); used to merge cards when syncing devices.
  DateTime modified;

  Map<String, dynamic> toJson() => {
        'id': id,
        'deckId': deckId,
        'front': front,
        'back': back,
        'created': created.toIso8601String(),
        'due': due.toIso8601String(),
        'state': state.index,
        'interval': interval,
        'ease': ease,
        'reps': reps,
        'lapses': lapses,
        'step': step,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'modified': modified.toIso8601String(),
      };

  factory Flashcard.fromJson(Map<String, dynamic> j) => Flashcard(
        id: j['id'],
        deckId: j['deckId'],
        front: j['front'],
        back: j['back'],
        created: DateTime.parse(j['created']),
        due: DateTime.parse(j['due']),
        state: CardState.values[j['state'] ?? 0],
        interval: j['interval'] ?? 0,
        ease: (j['ease'] ?? 2.5).toDouble(),
        reps: j['reps'] ?? 0,
        lapses: j['lapses'] ?? 0,
        step: j['step'] ?? 0,
        imageUrl: j['imageUrl'],
        modified: j['modified'] == null ? null : DateTime.parse(j['modified']),
      );
}

/// One answer given during a study session. Drives Insights.
class ReviewLog {
  ReviewLog(
      {required this.cardId, required this.time, required this.grade, required this.wasReview, this.wasNew = false});

  final String cardId;
  final DateTime time;

  /// 1 = Again, 2 = Hard, 3 = Good, 4 = Easy.
  final int grade;

  /// True when the card was a mature review card (counts toward retention).
  final bool wasReview;

  /// True when this was the card's first answer (counts toward the new-cards limit).
  final bool wasNew;

  Map<String, dynamic> toJson() =>
      {'c': cardId, 't': time.toIso8601String(), 'g': grade, 'r': wasReview, if (wasNew) 'n': true};

  factory ReviewLog.fromJson(Map<String, dynamic> j) => ReviewLog(
      cardId: j['c'], time: DateTime.parse(j['t']), grade: j['g'], wasReview: j['r'] ?? true, wasNew: j['n'] ?? false);

  /// Identity used to de-duplicate logs coming from several devices.
  String get key => '$cardId|${time.toIso8601String()}';
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
