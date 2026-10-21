import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/pronunciation.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Opens the AI Practice sheet: a native voice reads [text], then the user
/// repeats it into the microphone and gets a pronunciation score.
Future<void> showAiPractice(BuildContext context, {required String text, String? lang, String? translation}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AiPracticeSheet(text: text, lang: lang, translation: translation),
  );
}

/// Asks for any word or sentence, then opens AI Practice for it.
Future<void> showFreePractice(BuildContext context) async {
  final text = await promptText(context,
      title: 'AI Practice', hint: 'Type a word or sentence to practise', action: 'Practice', maxLines: 3);
  if (text == null || text.trim().isEmpty || !context.mounted) return;
  await showAiPractice(context, text: text.trim());
}

enum _Phase { idle, speaking, listening, result, error }

class AiPracticeSheet extends StatefulWidget {
  const AiPracticeSheet({super.key, required this.text, this.lang, this.translation});
  final String text;
  final String? lang;
  final String? translation;

  @override
  State<AiPracticeSheet> createState() => _AiPracticeSheetState();
}

class _AiPracticeSheetState extends State<AiPracticeSheet> with SingleTickerProviderStateMixin {
  final _speech = Speech.instance;
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  _Phase _phase = _Phase.idle;
  String _partial = '';
  PronunciationResult? _result;
  String? _error;
  bool _slow = false;
  late String _lang;
  final _history = <int>[];

