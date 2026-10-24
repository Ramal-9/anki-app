import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../display.dart';
import '../main.dart';
import '../services/card_generator.dart';
import '../services/speech.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'deck_screen.dart';

enum _Source { text, image, file, audio }

/// Library ✨ → Generate Cards: turns notes, a photo, a file or dictation into cards.
class GenerateCardsScreen extends StatefulWidget {
  const GenerateCardsScreen({super.key, this.deckId});
  final String? deckId;

  @override
  State<GenerateCardsScreen> createState() => _GenerateCardsScreenState();
}

class _GenerateCardsScreenState extends State<GenerateCardsScreen> {
  final _text = TextEditingController();
  _Source _source = _Source.text;
  int _count = 15;
  CardStyle _style = CardStyle.auto;
  String? _deckId; // null = new deck
  String? _busy;

  @override
  void initState() {
    super.initState();
    _deckId = widget.deckId;
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    Speech.instance.stopListening();
    super.dispose();
  }

  void _append(String more) {
    more = more.trim();
    if (more.isEmpty) return;
    final cur = _text.text.trim();
    var next = cur.isEmpty ? more : '$cur\n$more';
    if (next.length > CardGenerator.maxChars) next = next.substring(0, CardGenerator.maxChars);
    _text.text = next;
  }

  Future<void> _pickSource(_Source s) async {
    setState(() => _source = s);
    switch (s) {
      case _Source.text:
        return;
      case _Source.file:
        final f = await _pickFile('.txt,.md,.csv,.tsv,.srt,.vtt,text/plain', false);
        if (f != null) {
          _append(f.$2);
          if (mounted) toast(context, 'Loaded ${f.$1}');
        }
      case _Source.image:
        final f = await _pickFile('image/*', true);
        if (f == null || !mounted) return;
        setState(() => _busy = 'Reading text from the photo…');
        try {
          final ocr = globalContext.callMethod<JSPromise<JSString>>('afOcr'.toJS, f.$2.toJS);
          _append((await ocr.toDart).toDart);
        } catch (_) {
          if (mounted) toast(context, 'Reading photos needs internet the first time. Try again online.');
        }
        if (mounted) setState(() => _busy = null);
      case _Source.audio:
        setState(() => _busy = 'Listening… speak now');
        try {
          final alts = await Speech.instance.listen(lang: StoreScope.read(context).accent);
          _append(alts.first.transcript.endsWith('.') ? alts.first.transcript : '${alts.first.transcript}.');
        } on SpeechError catch (e) {
          if (mounted) toast(context, e.message);
        }
        if (mounted) setState(() => _busy = null);
    }
  }

  Future<(String, String)?> _pickFile(String accept, bool dataUrl) async {
    final files = globalContext.getProperty<JSObject?>('afFiles'.toJS);
    if (files == null) return null;
    final r = await files.callMethod<JSPromise<JSObject?>>('pick'.toJS, accept.toJS, dataUrl.toJS).toDart;
    if (r == null) return null;
    return (r.getProperty<JSString>('name'.toJS).toDart, r.getProperty<JSString>('content'.toJS).toDart);
  }

  void _generate() {
    final cards = CardGenerator.generate(_text.text, count: _count, style: _style);
    if (cards.isEmpty) {
      toast(context, 'No cards found. Paste a few English sentences or "word - meaning" lines.');
      return;
    }
    Navigator.of(context).push(pageRoute(_ReviewGenerated(
      cards: cards,
      deckId: _deckId,
      suggestedName: _suggestName(),
    )));
  }

