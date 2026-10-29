import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/collocations.dart';

class PhraseSuggestion {
  PhraseSuggestion(this.phrase, {this.translation, this.online = false});
  final String phrase;
  final String? translation;

  /// True when it came from the online source rather than the built-in dictionary.
  final bool online;
}

/// Finds frequent, useful phrases and collocations for a newly added word.
///
/// 1. Built-in offline dictionary ([kCollocations]) with Russian translations.
/// 2. Optional online fallback: the free Datamuse API (no key, CORS-enabled),
///    which returns words that most often follow / precede the given word.
///    Swap [OnlineSuggestionProvider] for any other API (e.g. an LLM endpoint).
class SuggestionService {
  SuggestionService({OnlineSuggestionProvider? online}) : _online = online ?? DatamuseProvider();

  final OnlineSuggestionProvider _online;

  static String lemma(String word) {
    final w = word.toLowerCase().replaceAll(RegExp(r"[^a-z'-]"), '');
    if (kCollocations.containsKey(w)) return w;
    final irr = kIrregular[w];
    if (irr != null) return irr;
    final candidates = <String>[
      if (w.endsWith('ies')) '${w.substring(0, w.length - 3)}y',
      if (w.endsWith('es')) w.substring(0, w.length - 2),
      if (w.endsWith('s')) w.substring(0, w.length - 1),
      if (w.endsWith('ed')) w.substring(0, w.length - 2),
      if (w.endsWith('ed')) w.substring(0, w.length - 1),
      if (w.endsWith('ing')) w.substring(0, w.length - 3),
      if (w.endsWith('ing')) '${w.substring(0, w.length - 3)}e',
      if (w.endsWith('ly')) w.substring(0, w.length - 2),
    ];
    for (final c in candidates) {
      if (kCollocations.containsKey(c)) return c;
    }
    return w;
  }

  /// Picks the word in [text] that suggestions should be about: the text itself
  /// when it is one word, otherwise the content words in order.
  static List<String> keywords(String text) {
    final words = text
        .toLowerCase()
        .replaceAll('’', "'")
        .split(RegExp(r"[^a-z'-]+"))
        .where((w) => w.length > 1)
        .toList();
    if (words.length == 1) return [lemma(words.first)];
    final content = words.where((w) => !kStopWords.contains(w)).map(lemma).toList();
    // Dictionary hits first, longer (rarer) words first.
    content.sort((a, b) {
      final ah = kCollocations.containsKey(a) ? 0 : 1;
      final bh = kCollocations.containsKey(b) ? 0 : 1;
      if (ah != bh) return ah - bh;
      return b.length - a.length;
    });
    return content.toSet().toList();
  }

  List<PhraseSuggestion> offline(String text, {int limit = 8}) {
    final source = text.trim().toLowerCase();
    final out = <PhraseSuggestion>[];
    final seen = <String>{};
    for (final k in keywords(text)) {
      for (final pair in kCollocations[k] ?? const <List<String>>[]) {
        if (pair[0].toLowerCase() == source) continue;
        if (seen.add(pair[0])) out.add(PhraseSuggestion(pair[0], translation: pair[1]));
      }
      if (out.length >= limit) break;
    }
    return out.take(limit).toList();
  }

  /// Offline suggestions first; online ones fill up to [limit] when enabled.
  Future<List<PhraseSuggestion>> suggest(String text, {bool allowOnline = true, int limit = 8}) async {
    final local = offline(text, limit: limit);
    if (!allowOnline || local.length >= 4) return local;
    final keys = keywords(text);
    if (keys.isEmpty) return local;
    try {
      final remote = await _online.fetch(keys.first).timeout(const Duration(seconds: 4));
      final have = local.map((s) => s.phrase).toSet();
      for (final p in remote) {
        if (local.length >= limit) break;
        if (have.add(p)) local.add(PhraseSuggestion(p, online: true));
      }
    } catch (_) {
      // Offline or API down: built-in results are enough.
    }
    return local;
  }
}

abstract class OnlineSuggestionProvider {
  Future<List<String>> fetch(String word);
}

class DatamuseProvider implements OnlineSuggestionProvider {
  static const _skip = {...kStopWords, 'will', 'would', 'can', 'could', 's'};

  Future<List<dynamic>> _get(String query) async {
    final r = await http.get(Uri.parse('https://api.datamuse.com/words?$query&max=12'));
    if (r.statusCode != 200) return const [];
    return jsonDecode(r.body) as List<dynamic>;
  }

  @override
  Future<List<String>> fetch(String word) async {
    final w = Uri.encodeQueryComponent(word);
    final results = await Future.wait([
      _get('rel_jjb=$w'), // adjectives often describing the noun: "tough" decision
      _get('rel_bga=$w'), // words that often follow: decision "making"
      _get('rel_bgb=$w'), // words that often precede: "final" decision
    ]);
    final out = <String>[];
    for (final e in results[0].take(4)) {
      out.add('${e['word']} $word');
    }
    for (final e in results[1]) {
      final next = e['word'] as String;
      if (_skip.contains(next)) continue;
      out.add('$word $next');
      if (out.length >= 7) break;
    }
    for (final e in results[2]) {
      final prev = e['word'] as String;
      if (_skip.contains(prev)) continue;
      out.add('$prev $word');
      if (out.length >= 10) break;
    }
    return out;
  }
}
