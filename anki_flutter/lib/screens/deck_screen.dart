import 'package:flutter/material.dart';

import '../display.dart';
import '../main.dart';
import '../models.dart';
import '../srs.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'card_editor.dart';
import 'deck_style_sheet.dart';
import 'queue_screen.dart';
import 'study_screen.dart';

const kLanguages = {
  'en-GB': 'English (GB)',
  'en-US': 'English (US)',
  'en-AU': 'English (AU)',
  'de-DE': 'German',
  'fr-FR': 'French',
  'es-ES': 'Spanish',
  'it-IT': 'Italian',
  'tr-TR': 'Turkish',
  'ru-RU': 'Russian',
};

class DeckScreen extends StatelessWidget {
  const DeckScreen({super.key, required this.deckId});
  final String deckId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final deck = store.deckById(deckId);
    if (deck == null) return const Scaffold();
    final cards = store.cardsOf(deckId)..sort((a, b) => b.created.compareTo(a.created));
    final due = store.queue(deckId: deckId).length;
    final now = DateTime.now();

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(children: [
                    RoundButton(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back_ios_new_rounded),
                    ),
                    const Spacer(),
                    Builder(
                      builder: (btnCtx) => RoundButton(
                        onTap: () => _openMenu(btnCtx, context, store, deck),
                        child: const Icon(Icons.more_horiz_rounded, size: 30),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Text(deck.name,
                      style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    _stat('${cards.length}', 'cards'),
                    const SizedBox(width: 12),
                    _stat('$due', 'due'),
                    const SizedBox(width: 12),
                    _stat('${cards.where((c) => c.state == CardState.newCard).length}', 'new'),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 28, 20, 12),
                  child: Row(children: [
                    Icon(Icons.style_rounded, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Text('CARDS',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                  ]),
                ),
                if (cards.isEmpty)
                  Panel(children: [
                    ListTile(
                      contentPadding: const EdgeInsets.all(20),
                      title: const Text('No cards yet'),
                      subtitle: const Text('Tap ··· → Add Card'),
                      onTap: () => showCardEditor(context, deckId: deckId),
                    )
                  ])
                else
                  Panel(children: [
                    for (final c in cards) _CardRow(card: c, now: now),
                  ]),
              ],
            ),
          ),
          if (due > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: SafeArea(
                child: Center(
                  child: GestureDetector(
                    onTap: () => openStudy(context, deckId: deckId),
                    child: Container(
                      height: 62,
                      padding: const EdgeInsets.symmetric(horizontal: 44),
                      decoration: BoxDecoration(
                        color: AppColors.accentStrong,
                        borderRadius: BorderRadius.circular(31),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14, offset: Offset(0, 4))],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.school_rounded, color: Colors.white, size: 30),
                        const SizedBox(width: 14),
                        Text('Study $due cards',
                            style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          height: 104,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(26)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(value, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(fontSize: 16)),
          ]),
        ),
      );

  Future<void> _openMenu(BuildContext btnCtx, BuildContext context, AppStore store, Deck deck) async {
    final box = btnCtx.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset(0, box.size.height + 6));
    final choice = await showMenu<String>(
      context: context,
      color: AppColors.surface2.withValues(alpha: 0.98),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      constraints: const BoxConstraints(minWidth: 260),
      position: RelativeRect.fromLTRB(pos.dx - 220, pos.dy, 20, 0),
      items: [
        _item('add', Icons.add_rounded, 'Add Card'),
        _item('import', Icons.file_download_outlined, 'Import'),
        const PopupMenuDivider(),
        _item('review', Icons.sync_rounded, 'Review'),
        _item('quiz', Icons.quiz_outlined, 'Quiz'),
        const PopupMenuDivider(),
        _item('style', Icons.palette_outlined, 'Color & Icon'),
        _item('settings', Icons.settings_outlined, 'Settings'),
      ],
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'add':
        showCardEditor(context, deckId: deck.id);
      case 'import':
        _import(context, store, deck);
      case 'review':
        if (store.queue(deckId: deck.id).isEmpty) {
          toast(context, 'Nothing due in this deck right now');
        } else {
          openStudy(context, deckId: deck.id);
        }
      case 'quiz':
        if (store.cardsOf(deck.id).length < 4) {
          toast(context, 'A quiz needs at least 4 cards');
        } else {
          Navigator.of(context).push(pageRoute(QuizScreen(deckId: deck.id)));
        }
      case 'style':
        showDeckStyleSheet(context, deck);
      case 'settings':
        _settings(context, store, deck);
    }
  }

  PopupMenuItem<String> _item(String v, IconData icon, String label) => PopupMenuItem(
        value: v,
        height: 56,
        child: Row(children: [
          Icon(icon, size: 26),
          const SizedBox(width: 18),
          Text(label, style: const TextStyle(fontSize: 19)),
        ]),
      );

  Future<void> _import(BuildContext context, AppStore store, Deck deck) async {
    final text = await promptText(
      context,
      title: 'Import cards',
      hint: 'One card per line:\nfront ; back\nfront<TAB>back\nfront - back',
      action: 'Import',
      maxLines: 8,
    );
    if (text == null || !context.mounted) return;
    final n = store.importLines(deck.id, text);
    toast(context, n == 0 ? 'No cards found. Use "front ; back" per line.' : 'Imported $n cards');
  }

  void _settings(BuildContext context, AppStore store, Deck deck) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Rename'),
                subtitle: Text(deck.name),
                onTap: () async {
                  final n = await promptText(ctx, title: 'Rename deck', initial: deck.name);
                  if (n != null && n.trim().isNotEmpty) {
                    deck.name = n.trim();
                    store.updateDeck(deck);
                    setSheet(() {});
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.translate_rounded),
                title: const Text('Language (voice & mic)'),
                trailing: DropdownButton<String>(
                  value: kLanguages.containsKey(deck.language) ? deck.language : 'en-GB',
                  underline: const SizedBox(),
                  items: [
                    for (final e in kLanguages.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) {
                    deck.language = v!;
                    store.updateDeck(deck);
                    setSheet(() {});
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.fiber_new_outlined),
                title: const Text('New cards per day'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: deck.newPerDay <= 0
                        ? null
                        : () {
                            deck.newPerDay -= 5;
                            if (deck.newPerDay < 0) deck.newPerDay = 0;
                            store.updateDeck(deck);
                            setSheet(() {});
                          },
                  ),
                  Text('${deck.newPerDay}', style: const TextStyle(fontSize: 17)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      deck.newPerDay += 5;
                      store.updateDeck(deck);
                      setSheet(() {});
                    },
                  ),
                ]),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                title: const Text('Delete deck', style: TextStyle(color: AppColors.danger)),
                onTap: () async {
                  final ok = await confirm(ctx, 'Delete "${deck.name}"?', 'All its cards will be deleted too.');
                  if (ok && context.mounted) {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                    store.deleteDeck(deck.id);
                  }
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.card, required this.now});
  final Flashcard card;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showCardEditor(context, deckId: card.deckId, card: card),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 10, 16),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(card.front,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(card.back.isEmpty ? '—' : card.back.split('\n').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 17)),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            StateTag(card.state),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(card.state == CardState.newCard ? 'new' : relativeDue(now, card.due),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            ]),
          ]),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}
