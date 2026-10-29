import 'dart:math';

/// One recognition hypothesis from the speech engine.
class SpeechAlternative {
  SpeechAlternative(this.transcript, this.confidence);
  final String transcript;
  final double confidence;
}

enum WordStatus { correct, close, wrong, missing }

class WordResult {
  WordResult(this.word, this.status, {this.heard});
  final String word;
  final WordStatus status;
  final String? heard;
}

class PronunciationResult {
  PronunciationResult({required this.score, required this.words, required this.heard, required this.confidence});

  /// 0..100
  final int score;
  final List<WordResult> words;
  final String heard;
  final double confidence;

  String get verdict {
    if (score >= 95) return 'Excellent!';
    if (score >= 75) return 'Great job';
    if (score >= 55) return 'Almost there';
    return 'Keep practicing';
  }
}

/// Compares what the recognizer heard with the target phrase.
///
/// Words are aligned with a weighted edit distance where substituting one word
/// for another costs (1 − character similarity). Each target word is then
/// graded correct / close / wrong / missing. The best of the recognizer's
/// alternatives is used, since it often normalises spelling differently.
class PronunciationChecker {
  static final _contractions = {
    "i'm": 'i am',
    "you're": 'you are',
    "we're": 'we are',
    "they're": 'they are',
    "it's": 'it is',
    "that's": 'that is',
    "don't": 'do not',
    "doesn't": 'does not',
    "didn't": 'did not',
    "can't": 'cannot',
    "won't": 'will not',
    "isn't": 'is not',
    "aren't": 'are not',
    "i'll": 'i will',
    "i've": 'i have',
    "let's": 'let us',
  };

  static List<String> tokenize(String s) {
    var t = s.toLowerCase().replaceAll('’', "'").replaceAll(RegExp(r"[^a-zа-яё0-9'\s-]"), ' ');
    t = t.replaceAll('-', ' ');
    final out = <String>[];
    for (final w in t.split(RegExp(r'\s+'))) {
      if (w.isEmpty) continue;
      final exp = _contractions[w];
      if (exp != null) {
        out.addAll(exp.split(' '));
      } else {
        out.add(w.replaceAll("'", ''));
      }
    }
    return out;
  }

  /// Display words of the target, keeping original casing/punctuation.
  static List<String> displayWords(String s) =>
      s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  static double charSimilarity(String a, String b) {
    if (a == b) return 1;
    if (a.isEmpty || b.isEmpty) return 0;
    final d = _levenshtein(a, b);
    return 1 - d / max(a.length, b.length);
  }

  static int _levenshtein(String a, String b) {
    final prev = List<int>.generate(b.length + 1, (i) => i);
    final cur = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        cur[j] = min(min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
      }
      prev.setAll(0, cur);
    }
    return prev[b.length];
  }

  static PronunciationResult check(String target, List<SpeechAlternative> alternatives) {
    PronunciationResult? best;
    for (final alt in alternatives) {
      final r = _score(target, alt);
      if (best == null || r.score > best.score) best = r;
    }
    return best ?? _score(target, SpeechAlternative('', 0));
  }

  static PronunciationResult _score(String target, SpeechAlternative alt) {
    final display = displayWords(target);
    // Map each display word to its normalized token(s); scoring is per display word.
    final targetTokens = <String>[];
    final owner = <int>[];
    for (var i = 0; i < display.length; i++) {
      for (final t in tokenize(display[i])) {
        targetTokens.add(t);
        owner.add(i);
      }
    }
    final heard = tokenize(alt.transcript);
    final n = targetTokens.length, m = heard.length;

    // DP alignment.
    final dp = List.generate(n + 1, (_) => List<double>.filled(m + 1, 0));
    for (var i = 1; i <= n; i++) {
      dp[i][0] = i.toDouble();
    }
    for (var j = 1; j <= m; j++) {
      dp[0][j] = j * 0.5; // extra words are cheaper than missing ones
    }
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final sub = dp[i - 1][j - 1] + (1 - charSimilarity(targetTokens[i - 1], heard[j - 1]));
        dp[i][j] = min(sub, min(dp[i - 1][j] + 1, dp[i][j - 1] + 0.5));
      }
    }
    // Backtrack.
    final tokenScore = List<double>.filled(n, 0);
    final tokenHeard = List<String?>.filled(n, null);
    var i = n, j = m;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        final sim = charSimilarity(targetTokens[i - 1], heard[j - 1]);
        if ((dp[i][j] - (dp[i - 1][j - 1] + 1 - sim)).abs() < 1e-9) {
          tokenScore[i - 1] = sim;
          tokenHeard[i - 1] = heard[j - 1];
          i--;
          j--;
          continue;
        }
      }
      if (i > 0 && (j == 0 || (dp[i][j] - (dp[i - 1][j] + 1)).abs() < 1e-9)) {
        tokenScore[i - 1] = 0;
        i--;
      } else {
        j--;
      }
    }

    // Aggregate per display word.
    final words = <WordResult>[];
    var total = 0.0;
    for (var w = 0; w < display.length; w++) {
      final idx = [for (var k = 0; k < n; k++) if (owner[k] == w) k];
      if (idx.isEmpty) {
        words.add(WordResult(display[w], WordStatus.correct));
        continue;
      }
      final s = idx.map((k) => tokenScore[k]).reduce((a, b) => a + b) / idx.length;
      final heardWord = idx.map((k) => tokenHeard[k]).whereType<String>().join(' ');
      total += s * idx.length;
      final status = heardWord.isEmpty
          ? WordStatus.missing
          : s >= 0.99
              ? WordStatus.correct
              : s >= 0.6
                  ? WordStatus.close
                  : WordStatus.wrong;
      words.add(WordResult(display[w], status, heard: heardWord.isEmpty ? null : heardWord));
    }
    final accuracy = n == 0 ? 0.0 : total / n;
    final extra = max(0, m - n);
    var score = accuracy * 100 - extra * 4;
    // Blend in the recognizer's confidence a little (it's 0 on some browsers).
    if (alt.confidence > 0) score = score * 0.9 + alt.confidence * 10;
    return PronunciationResult(
      score: score.clamp(0, 100).round(),
      words: words,
      heard: alt.transcript,
      confidence: alt.confidence,
    );
  }
}
