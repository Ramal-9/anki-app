import 'package:flutter/material.dart';

import '../display.dart';
import '../main.dart';
import '../services/speech.dart';
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

  Future<void> _play(String lang, String? voice, double rate) async {
    final speech = Speech.instance;
    final saved = speech.preferred;
    setState(() => _playing = voice ?? '');
    speech.preferred = {...saved, lang: voice ?? ''};
    await speech.speak(_samples[lang]!, lang: lang, rate: rate);
    speech.preferred = saved;
    if (mounted) setState(() => _playing = null);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final lang = store.accent;
    final voices = Speech.instance.voicesFor(lang);
    final chosen = store.voices[lang] ?? '';
    final auto = voices.firstOrNull;
    final hasNatural = voices.any((v) => v.quality >= 40);

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
            SectionLabel('${kAccents[lang]} voices on this device', padding: const EdgeInsets.fromLTRB(40, 20, 20, 10)),
            Panel(children: [
              _VoiceRow(
                title: 'Automatic',
                subtitle: auto == null ? 'No ${kAccents[lang]} voice found' : 'Best available · ${auto.shortName}',
                selected: chosen.isEmpty || !voices.any((v) => v.name == chosen),
                playing: _playing == '',
                onTap: () {
                  store.voices.remove(lang);
                  store.touchDevice();
                },
                onPlay: () => _play(lang, null, store.speechRate),
              ),
              for (final v in voices)
                _VoiceRow(
                  title: v.shortName,
                  subtitle: '${v.label}${v.local ? '' : ' · needs internet'}',
                  selected: chosen == v.name,
                  playing: _playing == v.name,
                  onTap: () {
                    store.voices[lang] = v.name;
                    store.touchDevice();
                  },
                  onPlay: () => _play(lang, v.name, store.speechRate),
                ),
            ]),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.download_rounded, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(hasNatural ? 'Want even better voices?' : 'Get natural native voices',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(
                  'The app uses the voices installed on your device. Apple\'s Premium and Enhanced voices sound '
                  'like real people and work offline.\n\n'
                  'iPhone: Settings → Accessibility → Spoken Content → Voices → English. '
                  'Download for UK: Serena (Premium) or Daniel (Enhanced); for US: Ava (Premium), Zoe (Premium) '
                  'or Evan (Enhanced). Then close and reopen the app.\n\n'
                  'Mac: System Settings → Accessibility → Spoken Content → System voice → Manage Voices… → '
                  'English (United Kingdom / United States), download the same voices, then restart the browser.\n\n'
                  'In Edge on Mac/Windows the Microsoft "Natural" voices (Sonia, Ryan, Jenny, Guy) are also excellent '
                  'but need internet.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.45),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
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
