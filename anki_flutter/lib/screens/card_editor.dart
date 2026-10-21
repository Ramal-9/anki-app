import 'dart:async';

import 'package:flutter/material.dart';

import '../display.dart';
import '../main.dart';
import '../models.dart';
import '../services/speech.dart';
import '../services/suggestions.dart';
import '../srs.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'ai_practice.dart';
import 'deck_screen.dart' show kLanguages;

/// "New Card" sheet (or edit, when [card] is given).
Future<void> showCardEditor(BuildContext context, {required String deckId, Flashcard? card}) {
  return Navigator.of(context).push(pageRoute(CardEditor(deckId: deckId, card: card), fullscreenDialog: true));
}

class CardEditor extends StatefulWidget {
  const CardEditor({super.key, required this.deckId, this.card});
  final String deckId;
  final Flashcard? card;

  @override
  State<CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<CardEditor> {
  final _front = TextEditingController();
  final _back = TextEditingController();
  final _service = SuggestionService();
  late String _deckId = widget.deckId;
  late String _lang;
  String? _imageUrl;
  bool _reverse = false;
  bool _dictating = false;

  List<PhraseSuggestion> _suggestions = [];
  bool _loading = false;
  bool _showSuggestions = true;
  final _addedPhrases = <String>{};
  Timer? _debounce;
  String _lastQuery = '';

  bool get _editing => widget.card != null;

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    _lang = store.deckById(widget.deckId)?.language ?? 'en-GB';
    if (widget.card != null) {
      _front.text = widget.card!.front;
      _back.text = widget.card!.back;
      _imageUrl = widget.card!.imageUrl;
    }
    _front.addListener(_onFrontChanged);
    if (_front.text.isNotEmpty) _refresh(force: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  void _onFrontChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _refresh);
    setState(() {});
  }

  Future<void> _refresh({bool force = false}) async {
    final q = _front.text.trim();
    if (!force && q == _lastQuery) return;
    _lastQuery = q;
    if (q.isEmpty || !_lang.startsWith('en')) {
      setState(() => _suggestions = []);
      return;
    }
    final store = StoreScope.read(context);
    setState(() {
      _loading = true;
      _suggestions = _service.offline(q);
    });
    final s = await _service.suggest(q, allowOnline: store.onlineSuggestions);
    if (!mounted || _front.text.trim() != q) return;
    setState(() {
      _suggestions = s;
      _loading = false;
    });
  }

  void _save() {
    final store = StoreScope.read(context);
    final front = _front.text.trim();
    if (front.isEmpty) {
      toast(context, 'Enter the question first');
      return;
    }
    if (_editing) {
      final c = widget.card!
        ..front = front
        ..back = _back.text.trim()
        ..deckId = _deckId
        ..imageUrl = _imageUrl;
      store.updateCard(c);
    } else {
      store.addCard(_deckId, front, _back.text, imageUrl: _imageUrl);
      if (_reverse && _back.text.trim().isNotEmpty) store.addCard(_deckId, _back.text, front);
    }
    Navigator.pop(context);
  }

  /// Appends a phrase to the Back field as an example line.
  void _insertExample(PhraseSuggestion s) {
    final line = s.translation == null ? '• ${s.phrase}' : '• ${s.phrase} — ${s.translation}';
    if (_back.text.contains(s.phrase)) return;
    _back.text = _back.text.trim().isEmpty ? line : '${_back.text.trimRight()}\n$line';
    setState(() {});
  }

  /// Creates a separate card for the phrase right away.
  void _addAsCard(PhraseSuggestion s) {
    final store = StoreScope.read(context);
    store.addCard(_deckId, s.phrase, s.translation ?? '');
    setState(() => _addedPhrases.add(s.phrase));
    toast(context, 'Card added: ${s.phrase}');
  }

