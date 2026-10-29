import 'package:flutter/material.dart';

import 'models.dart';

/// Colors and topic icons for deck tiles (Library and Queue).
class DeckStyle {
  /// Tile gradients, top → bottom. Index 0 is the original grey.
  static const palette = <(String, Color, Color)>[
    ('Graphite', Color(0xFF9A9A9C), Color(0xFF7C7C7E)),
    ('Ocean', Color(0xFF5B8DEF), Color(0xFF3A63C9)),
    ('Indigo', Color(0xFF7C83F2), Color(0xFF5257CC)),
    ('Violet', Color(0xFF9D7BEA), Color(0xFF6F4FC4)),
    ('Grape', Color(0xFFB66FD8), Color(0xFF8A47AE)),
    ('Pink', Color(0xFFE77BB8), Color(0xFFBF4E90)),
    ('Rose', Color(0xFFEE7A8A), Color(0xFFC94D62)),
    ('Coral', Color(0xFFF2896C), Color(0xFFD05F43)),
    ('Orange', Color(0xFFF2A65A), Color(0xFFD27E2F)),
    ('Amber', Color(0xFFE9BE4F), Color(0xFFC0952A)),
    ('Lime', Color(0xFFA9CC5A), Color(0xFF7DA233)),
    ('Green', Color(0xFF5FC48A), Color(0xFF379A63)),
    ('Teal', Color(0xFF4DBDB0), Color(0xFF2D9387)),
    ('Cyan', Color(0xFF4FB8D8), Color(0xFF2B8EB0)),
    ('Slate', Color(0xFF7D8FA8), Color(0xFF56677F)),
    ('Cocoa', Color(0xFFB08A72), Color(0xFF86624C)),
  ];

