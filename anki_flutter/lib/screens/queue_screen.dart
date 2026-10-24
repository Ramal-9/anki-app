import 'package:flutter/material.dart';

import '../display.dart';
import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'card_editor.dart';
import 'deck_screen.dart';
import 'settings_pages.dart';
import 'study_screen.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final queue = store.queue();
    final now = DateTime.now();
    final newCount = queue.where((c) => c.state == CardState.newCard).length;
    final reviewCount = queue.length - newCount;
    final minutes = (queue.length * 12 / 60).ceil();
    final done = store.answeredToday();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SizedBox(
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const SquiggleLogo(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: RoundButton(
                        onTap: () => _editGoal(context, store),
                        child: const Icon(Icons.track_changes_rounded, size: 30),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _QueueHero(
              date: '${_weekdays[now.weekday - 1]} ${_months[now.month - 1]} ${now.day}',
              ready: queue.length,
              minutes: minutes,
              newCount: newCount,
              reviewCount: reviewCount,
              done: done,
              goal: store.goalTracking ? store.dailyGoal : 0,
              onStudy: () => openStudy(context),
            ),
          ),
          const SliverToBoxAdapter(child: SectionLabel('Study by deck')),
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, c) {
                // Two tiles across on a phone, more on wider windows.
                final n = columnsFor(c.maxWidth, minTile: 240);
                final tileWidth = (c.maxWidth - 40 - 12 * (n - 1)) / n;
                return SizedBox(
                  height: 108,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: store.decks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final d = store.decks[i];
                      return SizedBox(
                        width: tileWidth,
                        child: DeckTile(
                          name: d.name,
                          cards: store.cardsOf(d.id).length,
                          due: store.queue(deckId: d.id).length,
                          onTap: () => Navigator.of(context).push(pageRoute(DeckScreen(deckId: d.id))),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SectionLabel(
              'Queue',
              padding: const EdgeInsets.fromLTRB(20, 34, 12, 12),
              trailing: _SortButton(store: store),
            ),
          ),
          SliverToBoxAdapter(
            child: queue.isEmpty
                ? Panel(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          'All caught up! 🎉\nAdd new cards in the Library.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.4),
                        ),
                      ),
                    ],
                  )
                : Panel(
                    children: [
                      for (var i = 0; i < queue.length && i < 50; i++)
                        _QueueRow(index: i + 1, card: queue[i], deckName: store.deckById(queue[i].deckId)?.name ?? ''),
                    ],
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Future<void> _editGoal(BuildContext context, AppStore store) => showDailyGoalsSheet(context);
}

void openStudy(BuildContext context, {String? deckId}) {
  Navigator.of(context).push(pageRoute(StudyScreen(deckId: deckId), fullscreenDialog: true));
}

class _QueueHero extends StatelessWidget {
  const _QueueHero({
    required this.date,
    required this.ready,
    required this.minutes,
    required this.newCount,
    required this.reviewCount,
    required this.done,
    required this.goal,
    required this.onStudy,
  });

  final String date;
  final int ready, minutes, newCount, reviewCount, done, goal;
  final VoidCallback onStudy;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final dim = Colors.white.withValues(alpha: 0.9);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 26),
      decoration: BoxDecoration(gradient: AppColors.queueGradient, borderRadius: BorderRadius.circular(36)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // soft light blob in the top-right corner
          Positioned(
            right: -60,
            top: -60,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.18), Colors.transparent]),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'IN YOUR QUEUE', style: TextStyle(letterSpacing: 2.4)),
                    const TextSpan(text: '  ·  '),
                    TextSpan(text: date, style: const TextStyle(letterSpacing: 0.4)),
                  ],
                ),
                style: TextStyle(color: dim, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$ready',
                    style: const TextStyle(
                      color: white,
                      fontSize: 76,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'cards ready',
                    style: TextStyle(color: white, fontSize: 22, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                '~$minutes min  ·  $newCount new  ·  $reviewCount review',
                style: TextStyle(color: dim, fontSize: 17, fontWeight: FontWeight.w500),
              ),
              if (goal > 0) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(color: dim, fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: goal == 0 ? 0 : (done / goal).clamp(0, 1),
                        minHeight: 9,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '$done / $goal',
                    style: TextStyle(color: dim, fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              ],
              const SizedBox(height: 22),
              GestureDetector(
                onTap: ready == 0 ? null : onStudy,
                child: Container(
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school_rounded, color: Colors.black, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        ready == 0 ? 'Nothing due' : 'Study cards',
                        style: const TextStyle(color: Colors.black, fontSize: 21, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.store});
  final AppStore store;

  static const _labels = {QueueSort.dueDate: 'Due Date', QueueSort.deck: 'Deck', QueueSort.created: 'Recently Added'};

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<QueueSort>(
      color: AppColors.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: (s) {
        store.queueSort = s;
        store.touch();
      },
      itemBuilder: (_) => [
        for (final e in _labels.entries)
          PopupMenuItem(
            value: e.key,
            child: Row(
              children: [
                Expanded(child: Text(e.value)),
                if (e.key == store.queueSort) const Icon(Icons.check, size: 18),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_rounded, color: AppColors.accentStrong, size: 26),
            const SizedBox(width: 6),
            Text(
              _labels[store.queueSort]!,
              style: const TextStyle(color: AppColors.accentStrong, fontSize: 21, fontWeight: FontWeight.w500),
            ),
            const Icon(Icons.unfold_more_rounded, color: AppColors.accentStrong),
          ],
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.index, required this.card, required this.deckName});
  final int index;
  final Flashcard card;
  final String deckName;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showCardEditor(context, deckId: card.deckId, card: card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              margin: const EdgeInsets.only(top: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$index',
                style: const TextStyle(color: AppColors.accent, fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.front,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(deckName, style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StateTag(card.state),
          ],
        ),
      ),
    );
  }
}
