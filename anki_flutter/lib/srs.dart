import 'dart:math';

import 'models.dart';

/// Scheduler presets shown in Profile → Spaced repetition.
enum SrsPreset { standard, aggressive, relaxed, custom }

class SrsParams {
  const SrsParams({
    this.retention = 0.9,
    this.maxIntervalDays = 365,
    this.fuzz = true,
    this.shortTerm = true,
  });

  /// Desired probability of recalling a card when it comes due (0.7–0.97).
  final double retention;
  final int maxIntervalDays;

  /// Spread intervals by ±5 % so cards added together don't stay clumped.
  final bool fuzz;

  /// Same-day learning steps (1 min → 10 min) for new and forgotten cards.
  final bool shortTerm;

  static const standard = SrsParams();
  static const aggressive = SrsParams(retention: 0.95, maxIntervalDays: 180);
  static const relaxed = SrsParams(retention: 0.85, maxIntervalDays: 730);

  static SrsParams? forPreset(SrsPreset p) => switch (p) {
        SrsPreset.standard => standard,
        SrsPreset.aggressive => aggressive,
        SrsPreset.relaxed => relaxed,
        SrsPreset.custom => null,
      };
}

/// Anki-flavoured SM-2 scheduler.
///
/// New and lapsed cards go through short learning steps (1 min, 10 min);
/// graduated cards get intervals multiplied by their ease factor. The
/// retention target scales intervals the way Anki's interval modifier does:
/// ln(target) / ln(0.9), so 95 % gives shorter and 85 % longer intervals.
class Scheduler {
  Scheduler({this.maxIntervalDays = 36500, double retention = 0.9, this.fuzz = false, this.shortTerm = true})
      : modifier = log(retention) / log(0.9);

  factory Scheduler.fromParams(SrsParams p) =>
      Scheduler(maxIntervalDays: p.maxIntervalDays, retention: p.retention, fuzz: p.fuzz, shortTerm: p.shortTerm);

  static const learningSteps = [Duration(minutes: 1), Duration(minutes: 10)];
  static const graduatingInterval = 1;
  static const easyInterval = 4;
  static const minEase = 1.3;

  final int maxIntervalDays;
  final double modifier;
  final bool fuzz;
  final bool shortTerm;

  /// Applies [grade] (1..4) to [card] in place, relative to [now].
  void answer(Flashcard card, int grade, DateTime now) {
    final p = preview(card, grade, now);
    card
      ..state = p.state
      ..interval = p.interval
      ..ease = p.ease
      ..step = p.step
      ..due = p.due
      ..reps = card.reps + 1
      ..modified = now;
    if (p.wasLapse) card.lapses++;
  }

  /// What would happen to [card] if answered with [grade]; used for button labels.
  SchedulePreview preview(Flashcard card, int grade, DateTime now) {
    var ease = card.ease;
    if (card.state == CardState.review) {
      final ivl = max(1, card.interval);
      switch (grade) {
        case 1:
          ease = max(minEase, ease - 0.2);
          if (!shortTerm) return _review(card, 1, ease, now, lapse: true);
          return SchedulePreview(CardState.learning, 1, ease, 0, now.add(learningSteps.first), wasLapse: true);
        case 2:
          ease = max(minEase, ease - 0.15);
          return _review(card, _next(ivl * 1.2, ivl + 1), ease, now);
        case 3:
          return _review(card, _next(ivl * ease, ivl + 1), ease, now);
        default:
          ease += 0.15;
          return _review(card, _next(ivl * ease * 1.3, ivl + 2), ease, now);
      }
    }

    // New or learning card.
    if (!shortTerm) {
      return switch (grade) {
        1 || 2 || 3 => _review(card, graduatingInterval, ease, now),
        _ => _review(card, easyInterval, ease, now),
      };
    }
    final step = card.state == CardState.newCard ? 0 : card.step;
    switch (grade) {
      case 1:
        return SchedulePreview(CardState.learning, card.interval, ease, 0, now.add(learningSteps.first));
      case 2:
        // Hard repeats the current step with a longer delay: halfway to the next step.
        final cur = learningSteps[min(step, learningSteps.length - 1)];
        final delay = step + 1 < learningSteps.length ? (cur + learningSteps[step + 1]) ~/ 2 : cur * 1.5;
        return SchedulePreview(CardState.learning, card.interval, ease, step, now.add(delay));
      case 3:
        if (step + 1 < learningSteps.length) {
          return SchedulePreview(CardState.learning, card.interval, ease, step + 1, now.add(learningSteps[step + 1]));
        }
        return _review(card, max(graduatingInterval, card.interval), ease, now);
      default:
        return _review(card, max(easyInterval, card.interval), ease, now);
    }
  }

  /// Interval after the retention modifier, never below [atLeast].
  int _next(double raw, int atLeast) => max((raw * modifier).round(), atLeast);

  SchedulePreview _review(Flashcard card, int days, double ease, DateTime now, {bool lapse = false}) {
    var n = min(maxIntervalDays, max(1, days));
    if (fuzz && n >= 3) {
      // Deterministic per card and repetition, so the button label matches the result.
      final spread = max(1, (n * 0.05).round());
      n += Random(card.id.hashCode ^ card.reps).nextInt(spread * 2 + 1) - spread;
      n = min(maxIntervalDays, max(1, n));
    }
    return SchedulePreview(CardState.review, n, ease, 0, dayOnly(now).add(Duration(days: n, hours: 4)), wasLapse: lapse);
  }
}

class SchedulePreview {
  SchedulePreview(this.state, this.interval, this.ease, this.step, this.due, {this.wasLapse = false});
  final CardState state;
  final int interval;
  final double ease;
  final int step;
  final DateTime due;
  final bool wasLapse;
}

/// "1m", "10m", "3d", "2mo", "1.2y" — short label for a due time.
String shortInterval(DateTime from, DateTime to) {
  final d = to.difference(from);
  if (d.inMinutes < 60) return '${max(1, d.inMinutes)}m';
  if (d.inHours < 24) return '${d.inHours}h';
  final days = (d.inHours / 24).round();
  if (days < 30) return '${days}d';
  if (days < 365) return '${(days / 30).round()}mo';
  return '${(days / 365).toStringAsFixed(1)}y';
}

/// "in 2 weeks", "in 6 months", "now" — relative label used in card lists.
String relativeDue(DateTime now, DateTime due) {
  final d = due.difference(now);
  if (d.isNegative || d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return 'in ${d.inMinutes} min';
  if (d.inHours < 24) return 'in ${d.inHours} h';
  final days = (d.inHours / 24).round();
  if (days == 1) return 'tomorrow';
  if (days < 7) return 'in $days days';
  if (days < 30) {
    final w = (days / 7).round();
    return w == 1 ? 'in 1 week' : 'in $w weeks';
  }
  if (days < 365) {
    final m = (days / 30).round();
    return m == 1 ? 'in 1 month' : 'in $m months';
  }
  final y = (days / 365).round();
  return y == 1 ? 'in 1 year' : 'in $y years';
}