  /// Topic icons: key, icon, label, words in deck names that suggest it.
  static const icons = <(String, IconData, String, List<String>)>[
    ('work', Icons.work_outline_rounded, 'Work', ['work', 'job', 'office', 'business', 'career', 'meeting', 'corporate']),
    ('money', Icons.payments_outlined, 'Money', ['money', 'financ', 'bank', 'econom', 'invest', 'tax']),
    ('travel', Icons.flight_takeoff_rounded, 'Travel', ['travel', 'trip', 'airport', 'flight', 'holiday', 'vacation', 'hotel']),
    ('food', Icons.restaurant_rounded, 'Food', ['food', 'cook', 'kitchen', 'restaurant', 'meal', 'eat', 'drink']),
    ('health', Icons.medical_services_outlined, 'Health', ['health', 'medic', 'doctor', 'hospital', 'disease', 'body']),
    ('tech', Icons.computer_rounded, 'Tech', ['it', 'tech', 'computer', 'program', 'coding', 'code', 'software', 'internet']),
    ('science', Icons.science_outlined, 'Science', ['science', 'chemi', 'physic', 'biolog', 'lab']),
    ('math', Icons.calculate_outlined, 'Math', ['math', 'number', 'algebra', 'geometr']),
    ('school', Icons.school_outlined, 'Study', ['school', 'study', 'educat', 'universit', 'exam', 'ielts', 'toefl', 'sat', 'lesson']),
    ('olympiad', Icons.emoji_events_outlined, 'Contest', ['olymp', 'contest', 'compet', 'champion']),
    ('sport', Icons.sports_soccer_rounded, 'Sport', ['sport', 'football', 'gym', 'fitness', 'game']),
    ('music', Icons.music_note_rounded, 'Music', ['music', 'song', 'lyric']),
    ('movies', Icons.movie_outlined, 'Movies', ['movie', 'film', 'series', 'tv', 'netflix', 'cinema']),
    ('books', Icons.menu_book_rounded, 'Books', ['book', 'read', 'literat', 'novel', 'story']),
    ('nature', Icons.eco_outlined, 'Nature', ['nature', 'environment', 'ecolog', 'plant', 'garden']),
    ('animals', Icons.pets_rounded, 'Animals', ['animal', 'pet', 'dog', 'cat', 'zoo']),
    ('weather', Icons.wb_sunny_outlined, 'Weather', ['weather', 'season', 'climate']),
    ('home', Icons.home_outlined, 'Home', ['home', 'house', 'daily', 'everyday', 'routine']),
    ('people', Icons.groups_outlined, 'People', ['people', 'family', 'friend', 'relationship', 'social']),
    ('love', Icons.favorite_border_rounded, 'Love', ['love', 'dating', 'romance']),
    ('emotions', Icons.mood_rounded, 'Feelings', ['emotion', 'feeling', 'mood', 'character', 'personalit']),
    ('talk', Icons.forum_outlined, 'Speaking', ['conversation', 'speaking', 'talk', 'phrase', 'idiom', 'slang', 'chat', 'collocation']),
    ('grammar', Icons.spellcheck_rounded, 'Grammar', ['grammar', 'tense', 'verb', 'condition', 'rule', 'article', 'phrasal']),
    ('law', Icons.gavel_rounded, 'Law', ['law', 'legal', 'court', 'crime']),
    ('news', Icons.newspaper_rounded, 'News', ['news', 'media', 'politic', 'society']),
    ('shopping', Icons.shopping_bag_outlined, 'Shopping', ['shop', 'clothes', 'fashion', 'buy', 'store']),
    ('transport', Icons.directions_car_outlined, 'Transport', ['car', 'transport', 'drive', 'traffic', 'city']),
    ('art', Icons.palette_outlined, 'Art', ['art', 'design', 'paint', 'colou', 'color', 'photo']),
    ('history', Icons.account_balance_outlined, 'History', ['history', 'culture', 'museum', 'religion']),
    ('psychology', Icons.psychology_outlined, 'Mind', ['psycholog', 'mind', 'brain', 'philosoph']),
    ('time', Icons.schedule_rounded, 'Time', ['time', 'date', 'calendar']),
    ('world', Icons.public_rounded, 'World', ['geograph', 'country', 'countries', 'world', 'map']),
    ('phone', Icons.smartphone_rounded, 'Phone', ['phone', 'gadget', 'app']),
    ('idea', Icons.lightbulb_outline_rounded, 'Ideas', ['idea', 'creativ', 'insight']),
    ('language', Icons.translate_rounded, 'Language', ['english', 'language', 'word', 'vocab', 'dictionar', 'russian', 'german', 'french', 'spanish']),
    ('star', Icons.star_outline_rounded, 'Favourite', ['favourite', 'favorite', 'important', 'top', 'best']),
    ('flag', Icons.flag_outlined, 'Goals', ['goal', 'plan', 'target']),
    ('deck', Icons.inventory_2_rounded, 'Deck', []),
  ];

  /// Picks a topic icon from the deck name ("Work vocabulary" → work).
  static String guessIcon(String name) {
    final words = name.toLowerCase().split(RegExp(r'[^a-zа-яё0-9]+')).where((w) => w.isNotEmpty).toList();
    for (final (key, _, _, keywords) in icons) {
      for (final k in keywords) {
        if (words.any((w) => k.length < 4 ? w == k : w.startsWith(k))) return key;
      }
    }
    return 'deck';
  }

  /// Different decks get different colors even before the user picks one.
  static int autoColor(String id) => 1 + (id.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff) % (palette.length - 1));

  static int colorOf(Deck d) => (d.color ?? autoColor(d.id)).clamp(0, palette.length - 1);

  static LinearGradient gradientOf(Deck d) => gradient(colorOf(d));

  static LinearGradient gradient(int i) {
    final (_, a, b) = palette[i.clamp(0, palette.length - 1)];
    return LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [a, b]);
  }

  static String iconKeyOf(Deck d) => d.icon ?? guessIcon(d.name);

  static IconData iconOf(Deck d) => iconFor(iconKeyOf(d));

  static IconData iconFor(String key) =>
      icons.firstWhere((e) => e.$1 == key, orElse: () => icons.last).$2;
}
