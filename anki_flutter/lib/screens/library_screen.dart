import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'ai_practice.dart';
import 'deck_screen.dart';
import 'search_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _folders = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Stack(
      children: [
        SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 130),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    RoundButton(onTap: () => _menu(context, store), child: const Icon(Icons.format_list_bulleted_rounded)),
                    const Spacer(),
                    _Segmented(
                      value: _folders ? 1 : 0,
                      labels: const ['Decks', 'Folders'],
                      onChanged: (i) => setState(() => _folders = i == 1),
                    ),
                    const Spacer(),
                    RoundButton(onTap: () => _newDeck(context, store), child: const Icon(Icons.add_rounded, size: 32)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text('Library', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 14, 20, 12),
                child: Wrap(spacing: 22, children: [
                  _dot(AppColors.newRed, '${store.countState(CardState.newCard)} new'),
                  _dot(AppColors.learningBlue, '${store.countState(CardState.learning)} learning'),
                  _dot(AppColors.reviewGreen, '${store.countState(CardState.review)} review'),
                ]),
              ),
              if (!_folders) _decksGrid(context, store) else _smartFolders(context, store),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: 120,
          child: GestureDetector(
            onTap: () => showFreePractice(context),
            child: Container(
              width: 82,
              height: 82,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF0A97C), Color(0xFFD27FD4), Color(0xFF7FB6DE)],
                ),
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 38),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 17)),
      ]);

  Widget _decksGrid(BuildContext context, AppStore store) {
    if (store.decks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Text('No decks yet. Tap + to create one.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.7,
        children: [
          for (final d in store.decks)
            DeckTile(
              name: d.name,
              cards: store.cardsOf(d.id).length,
              due: store.queue(deckId: d.id).length,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeckScreen(deckId: d.id))),
            ),
        ],
      ),
    );
  }

  Widget _smartFolders(BuildContext context, AppStore store) {
    final now = DateTime.now();
    final folders = <(IconData, String, List<Flashcard>)>[
      (Icons.folder_rounded, 'All cards', store.cards.toList()),
      (Icons.schedule_rounded, 'Due today', store.queue()),
      (Icons.fiber_new_rounded, 'New cards', store.cards.where((c) => c.state == CardState.newCard).toList()),
      (Icons.trending_down_rounded, 'Difficult (lapsed)', store.cards.where((c) => c.lapses > 0).toList()),
      (
        Icons.today_rounded,
        'Added this week',
        store.cards.where((c) => now.difference(c.created).inDays < 7).toList()
      ),
    ];
    return Panel(children: [
      for (final f in folders)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Icon(f.$1, color: AppColors.accent, size: 28),
          title: Text(f.$2, style: const TextStyle(fontSize: 18)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${f.$3.length}', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ]),
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => CardListScreen(title: f.$2, cards: f.$3))),
        ),
    ]);
  }

  Future<void> _newDeck(BuildContext context, AppStore store) async {
    final name = await promptText(context, title: 'New deck', hint: 'Deck name', action: 'Create');
    if (name != null && name.trim().isNotEmpty) store.addDeck(name.trim());
  }

  void _menu(BuildContext context, AppStore store) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.add_box_outlined),
            title: const Text('New deck'),
            onTap: () {
              Navigator.pop(ctx);
              _newDeck(context, store);
            },
          ),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('AI Practice (any phrase)'),
            onTap: () {
              Navigator.pop(ctx);
              showFreePractice(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.search_rounded),
            title: const Text('Search cards'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen()));
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.labels, required this.onChanged});
  final int value;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.dark ? Colors.white10 : Colors.black12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < labels.length; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 26),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == value ? (AppColors.dark ? const Color(0xFF151517) : AppColors.surface2) : null,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(labels[i], style: TextStyle(color: AppColors.text, fontSize: 18)),
            ),
          ),
      ]),
    );
  }
}
