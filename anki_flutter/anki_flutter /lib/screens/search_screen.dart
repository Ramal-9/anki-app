import 'package:flutter/material.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'card_editor.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = _q.trim().toLowerCase();
    final results = q.isEmpty
        ? <Flashcard>[]
        : store.cards.where((c) => c.front.toLowerCase().contains(q) || c.back.toLowerCase().contains(q)).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: [
              RoundButton(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_ios_new_rounded)),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(26)),
                  child: Row(children: [
                    Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) => setState(() => _q = v),
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          hintText: 'Search cards',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          Expanded(
            child: q.isEmpty
                ? Center(
                    child: Text('Search by question or answer',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16)))
                : results.isEmpty
                    ? Center(child: Text('Nothing found', style: TextStyle(color: AppColors.textSecondary)))
                    : CardList(cards: results),
          ),
        ]),
      ),
    );
  }
}

/// A plain list of cards (used by search and smart folders).
class CardList extends StatelessWidget {
  const CardList({super.key, required this.cards});
  final List<Flashcard> cards;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListView(padding: const EdgeInsets.only(bottom: 30), children: [
      Panel(children: [
        for (final c in cards)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            title: Text(c.front,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
            subtitle: Text('${store.deckById(c.deckId)?.name ?? ''} · ${c.back.split('\n').first}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: StateTag(c.state),
            onTap: () => showCardEditor(context, deckId: c.deckId, card: c),
          ),
      ]),
    ]);
  }
}

class CardListScreen extends StatelessWidget {
  const CardListScreen({super.key, required this.title, required this.cards});
  final String title;
  final List<Flashcard> cards;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: RoundButton(onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_ios_new_rounded)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(title, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
          ),
          Expanded(
            child: cards.isEmpty
                ? Center(child: Text('No cards here', style: TextStyle(color: AppColors.textSecondary)))
                : CardList(cards: cards),
          ),
        ]),
      ),
    );
  }
}
