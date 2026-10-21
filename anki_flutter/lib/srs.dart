import 'dart:math';

import 'models.dart';

/// Anki-flavoured SM-2 scheduler.
///
/// New and lapsed cards go through short learning steps (1 min, 10 min);
/// graduated cards get intervals multiplied by their ease factor.
class Scheduler {
  Scheduler({this.maxIntervalDays = 36500});

  static const learningSteps = [Duration(minutes: 1), Duration(minutes: 10)];
  static const graduatingInterval = 1;
  static const easyInterval = 4;
  static const minEase = 1.3;

  final int maxIntervalDays;

  /// Applies [grade] (1..4) to [card] in place, relative to [now].
  void answer(Flashcard card, int grade, DateTime now) {
    final p = preview(card, grade, now);
    card
      ..state = p.state
      ..interval = p.interval
      ..ease = p.ease
      ..step = p.step
      ..due = p.due
      ..reps = card.reps + 1;
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
          return SchedulePreview(CardState.learning, 1, ease, 0, now.add(learningSteps.first), wasLapse: true);
        case 2:
          ease = max(minEase, ease - 0.15);
          final n = _clamp((ivl * 1.2).round(), ivl + 1);
          return SchedulePreview(CardState.review, n, ease, 0, _days(now, n));
        case 3:
          final n = _clamp((ivl * ease).round(), ivl + 1);
          return SchedulePreview(CardState.review, n, ease, 0, _days(now, n));
        default:
          ease += 0.15;
          final n = _clamp((ivl * ease * 1.3).round(), ivl + 2);
          return SchedulePreview(CardState.review, n, ease, 0, _days(now, n));
      }
    }

    // New or learning card.
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
        final n = max(graduatingInterval, card.interval);
        return SchedulePreview(CardState.review, n, ease, 0, _days(now, n));
      default:
        final n = max(easyInterval, card.interval);
        return SchedulePreview(CardState.review, n, ease, 0, _days(now, n));
    }
  }

  int _clamp(int value, int atLeast) => min(maxIntervalDays, max(value, atLeast));

  DateTime _days(DateTime now, int days) => dayOnly(now).add(Duration(days: days, hours: 4));
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