  @override
  void initState() {
    super.initState();
    final store = StoreScope.read(context);
    final l = widget.lang ?? store.accent;
    _lang = l.startsWith('en') ? store.accent : l;
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void dispose() {
    _pulse.dispose();
    _speech.stopSpeaking();
    _speech.stopListening();
    super.dispose();
  }

  double get _rate {
    final base = StoreScope.read(context).speechRate;
    return _slow ? base * 0.6 : base;
  }

  Future<void> _play({String? text}) async {
    if (!_speech.ttsSupported) {
      setState(() {
        _phase = _Phase.error;
        _error = 'This browser cannot play speech.';
      });
      return;
    }
    _speech.stopListening();
    setState(() => _phase = _Phase.speaking);
    await _speech.speak(text ?? widget.text, lang: _lang, rate: _rate);
    if (mounted && _phase == _Phase.speaking) {
      setState(() => _phase = _result == null ? _Phase.idle : _Phase.result);
    }
  }

  Future<void> _listen() async {
    if (_phase == _Phase.listening) {
      _speech.stopListening();
      return;
    }
    setState(() {
      _phase = _Phase.listening;
      _partial = '';
      _error = null;
    });
    try {
      final alts = await _speech.listen(
        lang: _lang,
        onPartial: (p) {
          if (mounted) setState(() => _partial = p);
        },
      );
      final r = PronunciationChecker.check(widget.text, alts);
      if (!mounted) return;
      setState(() {
        _result = r;
        _history.add(r.score);
        _phase = _Phase.result;
      });
    } on SpeechError catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = e.message;
      });
    }
  }

  void _stop() {
    _speech.stopSpeaking();
    _speech.stopListening();
    setState(() => _phase = _result == null ? _Phase.idle : _Phase.result);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Container(
      height: h * 0.86,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.dark ? const Color(0xFF29292B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
      ),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(
          width: 64,
          height: 5,
          decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(3)),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 18, top: 4),
            child: RoundButton(
              size: 48,
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close_rounded, color: AppColors.textSecondary),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              _targetText(),
              if (widget.translation != null && widget.translation!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(widget.translation!,
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 17)),
              ],
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _chip(Icons.volume_up_rounded, 'Listen', () => _play()),
                const SizedBox(width: 10),
                _chip(Icons.slow_motion_video_rounded, _slow ? 'Slow: on' : 'Slow', () {
                  setState(() => _slow = !_slow);
                  _play();
                }, active: _slow),
                const SizedBox(width: 10),
                _chip(Icons.flag_outlined, _accentLabel(_lang), _cycleAccent),
              ]),
              const SizedBox(height: 28),
              _body(),
            ]),
          ),
        ),
        _bottomBar(),
      ]),
    );
  }

  String _accentLabel(String l) => const {'en-GB': 'UK', 'en-US': 'US', 'en-AU': 'AU'}[l] ?? l;

  void _cycleAccent() {
    if (!_lang.startsWith('en')) return;
    const order = ['en-GB', 'en-US', 'en-AU'];
    setState(() => _lang = order[(order.indexOf(_lang) + 1) % order.length]);
    _play();
  }

  /// Target phrase; after a result each word is colored by how well it was said.
  Widget _targetText() {
    final r = _result;
    const style = TextStyle(fontSize: 38, fontWeight: FontWeight.w700, height: 1.25);
    if (r == null) return Text(widget.text, textAlign: TextAlign.center, style: style);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      children: [
        for (final w in r.words)
          GestureDetector(
            onTap: () => _play(text: w.word),
            child: Text(w.word,
                style: style.copyWith(
                  color: switch (w.status) {
                    WordStatus.correct => AppColors.reviewGreen,
                    WordStatus.close => AppColors.todayOrange,
                    WordStatus.wrong || WordStatus.missing => AppColors.newRed,
                  },
                  decoration: w.status == WordStatus.missing ? TextDecoration.underline : null,
                  decorationStyle: TextDecorationStyle.dotted,
                )),
          ),
      ],
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap, {bool active = false}) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.accent.withValues(alpha: 0.25) : AppColors.surface2,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 19, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: AppColors.text, fontSize: 15)),
          ]),
        ),
      );

  Widget _body() {
    switch (_phase) {
      case _Phase.speaking:
        return _hint(Icons.graphic_eq_rounded, 'Listen to the native speaker…');
      case _Phase.listening:
        return Column(children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              width: 90 + _pulse.value * 20,
              height: 90 + _pulse.value * 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withValues(alpha: 0.15 + _pulse.value * 0.15),
              ),
              child: const Icon(Icons.mic_rounded, size: 44, color: AppColors.accent),
            ),
          ),
          const SizedBox(height: 18),
          Text(_partial.isEmpty ? 'Listening… say the phrase' : '“$_partial”',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 19)),
        ]);
      case _Phase.error:
        return _hint(Icons.error_outline_rounded, _error ?? 'Something went wrong', color: AppColors.newRed);
      case _Phase.result:
        return _resultView(_result!);
      case _Phase.idle:
        return _hint(Icons.record_voice_over_outlined,
            _speech.recognitionSupported
                ? 'Tap the microphone and repeat the phrase'
                : 'Speech recognition is not available in this browser. Use Chrome, Edge or Safari.');
    }
  }

  Widget _hint(IconData icon, String text, {Color? color}) => Column(children: [
        Icon(icon, size: 44, color: color ?? AppColors.textMuted),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: color ?? AppColors.textSecondary, fontSize: 17)),
      ]);

  Widget _resultView(PronunciationResult r) {
    final color = r.score >= 85
        ? AppColors.reviewGreen
        : r.score >= 60
            ? AppColors.todayOrange
            : AppColors.newRed;
    final problems = r.words.where((w) => w.status != WordStatus.correct).toList();
    return Column(children: [
      SizedBox(
        width: 130,
        height: 130,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: r.score / 100,
              strokeWidth: 10,
              color: color,
              backgroundColor: AppColors.surface2,
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${r.score}', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: color)),
            Text('/ 100', style: TextStyle(color: AppColors.textSecondary)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      Text(r.verdict, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('We heard: “${r.heard}”',
          textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
      if (problems.isNotEmpty) ...[
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface2.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Work on these words (tap to hear):',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final w in problems.take(8))
                ActionChip(
                  avatar: const Icon(Icons.volume_up_rounded, size: 16),
                  label: Text(w.heard == null ? '${w.word} (missed)' : '${w.word} → ${w.heard}'),
                  onPressed: () => _play(text: w.word),
                ),
            ]),
          ]),
        ),
      ],
      if (_history.length > 1) ...[
        const SizedBox(height: 14),
        Text('Attempts: ${_history.join(' → ')}   Best: ${_history.reduce(max)}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      ],
    ]);
  }

  Widget _bottomBar() {
    final listening = _phase == _Phase.listening;
    final label = switch (_phase) {
      _Phase.listening => 'Listening… tap to finish',
      _Phase.result => 'Tap to try again',
      _ => 'Practice speaking',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 26, 26, 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.dark
              ? [const Color(0xFF2F2E36), const Color(0xFF252A35)]
              : [const Color(0xFFF1F0F7), const Color(0xFFE6EBF5)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(60)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            _round(
              onTap: _stop,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: const Color(0xFF6FA7C8), borderRadius: BorderRadius.circular(6)),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: GestureDetector(
                onTap: _listen,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Container(
                    height: 78,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(39),
                      border: Border.all(color: Colors.white24, width: 2),
                      gradient: LinearGradient(colors: [
                        const Color(0xFF6F9CC0),
                        const Color(0xFF86B8DC),
                        Color.lerp(const Color(0xFFA9A3F5), const Color(0xFFC9A3F5), listening ? _pulse.value : 0)!,
                      ]),
                      boxShadow: listening
                          ? [BoxShadow(color: const Color(0xFF9AA6F0).withValues(alpha: 0.5), blurRadius: 12 + 10 * _pulse.value)]
                          : null,
                    ),
                    child: child,
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    Icon(listening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded, size: 40, color: Colors.black87),
                    const Positioned(left: 0, right: 60, top: 12, child: Icon(Icons.auto_awesome, size: 16, color: Colors.black87)),
                    const Positioned(left: 60, right: 0, bottom: 12, child: Icon(Icons.auto_awesome, size: 12, color: Colors.black87)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 18),
            _round(onTap: _settings, child: Icon(Icons.settings_outlined, color: AppColors.text, size: 30)),
          ]),
          const SizedBox(height: 18),
          Text(label, style: const TextStyle(color: Color(0xFF7FB0D8), fontSize: 19)),
        ]),
      ),
    );
  }

  Widget _round({required Widget child, required VoidCallback onTap}) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.dark ? const Color(0xFF1E1E21) : Colors.white,
            shape: BoxShape.circle,
          ),
          child: child,
        ),
      );

  void _settings() {
    final store = StoreScope.read(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Voice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (_lang.startsWith('en'))
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'en-GB', label: Text('🇬🇧 UK')),
                    ButtonSegment(value: 'en-US', label: Text('🇺🇸 US')),
                    ButtonSegment(value: 'en-AU', label: Text('🇦🇺 AU')),
                  ],
                  selected: {_lang},
                  onSelectionChanged: (s) {
                    setState(() => _lang = s.first);
                    store.accent = s.first;
                    store.touch();
                    set(() {});
                  },
                ),
              const SizedBox(height: 16),
              Text('Speed: ${store.speechRate.toStringAsFixed(1)}×'),
              Slider(
                value: store.speechRate,
                min: 0.5,
                max: 1.3,
                divisions: 8,
                onChanged: (v) {
                  store.speechRate = double.parse(v.toStringAsFixed(1));
                  store.touch();
                  set(() {});
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('🐢 Slow mode'),
                value: _slow,
                onChanged: (v) {
                  setState(() => _slow = v);
                  set(() {});
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
