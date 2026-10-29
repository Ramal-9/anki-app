import 'package:flutter/material.dart';

import '../deck_style.dart';
import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Bottom sheet to pick a deck's color and topic icon. Changes apply at once.
Future<void> showDeckStyleSheet(BuildContext context, Deck deck) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _DeckStyleSheet(deck: deck),
  );
}

class _DeckStyleSheet extends StatelessWidget {
  const _DeckStyleSheet({required this.deck});
  final Deck deck;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final color = DeckStyle.colorOf(deck);
    final iconKey = DeckStyle.iconKeyOf(deck);
    void save(void Function() change) {
      change();
      store.updateDeck(deck);
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: SizedBox(
                width: 220,
                child: DeckTile(
                  name: deck.name,
                  cards: store.cardsOf(deck.id).length,
                  due: store.queue(deckId: deck.id).length,
                  gradient: DeckStyle.gradientOf(deck),
                  icon: DeckStyle.iconOf(deck),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text('Color', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (var i = 0; i < DeckStyle.palette.length; i++)
                Tooltip(
                  message: DeckStyle.palette[i].$1,
                  child: GestureDetector(
                    onTap: () => save(() => deck.color = i),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: DeckStyle.gradient(i),
                        shape: BoxShape.circle,
                        border: Border.all(color: i == color ? AppColors.text : Colors.transparent, width: 3),
                      ),
                      child: i == color ? const Icon(Icons.check_rounded, color: Colors.white, size: 22) : null,
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              const Expanded(child: Text('Icon', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
              if (deck.icon != null)
                TextButton(
                  onPressed: () => save(() => deck.icon = null),
                  child: const Text('Auto from name'),
                ),
            ]),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, c) {
              final n = (c.maxWidth / 76).floor().clamp(4, 8);
              final w = (c.maxWidth - (n - 1) * 8) / n;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (key, icon, label, _) in DeckStyle.icons)
                  GestureDetector(
                    onTap: () => save(() => deck.icon = key),
                    child: Container(
                      width: w,
                      height: 70,
                      decoration: BoxDecoration(
                        color: key == iconKey ? AppColors.accent.withValues(alpha: 0.18) : AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: key == iconKey ? AppColors.accent : Colors.transparent, width: 1.4),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(icon, color: key == iconKey ? AppColors.accent : AppColors.text, size: 26),
                        const SizedBox(height: 4),
                        Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                      ]),
                    ),
                  ),
              ]);
            }),
            const SizedBox(height: 18),
            GradientButton(height: 54, onTap: () => Navigator.pop(context), child: const Text('Done')),
          ]),
        ),
      ),
    );
  }
}
