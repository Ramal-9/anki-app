import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models.dart';
import '../services/speech.dart';
import '../srs.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'ai_practice.dart';
import 'card_editor.dart';
import '../display.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key, this.deckId});
  final String? deckId;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late List<Flashcard> _cards;
  int _index = 0;
  int _answered = 0;
  bool _revealed = false;

  /// After revealing, tapping the card flips back to the question.
  bool _showFront = false;
  int _fontStep = 1;
  static const _fontSizes = [26.0, 32.0, 38.0, 46.0];

  @override
  void initState() {
    super.initState();
    _cards = StoreScope.read(context).queue(deckId: widget.deckId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoPlay());
  }

  AppStore get _store => StoreScope.read(context);
  Flashcard? get _current => _index < _cards.length ? _cards[_index] : null;

  String _langOf(Flashcard c) {
    final deckLang = _store.deckById(c.deckId)?.language ?? 'en-GB';
    // Accent setting overrides the generic English voice.
    return deckLang.startsWith('en') ? _store.accent : deckLang;
  }

  void _autoPlay() {
    final c = _current;
    if (c != null && _store.autoPlayAudio) {
      Speech.instance.speak(c.front, lang: _langOf(c), rate: _store.speechRate);
    }
  }

  void _reveal() {
    if (_current == null || _revealed) return;
    setState(() {
      _revealed = true;
      _showFront = false;
    });
  }

  void _grade(int g) {
    final c = _current;
    if (c == null || !_revealed) return;
    _store.answer(c, g);
    _answered++;
    // Cards still in learning and due within the next 10 minutes come back this session.
    if (c.state == CardState.learning && c.due.isBefore(DateTime.now().add(const Duration(minutes: 11)))) {
      _cards.add(c);
    }
    setState(() {
      _index++;
      _revealed = false;
    });
    _autoPlay();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final card = _current;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _reveal,
        const SingleActivator(LogicalKeyboardKey.enter): _reveal,
        const SingleActivator(LogicalKeyboardKey.digit1): () => _grade(1),
        const SingleActivator(LogicalKeyboardKey.digit2): () => _grade(2),
        const SingleActivator(LogicalKeyboardKey.digit3): () => _grade(3),
        const SingleActivator(LogicalKeyboardKey.digit4): () => _grade(4),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(children: [
                  RoundButton(
                    wide: true,
                    onTap: () {
                      Speech.instance.stopSpeaking();
                      Navigator.pop(context);
                    },
                    child: Text('Quit', style: TextStyle(color: AppColors.text, fontSize: 19)),
                  ),
                  Expanded(
                    child: Text('${min(_index, _cards.length)} of ${_cards.length}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 20, fontWeight: FontWeight.w600)),
                  ),
                  _HeaderPill(
                    onEdit: card == null ? null : () => _edit(card),
                    onSettings: () => _settings(store),
                  ),
                ]),
              ),
              Expanded(child: card == null ? _finished() : _cardView(store, card)),
              if (card != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: _revealed
                      ? _gradeButtons(store, card)
                      : GradientButton(
                          onTap: _reveal,
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('👀', style: TextStyle(fontSize: 24)),
                            SizedBox(width: 14),
                            Text('Show answer'),
                          ]),
                        ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _edit(Flashcard card) async {
    Speech.instance.stopSpeaking();
    await Navigator.of(context).push(pageRoute(CardEditor(deckId: card.deckId, card: card)));
    if (!mounted) return;
    // The card may have been deleted in the editor.
    if (!_store.cards.contains(card)) {
      setState(() {
        _cards.removeAt(_index);
        _revealed = false;
      });
    } else {
      setState(() {});
    }
  }

  Widget _cardView(AppStore store, Flashcard card) {
    final fs = _fontSizes[_fontStep];
    final answerSide = _revealed && !_showFront;
    return GestureDetector(
      onTap: _revealed ? () => setState(() => _showFront = !_showFront) : _reveal,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(32)),
        child: Stack(children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 76, 26, 76),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: max(0, box.maxHeight - 152)),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Column(
                      key: ValueKey(answerSide),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: answerSide
                          ? [
                              _label('ANSWER'),
                              const SizedBox(height: 14),
                              if (card.imageUrl != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(card.imageUrl!,
                                        height: 160, errorBuilder: (_, __, ___) => const SizedBox()),
                                  ),
                                ),
                              Text(card.back,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: fs, color: AppColors.accentStrong, fontWeight: FontWeight.w700, height: 1.25)),
                            ]
                          : [
                              _label('QUESTION'),
                              const SizedBox(height: 14),
                              Text(card.front,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: fs, fontWeight: FontWeight.w700, height: 1.25)),
                            ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: _miniButton(
              child: Text('ᴀA', style: TextStyle(color: AppColors.textSecondary, fontSize: 19, fontWeight: FontWeight.w600)),
              onTap: () => setState(() => _fontStep = (_fontStep + 1) % _fontSizes.length),
            ),
          ),
          Positioned(
            top: 14,
            left: 14,
            child: _miniButton(
              child: Icon(Icons.volume_up_rounded, color: AppColors.textSecondary, size: 22),
              onTap: () => Speech.instance.speak(card.front, lang: _langOf(card), rate: store.speechRate),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => showAiPractice(context, text: card.front, lang: _langOf(card), translation: card.back),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.surface2.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.mic_rounded, color: AppColors.accent, size: 20),
                    const SizedBox(width: 6),
                    Text('AI Practice',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String s) =>
      Text(s, style: TextStyle(color: AppColors.textSecondary, fontSize: 15, letterSpacing: 1.6, fontWeight: FontWeight.w500));

  Widget _miniButton({required Widget child, required VoidCallback onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surface2.withValues(alpha: 0.6), shape: BoxShape.circle),
          child: child,
        ),
      );

  Widget _gradeButtons(AppStore store, Flashcard card) {
    final now = DateTime.now();
    const specs = [
      (1, 'again', Icons.thumb_down_outlined, Color(0xFFC9465C)),
      (2, 'hard', Icons.thumbs_up_down_outlined, Color(0xFFCC8142)),
      (3, 'good', Icons.thumb_up_outlined, Color(0xFF6B70D6)),
      (4, 'easy', Icons.sign_language_outlined, Color(0xFF4DB3A2)),
    ];
    Widget button((int, String, IconData, Color) s) => Expanded(
          child: GestureDetector(
            onTap: () => _grade(s.$1),
            child: Container(
              height: 78,
              decoration: BoxDecoration(
                color: s.$4,
                borderRadius: BorderRadius.circular(39),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                boxShadow: [BoxShadow(color: s.$4.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(s.$3, color: Colors.white, size: 34),
                const SizedBox(width: 12),
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.$2, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                  Text(shortInterval(now, store.scheduler.preview(card, s.$1, now).due),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88), fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [button(specs[0]), const SizedBox(width: 14), button(specs[1])]),
      const SizedBox(height: 12),
      Row(children: [button(specs[2]), const SizedBox(width: 14), button(specs[3])]),
    ]);
  }

  Widget _finished() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🎉', style: TextStyle(fontSize: 72)),
        const SizedBox(height: 16),
        const Text('Session complete', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(
            _answered == 0
                ? 'Nothing to study right now.'
                : 'You reviewed $_answered cards. Come back later for the next reviews.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
        const SizedBox(height: 32),
        GradientButton(height: 58, onTap: () => Navigator.pop(context), child: const Text('Done')),
      ]),
    );
  }

  void _settings(AppStore store) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SwitchListTile(
              title: const Text('Auto-play question audio'),
              value: store.autoPlayAudio,
              onChanged: (v) {
                store.autoPlayAudio = v;
                store.touch();
                set(() {});
              },
            ),
            ListTile(
              title: const Text('Text size'),
              trailing: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('S')),
                  ButtonSegment(value: 1, label: Text('M')),
                  ButtonSegment(value: 2, label: Text('L')),
                  ButtonSegment(value: 3, label: Text('XL')),
                ],
                selected: {_fontStep},
                onSelectionChanged: (s) {
                  setState(() => _fontStep = s.first);
                  set(() {});
                },
              ),
            ),
            ListTile(
              title: const Text('Keyboard shortcuts'),
              subtitle: const Text('Space — show answer · 1 Again · 2 Hard · 3 Good · 4 Easy'),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

/// Edit + settings buttons joined in one pill, like the original app.
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.onEdit, required this.onSettings});
  final VoidCallback? onEdit;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.dark ? Colors.white10 : Colors.black12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'Edit card',
          onPressed: onEdit,
          icon: Icon(Icons.edit_square, color: AppColors.text, size: 26),
        ),
        IconButton(
          tooltip: 'Study settings',
          onPressed: onSettings,
          icon: Icon(Icons.tune_rounded, color: AppColors.text, size: 26),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ quiz

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.deckId});
  final String deckId;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final _rnd = Random();
  late List<Flashcard> _pool;
  late List<Flashcard> _questions;
  int _i = 0;
  int _correct = 0;
  int? _picked;
  late List<Flashcard> _options;

  @override
  void initState() {
    super.initState();
    _pool = StoreScope.read(context).cardsOf(widget.deckId);
    _questions = (_pool.toList()..shuffle(_rnd)).take(10).toList();
    _makeOptions();
  }

  void _makeOptions() {
    if (_i >= _questions.length) return;
    final q = _questions[_i];
    final others = _pool.where((c) => c.id != q.id && c.back != q.back).toList()..shuffle(_rnd);
    _options = [q, ...others.take(3)]..shuffle(_rnd);
    _picked = null;
  }

  @override
  Widget build(BuildContext context) {
    final done = _i >= _questions.length;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              RoundButton(
                wide: true,
                onTap: () => Navigator.pop(context),
                child: Text('Quit', style: TextStyle(color: AppColors.text, fontSize: 19)),
              ),
              Expanded(
                child: Text(done ? 'Quiz' : '${_i + 1} of ${_questions.length}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 20, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 80),
            ]),
            Expanded(child: done ? _result() : _question()),
          ]),
        ),
      ),
    );
  }

  Widget _question() {
    final q = _questions[_i];
    return Column(children: [
      const SizedBox(height: 30),
      Text('What does it mean?', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, letterSpacing: 1)),
      const SizedBox(height: 14),
      Text(q.front, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
      const Spacer(),
      for (var k = 0; k < _options.length; k++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: _picked != null
                ? null
                : () {
                    setState(() {
                      _picked = k;
                      if (_options[k].id == q.id) _correct++;
                    });
                    Future.delayed(const Duration(milliseconds: 900), () {
                      if (!mounted) return;
                      setState(() {
                        _i++;
                        _makeOptions();
                      });
                    });
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _picked == null
                    ? AppColors.surface
                    : _options[k].id == q.id
                        ? AppColors.reviewGreen.withValues(alpha: 0.3)
                        : k == _picked
                            ? AppColors.newRed.withValues(alpha: 0.3)
                            : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_options[k].back, style: const TextStyle(fontSize: 17)),
            ),
          ),
        ),
    ]);
  }

  Widget _result() => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$_correct / ${_questions.length}', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text('correct answers', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
        const SizedBox(height: 32),
        GradientButton(
          height: 58,
          onTap: () => setState(() {
            _i = 0;
            _correct = 0;
            _questions = (_pool.toList()..shuffle(_rnd)).take(10).toList();
            _makeOptions();
          }),
          child: const Text('Try again'),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ]);
}