  String _suggestName() {
    final words = _text.text.trim().split(RegExp(r'\s+')).take(3).join(' ');
    return words.isEmpty ? 'Generated' : (words.length > 24 ? words.substring(0, 24) : words);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final deck = _deckId == null ? null : store.deckById(_deckId!);
    final ready = _text.text.trim().isNotEmpty && _busy == null;
    final styleName = switch (_style) {
      CardStyle.auto => 'Auto',
      CardStyle.wordToMeaning => 'Word → meaning',
      CardStyle.cloze => 'Fill the gap',
    };

    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SizedBox(
                height: 56,
                child: Stack(alignment: Alignment.center, children: [
                  const Text('Generate Cards', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RoundButton(onTap: () => Navigator.pop(context), child: const Icon(Icons.close_rounded, size: 30)),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: RoundButton(onTap: _optionsSheet, child: const Icon(Icons.tune_rounded)),
                  ),
                ]),
              ),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 20), children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                        ),
                      const SizedBox(width: 6),
                      Text('Unlimited · works offline',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  for (final (s, icon, label) in const [
                    (_Source.text, Icons.notes_rounded, 'Text'),
                    (_Source.image, Icons.image_outlined, 'Image'),
                    (_Source.file, Icons.insert_drive_file_outlined, 'File'),
                    (_Source.audio, Icons.graphic_eq_rounded, 'Audio (beta)'),
                  ]) ...[
                    if (s != _Source.text) const SizedBox(width: 9),
                    Expanded(child: _SourceTile(icon: icon, label: label, selected: _source == s, onTap: () => _pickSource(s))),
                  ],
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 16, 10),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
                  child: Column(children: [
                    TextField(
                      controller: _text,
                      minLines: 6,
                      maxLines: 12,
                      maxLength: CardGenerator.maxChars,
                      style: const TextStyle(fontSize: 18, height: 1.35),
                      decoration: InputDecoration(
                        hintText: 'Paste your notes, article, or any text here...',
                        hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 18),
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    Divider(color: AppColors.divider, height: 1),
                    const SizedBox(height: 6),
                    Row(children: [
                      TextButton.icon(
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) _append(data!.text!);
                        },
                        icon: Icon(Icons.content_paste_rounded, color: AppColors.textSecondary, size: 20),
                        label: Text('Paste', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      if (_text.text.isNotEmpty)
                        TextButton(
                          onPressed: _text.clear,
                          child: Text('Clear', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                        ),
                      const Spacer(),
                      Text('${_fmt(_text.text.length)} / 5 000', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                    ]),
                  ]),
                ),
                if (_busy != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text(_busy!, style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                      if (_source == _Source.audio)
                        TextButton(onPressed: Speech.instance.stopListening, child: const Text('Stop')),
                    ]),
                  ),
                const SizedBox(height: 16),
                Panel(margin: EdgeInsets.zero, children: [
                  _OptionRow(
                    leading: const Icon(Icons.auto_fix_high_outlined, color: AppColors.accent, size: 26),
                    title: 'About $_count cards · $styleName',
                    subtitle: 'tap to adjust count and style',
                    onTap: _optionsSheet,
                  ),
                  _OptionRow(
                    leading: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: AppColors.accentStrong, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 18),
                    ),
                    title: deck == null ? 'Save to a new deck' : 'Save to ${deck.name}',
                    subtitle: 'tap to choose or create',
                    onTap: () => _deckSheet(store),
                  ),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: ready
                  ? GradientButton(
                      height: 62,
                      onTap: _generate,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_fix_high_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        Text('Generate $_count cards'),
                      ]),
                    )
                  : Container(
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(31),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.auto_fix_high_rounded, color: AppColors.textMuted),
                        const SizedBox(width: 10),
                        Text('Generate $_count cards',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 20, fontWeight: FontWeight.w600)),
                      ]),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  String _fmt(int n) => n >= 1000 ? '${n ~/ 1000} ${(n % 1000).toString().padLeft(3, '0')}' : '$n';

  void _optionsSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          void update(VoidCallback f) {
            setState(f);
            set(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('About $_count cards', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                Slider(
                  value: _count.toDouble(),
                  min: 5,
                  max: 50,
                  divisions: 9,
                  label: '$_count',
                  onChanged: (v) => update(() => _count = v.round()),
                ),
                const SizedBox(height: 8),
                const Text('Style', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                SegmentedButton<CardStyle>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: CardStyle.auto, label: Text('Auto')),
                    ButtonSegment(value: CardStyle.wordToMeaning, label: Text('Word → meaning')),
                    ButtonSegment(value: CardStyle.cloze, label: Text('Fill the gap')),
                  ],
                  selected: {_style},
                  onSelectionChanged: (v) => update(() => _style = v.first),
                ),
                const SizedBox(height: 12),
                Text(
                  'Lines like "word - meaning" become cards as they are. Useful phrases from the text get a '
                  'Russian translation and the sentence as an example. Rare words get their sentence; '
                  'translations can be added online on the next screen. "Fill the gap" hides the word in the sentence.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _deckSheet(AppStore store) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.add_box_outlined, color: AppColors.accent),
            title: const Text('New deck'),
            trailing: _deckId == null ? const Icon(Icons.check_rounded, color: AppColors.accent) : null,
            onTap: () {
              setState(() => _deckId = null);
              Navigator.pop(ctx);
            },
          ),
          for (final d in store.decks)
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(d.name),
              trailing: _deckId == d.id ? const Icon(Icons.check_rounded, color: AppColors.accent) : null,
              onTap: () {
                setState(() => _deckId = d.id);
                Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.accent : Colors.transparent, width: 1.2),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(label, style: TextStyle(color: color, fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({required this.leading, required this.title, required this.subtitle, required this.onTap});
  final Widget leading;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Row(children: [
          SizedBox(width: 32, child: Center(child: leading)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 19)),
              Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------ review step

class _ReviewGenerated extends StatefulWidget {
  const _ReviewGenerated({required this.cards, required this.deckId, required this.suggestedName});
  final List<GeneratedCard> cards;
  final String? deckId;
  final String suggestedName;

  @override
  State<_ReviewGenerated> createState() => _ReviewGeneratedState();
}

class _ReviewGeneratedState extends State<_ReviewGenerated> {
  bool _translating = false;

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    final n = cards.where((c) => c.selected).length;
    final needsTranslation = cards.any((c) => c.kind == 'word' && !c.back.contains(' - ') && c.back.startsWith('“'));
    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SizedBox(
                height: 56,
                child: Stack(alignment: Alignment.center, children: [
                  Text('${cards.length} cards', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: RoundButton(
                        onTap: () => Navigator.pop(context), child: const Icon(Icons.arrow_back_ios_new_rounded)),
                  ),
                ]),
              ),
            ),
            if (needsTranslation)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: OutlinedButton.icon(
                  onPressed: _translating
                      ? null
                      : () async {
                          setState(() => _translating = true);
                          await CardGenerator.translateMissing(cards);
                          if (mounted) setState(() => _translating = false);
                        },
                  icon: _translating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.translate_rounded),
                  label: const Text('Add Russian translations (online)'),
                ),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                itemCount: cards.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final c = cards[i];
                  return GestureDetector(
                    onTap: () => _edit(c),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: c.selected ? AppColors.accent.withValues(alpha: 0.5) : Colors.transparent),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Checkbox(value: c.selected, onChanged: (v) => setState(() => c.selected = v ?? false)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.front, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(c.back.isEmpty ? '—' : c.back,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                          ]),
                        ),
                        Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 20),
                      ]),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Opacity(
                opacity: n == 0 ? 0.5 : 1,
                child: GradientButton(height: 62, onTap: n == 0 ? null : _save, child: Text('Add $n cards')),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _edit(GeneratedCard c) async {
    final front = await promptText(context, title: 'Front', initial: c.front, maxLines: 3);
    if (front == null || !mounted) return;
    final back = await promptText(context, title: 'Back', initial: c.back, maxLines: 5);
    if (back == null) return;
    setState(() {
      c.front = front.trim();
      c.back = back.trim();
    });
  }

  Future<void> _save() async {
    final store = StoreScope.read(context);
    var deckId = widget.deckId;
    if (deckId == null || store.deckById(deckId) == null) {
      final name = await promptText(context, title: 'New deck', initial: widget.suggestedName, action: 'Create');
      if (name == null || name.trim().isEmpty || !mounted) return;
      deckId = store.addDeck(name.trim()).id;
    }
    var n = 0;
    for (final c in widget.cards.where((c) => c.selected && c.front.isNotEmpty)) {
      store.addCard(deckId, c.front, c.back);
      n++;
    }
    if (!mounted) return;
    toast(context, 'Added $n cards');
    Navigator.of(context)
      ..popUntil((r) => r.isFirst)
      ..push(pageRoute(DeckScreen(deckId: deckId)));
  }
}
