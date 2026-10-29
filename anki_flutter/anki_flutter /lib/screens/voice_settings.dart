import 'package:flutter/material.dart';

import '../display.dart';
import '../main.dart';
import '../services/speech.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'settings_pages.dart';

const kAccents = {'en-GB': 'UK', 'en-US': 'US', 'en-AU': 'AU'};

const _samples = {
  'en-GB': 'I can\'t afford a new car at the moment, but I\'m saving up.',
  'en-US': 'I can\'t afford a new car right now, but I\'m saving up.',
  'en-AU': 'I can\'t afford a new car at the moment, but I\'m saving up.',
};

/// Profile → Voice: accent, speed and the native-speaker voice for each accent.
class VoiceSettingsScreen extends StatefulWidget {
  const VoiceSettingsScreen({super.key});

  @override
  State<VoiceSettingsScreen> createState() => _VoiceSettingsScreenState();
}

class _VoiceSettingsScreenState extends State<VoiceSettingsScreen> {
  String? _playing;

  @override
  void initState() {
    super.initState();
    Speech.instance.onVoicesChanged(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _play(String lang, String engine, double rate) async {
    setState(() => _playing = engine);
    if (engine.isEmpty) {
      await Speech.instance.speak(_samples[lang]!, lang: lang, rate: rate);
    } else {
      await Speech.instance.preview(engine, _samples[lang]!, lang, rate);
    }
    if (mounted) setState(() => _playing = null);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final lang = store.accent;
    final voices = Speech.instance.voicesFor(lang);
    final chosen = store.voices[lang] ?? '';

    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            const SubPageHeader(title: 'Voice'),
            const SectionLabel('Accent', padding: EdgeInsets.fromLTRB(40, 24, 20, 10)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: [
                  for (final e in kAccents.entries) ButtonSegment(value: e.key, label: Text(e.value)),
                ],
                selected: {lang},
                onSelectionChanged: (v) => store
                  ..accent = v.first
                  ..touch(),
              ),
            ),
            const SectionLabel('Speed', padding: EdgeInsets.fromLTRB(40, 24, 20, 4)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Icon(Icons.speed_rounded, color: AppColors.accent),
                Expanded(
                  child: Slider(
                    value: store.speechRate,
                    min: 0.5,
                    max: 1.3,
                    divisions: 8,
                    onChanged: (v) => store
                      ..speechRate = double.parse(v.toStringAsFixed(1))
                      ..touch(),
                  ),
                ),
                Text('${store.speechRate.toStringAsFixed(1)}×', style: const TextStyle(fontSize: 17)),
              ]),
            ),
            const SectionLabel('Natural voices · free, online', padding: EdgeInsets.fromLTRB(40, 20, 20, 10)),
            Panel(children: [
              _VoiceRow(
                title: 'Automatic',
                subtitle: 'Natural voice online, device voice offline',
                selected: chosen.isEmpty,
                playing: _playing == '',
                onTap: () {
                  store.voices.remove(lang);
                  store.touchDevice();
                },
                onPlay: () => _play(lang, '', store.speechRate),
              ),
              _VoiceRow(
                title: 'Google · ${kAccents[lang]} English',
                subtitle: 'Natural, clear pronunciation',
                selected: chosen == 'online:google',
                playing: _playing == 'online:google',
                onTap: () => _choose(store, lang, 'online:google'),
                onPlay: () => _play(lang, 'online:google', store.speechRate),
              ),
              for (final name in Speech.pollyVoices[lang] ?? const <String>[])
                _VoiceRow(
                  title: name,
                  subtitle: 'Amazon Polly · ${kAccents[lang]} English',
                  selected: chosen == 'online:polly:$name',
                  playing: _playing == 'online:polly:$name',
                  onTap: () => _choose(store, lang, 'online:polly:$name'),
                  onPlay: () => _play(lang, 'online:polly:$name', store.speechRate),
                ),
            ]),
            SectionLabel('Voices on this device · offline', padding: const EdgeInsets.fromLTRB(40, 24, 20, 10)),
            Panel(children: [
              if (voices.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No ${kAccents[lang]} voice on this device.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                ),
              for (final v in voices)
                _VoiceRow(
                  title: v.shortName,
                  subtitle: '${v.label}${v.local ? '' : ' · needs internet'}',
                  selected: chosen == 'system:${v.name}' || chosen == v.name,
                  playing: _playing == 'system:${v.name}',
                  onTap: () => _choose(store, lang, 'system:${v.name}'),
                  onPlay: () => _play(lang, 'system:${v.name}', store.speechRate),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
              child: Text(
                'Natural voices are free and need no account, only internet. Without internet the app '
                'automatically uses a voice of this device.\n\n'
                'Safari on iPhone only lets websites use a few built-in voices, so voices downloaded in iPhone '
                'Settings do not appear here. That is why the online voices are the default.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.45),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

void _choose(AppStore store, String lang, String engine) {
  store.voices[lang] = engine;
  store.touchDevice();
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.playing,
    required this.onTap,
    required this.onPlay,
  });
  final String title, subtitle;
  final bool selected, playing;
  final VoidCallback onTap, onPlay;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
        child: Row(children: [
          IconButton(
            onPressed: onPlay,
            icon: Icon(playing ? Icons.graphic_eq_rounded : Icons.play_circle_outline_rounded,
                color: AppColors.accent, size: 30),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18)),
              Text(subtitle, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ]),
          ),
          if (selected) const Icon(Icons.check_rounded, color: AppColors.accent, size: 26),
        ]),
      ),
    );
  }
}
