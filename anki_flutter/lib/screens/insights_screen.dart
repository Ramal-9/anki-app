import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

const _monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 130),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 76, 20, 16),
            child: Text('Insights', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ),
          LayoutBuilder(builder: (context, c) {
            final cards = <Widget>[
              _RetentionCard(store: store),
              _ActivityCard(store: store),
              _ForecastCard(store: store),
              _TotalsCard(store: store),
            ];
            // Two columns on wide windows (Mac), one on phones.
            if (c.maxWidth < 860) {
              return Column(children: [
                for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 22), child: card),
              ]);
            }
            final half = (c.maxWidth - 20) / 2;
            return Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Wrap(runSpacing: 22, children: [
                for (final card in cards) SizedBox(width: half, child: card),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.icon, required this.title, required this.child, this.trailing});
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(32)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AppColors.textSecondary, size: 24),
          const SizedBox(width: 12),
          Text(title.toUpperCase(),
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

// ------------------------------------------------------------ retention

class _RetentionCard extends StatefulWidget {
  const _RetentionCard({required this.store});
  final AppStore store;

  @override
  State<_RetentionCard> createState() => _RetentionCardState();
}

class _RetentionCardState extends State<_RetentionCard> {
  int _range = 1; // 0=7D 1=30D 2=90D 3=All
  static const _labels = ['7D', '30D', '90D', 'All'];

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final today = dayOnly(DateTime.now());
    final reviews = store.logs.where((l) => l.wasReview).toList();
    final days = switch (_range) {
      0 => 7,
      1 => 30,
      2 => 90,
      _ => reviews.isEmpty ? 30 : max(7, today.difference(dayOnly(reviews.first.time)).inDays + 1),
    };
    final start = today.subtract(Duration(days: days - 1));

    // Per-day retention points in range.
    final byDay = <DateTime, List<int>>{};
    for (final l in reviews) {
      final d = dayOnly(l.time);
      if (d.isBefore(start)) continue;
      (byDay[d] ??= [0, 0])
        ..[0] += l.grade > 1 ? 1 : 0
        ..[1] += 1;
    }
    final keys = byDay.keys.toList()..sort();
    var points = [for (final k in keys) (k, byDay[k]![0] / byDay[k]![1])];
    // Bucket into at most 7 points so the chart stays readable.
    if (points.length > 7) {
      final size = (points.length / 7).ceil();
      final merged = <(DateTime, double)>[];
      for (var i = 0; i < points.length; i += size) {
        final chunk = points.sublist(i, min(points.length, i + size));
        merged.add((chunk.last.$1, chunk.map((e) => e.$2).reduce((a, b) => a + b) / chunk.length));
      }
      points = merged;
    }

    double? rate(DateTime from, DateTime to) {
      var ok = 0, all = 0;
      for (final l in reviews) {
        if (l.time.isBefore(from) || !l.time.isBefore(to)) continue;
        all++;
        if (l.grade > 1) ok++;
      }
      return all == 0 ? null : ok / all;
    }

    final current = rate(start, today.add(const Duration(days: 1)));
    final previous = rate(start.subtract(Duration(days: days)), start);
    final delta = current != null && previous != null ? ((current - previous) * 100).round() : null;

    return _CardShell(
      icon: Icons.insights_rounded,
      title: 'Retention trend',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(current == null ? '— %' : '${(current * 100).round()} %',
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, height: 1)),
          const SizedBox(width: 14),
          if (delta != null) ...[
            Icon(delta >= 0 ? Icons.north_east_rounded : Icons.south_east_rounded,
                color: delta >= 0 ? AppColors.reviewGreen : AppColors.newRed, size: 22),
            Text('${delta.abs()} %',
                style: TextStyle(
                    color: delta >= 0 ? AppColors.reviewGreen : AppColors.newRed,
                    fontSize: 20,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 10),
            Text(_range == 0 ? 'vs last week' : 'vs last period',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
          ],
        ]),
        const SizedBox(height: 18),
        SizedBox(
          height: 240,
          child: points.isEmpty
              ? Center(child: Text('Review some cards to see your retention', style: TextStyle(color: AppColors.textSecondary)))
              : CustomPaint(
                  size: Size.infinite,
                  painter: _RetentionPainter(points, goal: store.srs.retention, dark: AppColors.dark),
                ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Container(width: 22, height: 2, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Text('On track · 70 %', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(width: 22),
          Container(width: 22, height: 3, color: AppColors.goalTeal),
          const SizedBox(width: 8),
          Text('Goal · ${(store.srs.retention * 100).round()} %',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        ]),
        const SizedBox(height: 18),
        Container(
          height: 50,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(25)),
          child: Row(children: [
            for (var i = 0; i < _labels.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _range = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == _range ? (AppColors.dark ? const Color(0xFF6A6A6E) : Colors.white) : null,
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: Text(_labels[i], style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _RetentionPainter extends CustomPainter {
  _RetentionPainter(this.points, {required this.goal, required this.dark});
  final List<(DateTime, double)> points;
  final double goal;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 54.0, bottom = 30.0, top = 8.0, right = 6.0;
    final w = size.width - left - right;
    final h = size.height - bottom - top;
    final labelColor = dark ? const Color(0xFFB0B0B5) : const Color(0xFF6C6C72);
    final gridPaint = Paint()
      ..color = dark ? Colors.white10 : Colors.black12
      ..strokeWidth = 1;

    double y(double v) => top + h * (1 - v);
    double x(int i) => points.length == 1 ? left + w / 2 : left + w * i / (points.length - 1);

    // Grid + y labels.
    for (final v in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), gridPaint);
      _text(canvas, '${(v * 100).round()} %', Offset(0, y(v) - 9), labelColor, 15);
    }
    for (var i = 0; i < points.length; i++) {
      canvas.drawLine(Offset(x(i), top), Offset(x(i), top + h), gridPaint);
    }

    // Smooth line path.
    final line = Path()..moveTo(x(0), y(points[0].$2));
    for (var i = 1; i < points.length; i++) {
      final x0 = x(i - 1), y0 = y(points[i - 1].$2), x1 = x(i), y1 = y(points[i].$2);
      final cx = (x0 + x1) / 2;
      line.cubicTo(cx, y0, cx, y1, x1, y1);
    }
    final area = Path.from(line)
      ..lineTo(x(points.length - 1), top + h)
      ..lineTo(x(0), top + h)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [const Color(0xFF6F7BC8).withValues(alpha: 0.75), const Color(0xFF6F7BC8).withValues(alpha: 0.12)],
        ).createShader(Rect.fromLTWH(left, top, w, h)),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.accentStrong
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Reference lines.
    _dashed(canvas, y(goal), left, left + w, AppColors.goalTeal, 10, 6, 3);
    _dashed(canvas, y(0.7), left, left + w, labelColor.withValues(alpha: 0.7), 5, 5, 2.5);

    // Dots + x labels (a label is skipped when it would overlap the previous one).
    var lastLabelEnd = -1.0;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(x(i), y(points[i].$2)), 5, Paint()..color = AppColors.accentStrong);
      final d = points[i].$1;
      final label = '${_monthsShort[d.month - 1]} ${d.day}';
      final tp = _layout(label, labelColor, 13.5);
      final lx = (x(i) - tp.width / 2).clamp(0.0, size.width - tp.width);
      if (lx < lastLabelEnd + 6) continue;
      lastLabelEnd = lx + tp.width;
      tp.paint(canvas, Offset(lx, top + h + 9));
    }
  }

  void _dashed(Canvas c, double y, double x0, double x1, Color color, double dash, double gap, double width) {
    final p = Paint()
      ..color = color
      ..strokeWidth = width;
    for (var x = x0; x < x1; x += dash + gap) {
      c.drawLine(Offset(x, y), Offset(min(x + dash, x1), y), p);
    }
  }

  TextPainter _layout(String s, Color color, double size) =>
      TextPainter(text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size)), textDirection: TextDirection.ltr)
        ..layout();

  void _text(Canvas c, String s, Offset o, Color color, double size) => _layout(s, color, size).paint(c, o);

  @override
  bool shouldRepaint(covariant _RetentionPainter old) => old.points != points || old.goal != goal || old.dark != dark;
}

// ------------------------------------------------------------- heatmap

class _ActivityCard extends StatefulWidget {
  const _ActivityCard({required this.store});
  final AppStore store;

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  DateTime? _selected;
  static const _weeks = 13;

  /// Month label goes on the first column of each month; the very first column
  /// only gets one if that month continues for at least two more weeks.
  static bool _monthStartsAt(DateTime firstMonday, int w) {
    int month(int k) => firstMonday.add(Duration(days: 7 * k)).month;
    if (w == 0) return month(1) == month(0) && month(2) == month(0);
    return month(w) != month(w - 1);
  }

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    final counts = <DateTime, int>{};
    for (final l in widget.store.logs) {
      final d = dayOnly(l.time);
      counts[d] = (counts[d] ?? 0) + 1;
    }
    final maxCount = counts.values.fold<int>(1, max);
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final firstMonday = thisMonday.subtract(const Duration(days: 7 * (_weeks - 1)));
    final selected = _selected ?? today;

    Color cellColor(int n) {
      if (n == 0) return AppColors.dark ? const Color(0xFF48484B) : const Color(0xFFE2E2E8);
      final t = n / maxCount;
      if (t < 0.25) return const Color(0xFF4A5180);
      if (t < 0.55) return const Color(0xFF6672B0);
      return const Color(0xFF8C9CF0);
    }

    return _CardShell(
      icon: Icons.local_fire_department_outlined,
      title: 'Review activity',
      trailing: GestureDetector(
        onTap: () => setState(() => _selected = null),
        child: const Text('Today', style: TextStyle(color: AppColors.accent, fontSize: 19, fontWeight: FontWeight.w500)),
      ),
      child: LayoutBuilder(builder: (context, c) {
        const labelW = 26.0;
        final cell = min(34.0, (c.maxWidth - labelW) / _weeks);
        final box = cell - 5;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Month labels.
          SizedBox(
            height: 24,
            child: Stack(children: [
              for (var w = 0; w < _weeks; w++)
                if (_monthStartsAt(firstMonday, w))
                  Positioned(
                    left: labelW + w * cell,
                    child: Text(_monthsShort[firstMonday.add(Duration(days: 7 * w)).month - 1],
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  ),
            ]),
          ),
          for (var r = 0; r < 7; r++)
            Row(children: [
              SizedBox(
                width: labelW,
                child: Text('MTWTFSS'[r], style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
              ),
              for (var w = 0; w < _weeks; w++)
                Builder(builder: (_) {
                  final d = firstMonday.add(Duration(days: 7 * w + r));
                  if (d.isAfter(today)) return SizedBox(width: cell, height: cell);
                  final isToday = d == today;
                  final isSel = d == selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = d),
                    child: Container(
                      width: box,
                      height: box,
                      margin: EdgeInsets.all((cell - box) / 2),
                      decoration: BoxDecoration(
                        color: isToday ? AppColors.todayOrange : cellColor(counts[d] ?? 0),
                        borderRadius: BorderRadius.circular(5),
                        border: isSel && !isToday ? Border.all(color: Colors.white, width: 2) : null,
                      ),
                    ),
                  );
                }),
            ]),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: '${selected.day} ${_monthsShort[selected.month - 1]} ${selected.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(
                  text: '    ${counts[selected] ?? 0} cards', style: TextStyle(color: AppColors.textSecondary)),
            ]), style: const TextStyle(fontSize: 19)),
          ),
          const SizedBox(height: 18),
          Row(children: [
            Text('Less', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(width: 8),
            for (final c in [cellColor(0), const Color(0xFF4A5180), const Color(0xFF6672B0), const Color(0xFF8C9CF0)])
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
              ),
            Text('More', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ]),
        ]);
      }),
    );
  }
}

