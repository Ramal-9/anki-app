import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/collocations.dart';
import 'suggestions.dart';

enum CardStyle { auto, wordToMeaning, cloze }

class GeneratedCard {
  GeneratedCard(this.front, this.back, {this.kind = 'word', this.term});
  String front;
  String back;

  /// 'definition', 'phrase' or 'word'.
  final String kind;

  /// The word or phrase the card teaches (used for translation).
  final String? term;
  bool selected = true;
}

/// Turns pasted notes / an article into flashcards, fully offline:
///
/// 1. Glossary lines ("term - meaning", "term: meaning") become cards as they are.
/// 2. Useful collocations from the built-in dictionary found in the text
///    become phrase cards with a Russian translation and the example sentence.
/// 3. The rarest content words become vocabulary cards with their sentence.
class CardGenerator {
  static const maxChars = 5000;

  static final _definition = RegExp(r'^\s*[-•*\d.)]*\s*(.{1,60}?)(?:\s+(?:-|–|—|=)|\s*:)\s+(.{2,})$');
  static final _definitionTab = RegExp(r'^\s*(.{1,60}?)\t+(.{2,})$');

  static List<GeneratedCard> generate(String text, {int count = 15, CardStyle style = CardStyle.auto}) {
    text = text.replaceAll('\r', '').replaceAll('’', "'");
    if (text.length > maxChars) text = text.substring(0, maxChars);
    final out = <GeneratedCard>[];
    final used = <String>{};

    // 1. Glossary lines.
    final prose = StringBuffer();
    for (final line in const LineSplitter().convert(text)) {
      final m = _definitionTab.firstMatch(line) ?? _definition.firstMatch(line);
      if (m != null && m.group(1)!.trim().split(RegExp(r'\s+')).length <= 6) {
        final term = m.group(1)!.trim();
        if (used.add(term.toLowerCase())) {
          out.add(GeneratedCard(term, m.group(2)!.trim(), kind: 'definition', term: term));
        }
      } else {
        prose.writeln(line);
      }
    }

    final sentences = splitSentences(prose.toString());

    // 2. Collocations from the dictionary.
    final phrases = <(String, String, String)>[]; // phrase, translation, sentence
    for (final s in sentences) {
      final lower = s.toLowerCase();
      for (final entry in kCollocations.entries) {
        if (!lower.contains(entry.key.substring(0, entry.key.length > 3 ? 3 : entry.key.length))) continue;
        for (final pair in entry.value) {
          if (used.contains(pair[0])) continue;
          final m = phrasePattern(pair[0]).firstMatch(s);
          if (m != null) {
            used.add(pair[0]);
            for (final w in pair[0].split(' ')) {
              used.add(SuggestionService.lemma(w));
            }
            phrases.add((pair[0], pair[1], s));
          }
        }
      }
    }
    for (final (phrase, translation, sentence) in phrases) {
      out.add(_card(style, phrase, translation, sentence, kind: 'phrase'));
    }

    // 3. Vocabulary: rare-looking content words, first sentence they appear in.
    final seen = <String, (String word, String sentence, int hits)>{};
    for (final s in sentences) {
      for (final m in RegExp(r"[A-Za-z][A-Za-z'-]+").allMatches(s)) {
        final w = m.group(0)!;
        final lw = w.toLowerCase();
        if (lw.length < 5 || kStopWords.contains(lw) || _common.contains(lw)) continue;
        // Skip names in the middle of a sentence.
        if (w[0] != lw[0] && m.start > 0) continue;
        final lemma = SuggestionService.lemma(lw);
        if (used.contains(lemma) || _common.contains(lemma)) continue;
        final prev = seen[lemma];
        seen[lemma] = prev == null ? (lw, s, 1) : (prev.$1, prev.$2, prev.$3 + 1);
      }
    }
    final vocab = seen.entries.toList()
      ..sort((a, b) {
        // Longer words are usually rarer; repeated ones matter more.
        final sa = a.value.$1.length + a.value.$3 * 2;
        final sb = b.value.$1.length + b.value.$3 * 2;
        return sb.compareTo(sa);
      });
    for (final e in vocab) {
      if (out.length >= count) break;
      out.add(_card(style, e.value.$1, '', e.value.$2, kind: 'word'));
    }
    return out.take(count).toList();
  }

  static GeneratedCard _card(CardStyle style, String term, String translation, String sentence, {required String kind}) {
    final example = sentence.trim();
    if (style == CardStyle.cloze) {
      final blanked = example.replaceFirst(phrasePattern(term), '_____');
      final back = translation.isEmpty ? term : '$term - $translation';
      return GeneratedCard(blanked == example ? '$example\n(_____ = ?)' : blanked, back, kind: kind, term: term);
    }
    final back = [if (translation.isNotEmpty) translation, if (example.isNotEmpty) '“$example”'].join('\n\n');
    return GeneratedCard(term, back, kind: kind, term: term);
  }

  static List<String> splitSentences(String text) => RegExp(r'[^.!?…]+[.!?…]*')
      .allMatches(text.replaceAll(RegExp(r'\s+'), ' '))
      .map((m) => m.group(0)!.trim())
      .where((s) => s.split(' ').length >= 3)
      .toList();