  Future<void> _dictate() async {
    if (_dictating) {
      Speech.instance.stopListening();
      return;
    }
    setState(() => _dictating = true);
    try {
      final alts = await Speech.instance.listen(lang: _lang);
      if (alts.isNotEmpty) {
        _front.text = _front.text.trim().isEmpty ? alts.first.transcript : '${_front.text} ${alts.first.transcript}';
      }
    } on SpeechError catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _dictating = false);
    }
  }

  Future<void> _addImage() async {
    final url = await promptText(context, title: 'Image URL', initial: _imageUrl ?? '', hint: 'https://…');
    if (url == null) return;
    setState(() => _imageUrl = url.trim().isEmpty ? null : url.trim());
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              RoundButton(onTap: () => Navigator.pop(context), child: const Icon(Icons.close_rounded, size: 30)),
              Expanded(
                child: Text(_editing ? 'Edit Card' : 'New Card',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              GestureDetector(
                onTap: _save,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _front.text.trim().isEmpty ? AppColors.surface2 : AppColors.accentStrong,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              children: [
                if (store.decks.length > 1) _deckPicker(store),
                Container(
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(30)),
                  child: Column(children: [
                    _fieldHeader('Front', _langPicker()),
                    _field(_front, 'Enter the question', autofocus: !_editing),
                    Divider(height: 1, color: AppColors.divider, indent: 16, endIndent: 16),
                    _fieldHeader('Back', Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.keyboard_outlined, color: AppColors.textSecondary, size: 22),
                      const SizedBox(width: 10),
                      Text('Default', style: TextStyle(color: AppColors.textSecondary, fontSize: 17)),
                    ])),
                    _field(_back, 'Enter the answer'),
                    if (_imageUrl != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(_imageUrl!,
                                height: 60,
                                width: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                          ),
                          const SizedBox(width: 10),
                          TextButton(onPressed: () => setState(() => _imageUrl = null), child: const Text('Remove image')),
                        ]),
                      ),
                    Divider(height: 1, color: AppColors.divider, indent: 16, endIndent: 16),
                    _toolbar(),
                  ]),
                ),
                if (_showSuggestions && _front.text.trim().isNotEmpty) _suggestionsPanel(),
                if (_editing) ...[
                  const SizedBox(height: 24),
                  _editInfo(widget.card!),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _deckPicker(AppStore store) => Padding(
        padding: const EdgeInsets.only(bottom: 14, left: 8),
        child: Row(children: [
          Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _deckId,
            underline: const SizedBox(),
            items: [
              for (final d in store.decks) DropdownMenuItem<String>(value: d.id, child: Text(d.name)),
            ],
            onChanged: (v) => setState(() => _deckId = v!),
          ),
        ]),
      );

  Widget _fieldHeader(String title, Widget trailing) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 16, 0),
        child: Row(children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          const Spacer(),
          trailing,
        ]),
      );

  Widget _langPicker() => PopupMenuButton<String>(
        color: AppColors.surface2,
        onSelected: (v) {
          setState(() => _lang = v);
          _refresh(force: true);
        },
        itemBuilder: (_) => [for (final e in kLanguages.entries) PopupMenuItem(value: e.key, child: Text(e.value))],
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.keyboard_outlined, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 10),
          Text(kLanguages[_lang] ?? _lang, style: TextStyle(color: AppColors.textSecondary, fontSize: 17)),
          const SizedBox(width: 6),
          Icon(Icons.unfold_more_rounded, color: AppColors.textSecondary),
        ]),
      );

  Widget _field(TextEditingController c, String hint, {bool autofocus = false}) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
        child: TextField(
          controller: c,
          autofocus: autofocus,
          minLines: 3,
          maxLines: 8,
          style: const TextStyle(fontSize: 21),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 21),
            border: InputBorder.none,
          ),
        ),
      );

  Widget _toolbar() {
    Widget btn(IconData icon, String tip, VoidCallback onTap, {bool active = false}) => IconButton(
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(icon, size: 30, color: active ? AppColors.accent : AppColors.textSecondary),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        btn(Icons.add_photo_alternate_outlined, 'Add image', _addImage, active: _imageUrl != null),
        btn(_dictating ? Icons.mic_rounded : Icons.mic_none_rounded, 'Dictate the front', _dictate, active: _dictating),
        btn(Icons.auto_awesome_outlined, 'Phrase suggestions', () {
          setState(() => _showSuggestions = !_showSuggestions);
          if (_showSuggestions) _refresh(force: true);
        }, active: _showSuggestions),
        btn(Icons.record_voice_over_outlined, 'AI Practice', () {
          if (_front.text.trim().isEmpty) return toast(context, 'Enter a word or sentence first');
          showAiPractice(context, text: _front.text.trim(), lang: _lang, translation: _back.text.trim());
        }),
        if (!_editing)
          IconButton(
            tooltip: 'Also create reversed card',
            onPressed: () => setState(() => _reverse = !_reverse),
            icon: Text('👀', style: TextStyle(fontSize: 26, color: _reverse ? null : Colors.white.withValues(alpha: 0.5))),
            style: IconButton.styleFrom(backgroundColor: _reverse ? AppColors.accent.withValues(alpha: 0.25) : null),
          ),
      ]),
    );
  }

  Widget _suggestionsPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(26)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ShaderMask(
            shaderCallback: (r) => AppColors.brandGradient.createShader(r),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Useful phrases & collocations', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
          if (_loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
        ]),
        const SizedBox(height: 4),
        Text('Tap a phrase to add it to the answer as an example, or ＋ to make it a separate card.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
        const SizedBox(height: 8),
        if (_suggestions.isEmpty && !_loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
                _lang.startsWith('en')
                    ? 'No common phrases found for this word.'
                    : 'Suggestions are available for English cards.',
                style: TextStyle(color: AppColors.textMuted)),
          ),
        for (final s in _suggestions)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _insertExample(s),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.phrase, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
                    if (s.translation != null)
                      Text(s.translation!, style: TextStyle(color: AppColors.textSecondary, fontSize: 15))
                    else if (s.online)
                      Text('frequent combination', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ]),
                ),
                IconButton(
                  tooltip: 'Listen',
                  icon: Icon(Icons.volume_up_outlined, color: AppColors.textSecondary),
                  onPressed: () => Speech.instance.speak(s.phrase,
                      lang: _lang.startsWith('en') ? StoreScope.read(context).accent : _lang,
                      rate: StoreScope.read(context).speechRate),
                ),
                IconButton(
                  tooltip: 'Add as a separate card',
                  icon: Icon(
                    _addedPhrases.contains(s.phrase) ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                    color: AppColors.accent,
                  ),
                  onPressed: _addedPhrases.contains(s.phrase) ? null : () => _addAsCard(s),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _editInfo(Flashcard c) {
    final now = DateTime.now();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Panel(margin: EdgeInsets.zero, children: [
        ListTile(
          title: const Text('Status'),
          trailing: Text(switch (c.state) {
            CardState.newCard => 'New',
            CardState.learning => 'Learning',
            CardState.review => 'Review · ${relativeDue(now, c.due)}',
          }),
        ),
        ListTile(title: const Text('Interval'), trailing: Text('${c.interval} days')),
        ListTile(title: const Text('Ease'), trailing: Text('${(c.ease * 100).round()} %')),
        ListTile(title: const Text('Reviews / lapses'), trailing: Text('${c.reps} / ${c.lapses}')),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        TextButton.icon(
          onPressed: () {
            c
              ..state = CardState.newCard
              ..interval = 0
              ..ease = 2.5
              ..step = 0
              ..due = DateTime.now();
            StoreScope.read(context).updateCard(c);
            toast(context, 'Card reset to new');
          },
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Forget'),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () async {
            if (await confirm(context, 'Delete card?', c.front)) {
              if (!mounted) return;
              StoreScope.read(context).deleteCard(c.id);
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          label: const Text('Delete', style: TextStyle(color: AppColors.danger)),
        ),
      ]),
    ]);
  }
}