// ------------------------------------------------------------ forecast

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(DateTime.now());
    const n = 14;
    final counts = List<int>.filled(n, 0);
    for (final c in store.cards) {
      if (c.state == CardState.newCard) continue;
      final diff = dayOnly(c.due).difference(today).inDays;
      counts[diff.clamp(0, n - 1)] += diff < n ? 1 : 0;
    }
    final maxV = max(1, counts.reduce(max));
    return _CardShell(
      icon: Icons.bar_chart_rounded,
      title: 'Upcoming reviews',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${counts.reduce((a, b) => a + b)} in the next 2 weeks',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < n; i++)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (counts[i] > 0)
                    Text('${counts[i]}', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  const SizedBox(height: 3),
                  Container(
                    height: 110 * counts[i] / maxV + 2,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == 0 ? AppColors.todayOrange : AppColors.accentStrong,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(i == 0 ? 'T' : '${today.add(Duration(days: i)).day}',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final days = store.logs.map((l) => dayOnly(l.time)).toSet();
    var streak = 0;
    var d = dayOnly(DateTime.now());
    if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
    while (days.contains(d)) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    final mature = store.cards.where((c) => c.state == CardState.review && c.interval >= 21).length;
    Widget stat(String v, String l) => Expanded(
          child: Column(children: [
            Text(v, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ]),
        );
    return _CardShell(
      icon: Icons.emoji_events_outlined,
      title: 'Totals',
      child: Row(children: [
        stat('${store.logs.length}', 'reviews'),
        stat('$streak', 'day streak'),
        stat('$mature', 'mature cards'),
        stat('${days.length}', 'study days'),
      ]),
    );
  }
}