  /// Regex matching [phrase] with the first word inflected (make → made, makes, making)
  /// and possessives swapped (your → my/his/her/...).
  static RegExp phrasePattern(String phrase) {
    final words = phrase.toLowerCase().split(' ');
    const possessive = '(?:your|my|his|her|their|our|its|one\'s)';
    final parts = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (const {'your', 'my', 'his', 'her', 'their', 'our'}.contains(w)) {
        parts.add(possessive);
      } else if (i == 0) {
        final forms = {w, '${w}s', '${w}es', '${w}ed', '${w}d', '${w}ing'};
        if (w.endsWith('e')) forms.add('${w.substring(0, w.length - 1)}ing');
        if (w.endsWith('y')) forms.addAll(['${w.substring(0, w.length - 1)}ies', '${w.substring(0, w.length - 1)}ied']);
        if (RegExp(r'[^aeiou][aeiou][bdgmnprt]$').hasMatch(w)) {
          final last = w[w.length - 1];
          forms.addAll(['$w${last}ed', '$w${last}ing']);
        }
        kIrregular.forEach((form, base) {
          if (base == w) forms.add(form);
        });
        parts.add('(?:${forms.map(RegExp.escape).join('|')})');
      } else {
        parts.add(RegExp.escape(w));
      }
    }
    return RegExp('\\b${parts.join(r'\s+')}\\b', caseSensitive: false);
  }

  /// Fills empty backs with a Russian translation (MyMemory, free, online only).
  static Future<void> translateMissing(List<GeneratedCard> cards) async {
    await Future.wait(cards.where((c) => c.kind == 'word' && c.term != null).map((c) async {
      try {
        final uri = Uri.https('api.mymemory.translated.net', '/get', {'q': c.term!, 'langpair': 'en|ru'});
        final r = await http.get(uri).timeout(const Duration(seconds: 6));
        final t = (jsonDecode(r.body)['responseData']?['translatedText'] as String?)?.trim();
        if (t == null || t.isEmpty || t.toLowerCase() == c.term!.toLowerCase() || t.contains('MYMEMORY')) return;
        if (c.back.startsWith('“')) {
          c.back = '$t\n\n${c.back}';
        } else if (c.back.contains(' - ')) {
          c.back = '${c.back.split(' - ').first} - $t';
        } else {
          c.back = '${c.back} - $t';
        }
      } catch (_) {}
    }));
  }

  // Frequent words that are not worth a card.
  static const _common = {
    'about', 'above', 'after', 'again', 'against', 'almost', 'along', 'already', 'also', 'although', 'always',
    'among', 'another', 'answer', 'anyone', 'anything', 'around', 'asked', 'away', 'back', 'became', 'because',
    'become', 'before', 'began', 'begin', 'behind', 'being', 'believe', 'below', 'best', 'better', 'between',
    'big', 'black', 'body', 'book', 'both', 'bring', 'brought', 'build', 'business', 'called', 'came', 'cannot',
    'change', 'child', 'children', 'city', 'close', 'come', 'company', 'could', 'country', 'course', 'during',
    'early', 'either', 'else', 'enough', 'even', 'ever', 'every', 'everyone', 'everything', 'example', 'family',
    'father', 'feel', 'field', 'find', 'first', 'follow', 'found', 'friend', 'friends', 'from', 'front', 'gave',
    'general', 'give', 'given', 'going', 'good', 'great', 'group', 'hand', 'happen', 'happened', 'having',
    'head', 'heard', 'help', 'here', 'high', 'himself', 'home', 'house', 'however', 'human', 'important',
    'inside', 'instead', 'into', 'itself', 'just', 'keep', 'kind', 'knew', 'know', 'known', 'large', 'last',
    'later', 'learn', 'least', 'leave', 'left', 'less', 'life', 'light', 'like', 'line', 'little', 'live',
    'long', 'look', 'looked', 'made', 'make', 'many', 'maybe', 'means', 'might', 'money', 'more', 'morning',
    'most', 'mother', 'move', 'much', 'must', 'myself', 'name', 'need', 'never', 'next', 'night', 'nothing',
    'number', 'often', 'once', 'only', 'open', 'order', 'other', 'others', 'over', 'own', 'part', 'people',
    'person', 'place', 'play', 'point', 'possible', 'power', 'probably', 'problem', 'public', 'put', 'question',
    'quite', 'rather', 'really', 'reason', 'right', 'room', 'said', 'same', 'saw', 'school', 'second', 'seem',
    'seemed', 'seen', 'several', 'should', 'show', 'side', 'since', 'small', 'something', 'sometimes', 'soon',
    'start', 'started', 'state', 'still', 'story', 'student', 'study', 'such', 'sure', 'system', 'take',
    'taken', 'talk', 'tell', 'than', 'thank', 'them', 'then', 'there', 'these', 'thing', 'things', 'think',
    'those', 'though', 'thought', 'three', 'through', 'time', 'times', 'today', 'together', 'told', 'took',
    'toward', 'turn', 'under', 'until', 'upon', 'used', 'using', 'usually', 'very', 'want', 'wanted', 'water',
    'week', 'well', 'went', 'were', 'what', 'when', 'where', 'whether', 'which', 'while', 'white', 'whole',
    'whose', 'without', 'woman', 'women', 'word', 'words', 'work', 'world', 'would', 'write', 'year', 'years',
    'young', 'yourself', 'there\'s', 'that\'s', 'didn\'t', 'doesn\'t', 'wasn\'t', 'aren\'t', 'couldn\'t',
    'wouldn\'t', 'shouldn\'t', 'haven\'t', 'isn\'t', 'can\'t', 'won\'t', 'don\'t', 'i\'m', 'you\'re',
    'they\'re', 'we\'re', 'actually', 'different', 'anyway', 'within', 'everybody', 'somebody',
  };
}
