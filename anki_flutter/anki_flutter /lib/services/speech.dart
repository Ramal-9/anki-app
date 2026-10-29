import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'pronunciation.dart' show SpeechAlternative;

export 'pronunciation.dart' show SpeechAlternative;

/// Thin wrapper over the browser Web Speech API:
/// `speechSynthesis` for native-speaker playback and
/// `SpeechRecognition` / `webkitSpeechRecognition` for the microphone.
///
/// Works in Chrome, Edge and Safari (iOS 14.5+). Firefox has TTS but no
/// recognition. The page must be served over HTTPS (GitHub Pages is).
class Speech {
  Speech._();
  static final instance = Speech._();

  JSObject? get _synth => globalContext.getProperty<JSObject?>('speechSynthesis'.toJS);

  bool get ttsSupported => _synth != null;

  JSFunction? get _recognitionCtor =>
      globalContext.getProperty<JSFunction?>('SpeechRecognition'.toJS) ??
      globalContext.getProperty<JSFunction?>('webkitSpeechRecognition'.toJS);

  bool get recognitionSupported => _recognitionCtor != null;

  JSObject? _recognition;

  // ------------------------------------------------------------------ TTS

  /// Voice name chosen by the user per accent ('' = automatic). Set from the store.
  Map<String, String> preferred = const {};

  List<JSObject> _allVoices() {
    final synth = _synth;
    if (synth == null) return const [];
    return synth.callMethod<JSArray<JSObject>>('getVoices'.toJS).toDart;
  }

  static String _norm(String lang) => lang.toLowerCase().replaceAll('_', '-');

  static VoiceInfo _info(JSObject v) => VoiceInfo(
        name: v.getProperty<JSString>('name'.toJS).toDart,
        lang: v.getProperty<JSString>('lang'.toJS).toDart,
        uri: v.getProperty<JSString?>('voiceURI'.toJS)?.toDart ?? '',
        local: v.getProperty<JSBoolean?>('localService'.toJS)?.toDart ?? true,
      );

  bool get _online => globalContext.getProperty<JSObject>('navigator'.toJS).getProperty<JSBoolean>('onLine'.toJS).toDart;

  /// Human-sounding voices for [lang], best first. Novelty and robotic voices
  /// (Eloquence, Fred, Zarvox, ...) are left out.
  List<VoiceInfo> voicesFor(String lang) {
    final want = _norm(lang);
    final online = _online;
    final list = <VoiceInfo>[];
    for (final v in _allVoices()) {
      final info = _info(v);
      if (_norm(info.lang) != want || info.robotic || list.any((v) => v.name == info.name)) continue;
      info.score = info.quality + (!info.local && !online ? -1000 : 0);
      list.add(info);
    }
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }

  JSObject? _voiceFor(String lang) {
    final all = _allVoices();
    var chosen = preferred[lang];
    if (chosen != null && chosen.startsWith('system:')) chosen = chosen.substring(7);
    final online = _online;
    if (chosen != null && chosen.isNotEmpty && !chosen.startsWith('online:')) {
      for (final v in all) {
        final info = _info(v);
        if (info.name == chosen && (info.local || online)) return v;
      }
    }
    final best = voicesFor(lang).firstOrNull;
    if (best != null && best.score > -1000) {
      return all.firstWhere((v) => _info(v).name == best.name);
    }
    // No proper voice for this accent: any non-robotic voice of the language.
    final base = _norm(lang).split('-').first;
    for (final v in all) {
      final info = _info(v);
      if (_norm(info.lang).split('-').first == base && !info.robotic && (info.local || online)) return v;
    }
    return null;
  }

  /// Fires when the browser finishes loading its voice list.
  void onVoicesChanged(void Function() callback) {
    _synth?.setProperty('onvoiceschanged'.toJS, ((JSAny? _) => callback()).toJS);
  }

  // ----------------------------------------------------------- online voices

  JSObject? get _tts => globalContext.getProperty<JSObject?>('afTts'.toJS);

  /// Free natural voices that need no account: Google's voice (accent by
  /// regional domain) and Amazon Polly voices served by StreamElements.
  static const pollyVoices = {
    'en-GB': ['Brian', 'Amy', 'Emma'],
    'en-US': ['Joanna', 'Matthew', 'Salli', 'Joey'],
    'en-AU': ['Russell', 'Nicole'],
  };

  static String _googleDomain(String lang) => switch (lang) {
        'en-GB' => 'co.uk',
        'en-AU' => 'com.au',
        'en-IN' => 'co.in',
        _ => 'com',
      };

  /// Splits text into pieces short enough for the online services (~180 chars).
  static List<String> chunks(String text, {int max = 180}) {
    final out = <String>[];
    var rest = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    while (rest.length > max) {
      var cut = -1;
      for (final sep in ['. ', '! ', '? ', '; ', ', ', ' ']) {
        final i = rest.lastIndexOf(sep, max);
        if (i > max ~/ 3) {
          cut = i + 1;
          break;
        }
      }
      if (cut <= 0) cut = max;
      out.add(rest.substring(0, cut).trim());
      rest = rest.substring(cut).trim();
    }
    if (rest.isNotEmpty) out.add(rest);
    return out;
  }

  static List<String> onlineUrls(String engine, String text, String lang) {
    final parts = chunks(text);
    if (engine.startsWith('online:polly:')) {
      final voice = engine.substring('online:polly:'.length);
      return [
        for (final p in parts)
          Uri.https('api.streamelements.com', '/kappa/v2/speech', {'voice': voice, 'text': p}).toString()
      ];
    }
    final tl = lang.split('-').first;
    return [
      for (final p in parts)
        Uri.https('translate.google.${_googleDomain(lang)}', '/translate_tts',
            {'ie': 'UTF-8', 'client': 'tw-ob', 'tl': tl, 'q': p}).toString()
    ];
  }

  Future<bool> _playOnline(String engine, String text, String lang, double rate) async {
    final tts = _tts;
    if (tts == null || !_online) return false;
    final urls = onlineUrls(engine, text, lang).map((u) => u.toJS).toList().toJS;
    try {
      final ok = await tts.callMethod<JSPromise<JSBoolean>>('play'.toJS, urls, rate.toJS).toDart;
      return ok.toDart;
    } catch (_) {
      return false;
    }
  }

  /// Engines tried in order for [lang]: the chosen one first, then the
  /// natural online voices, then the voices installed on the device.
  List<String> _engines(String lang) {
    final chosen = preferred[lang] ?? '';
    final firstPolly = pollyVoices[lang]?.first;
    return {
      if (chosen.startsWith('online:')) chosen,
      if (!chosen.startsWith('system:')) ...[
        'online:google',
        if (firstPolly != null) 'online:polly:$firstPolly',
      ],
    }.toList();
  }

  /// Speaks [text]; completes when playback ends (or fails).
  Future<void> speak(String text, {String lang = 'en-GB', double rate = 0.9}) async {
    if (text.trim().isEmpty) return;
    stopSpeaking();
    for (final engine in _engines(lang)) {
      if (await _playOnline(engine, text, lang, rate)) return;
    }
    await _speakSystem(text, lang, rate);
  }

  /// Plays [text] with one specific engine (used by the voice picker).
  Future<void> preview(String engine, String text, String lang, double rate) async {
    stopSpeaking();
    if (engine.startsWith('online:')) {
      if (await _playOnline(engine, text, lang, rate)) return;
      return;
    }
    final saved = preferred;
    preferred = {...saved, lang: engine};
    await _speakSystem(text, lang, rate);
    preferred = saved;
  }

  Future<void> _speakSystem(String text, String lang, double rate) {
    final synth = _synth;
    if (synth == null) return Future.value();
    synth.callMethod('cancel'.toJS);
    final ctor = globalContext.getProperty<JSFunction>('SpeechSynthesisUtterance'.toJS);
    final u = ctor.callAsConstructor<JSObject>(text.toJS);
    u.setProperty('lang'.toJS, lang.toJS);
    u.setProperty('rate'.toJS, rate.toJS);
    final voice = _voiceFor(lang);
    if (voice != null) {
      u.setProperty('voice'.toJS, voice);
      u.setProperty('lang'.toJS, voice.getProperty<JSString>('lang'.toJS));
    }
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    u.setProperty('onend'.toJS, ((JSAny? _) => finish()).toJS);
    u.setProperty('onerror'.toJS, ((JSAny? _) => finish()).toJS);
    synth.callMethod('speak'.toJS, u);
    // Safety net: some browsers never fire onend.
    Future.delayed(Duration(milliseconds: 1500 + text.length * 120), finish);
    return done.future;
  }

  void stopSpeaking() {
    _synth?.callMethod('cancel'.toJS);
    _tts?.callMethod('stop'.toJS);
  }

  /// Chrome loads voices lazily; call once early so the first speak() has them.
  void warmUp() => _synth?.callMethod('getVoices'.toJS);

  // ---------------------------------------------------------- recognition

  /// Finishes the current listening session (with what was heard so far).
  void Function()? _finishCurrent;

  /// Listens once. Emits partial transcripts through [onPartial] and resolves
  /// with all final alternatives (best first). Throws [SpeechError].
  ///
  /// Safari on iPhone sometimes never fires `onend` or never marks a result as
  /// final, especially on a second attempt; so the recognizer is reused, the
  /// last partial transcript counts as the answer, and timers make sure every
  /// session ends.
  Future<List<SpeechAlternative>> listen({
    String lang = 'en-GB',
    void Function(String partial)? onPartial,
  }) {
    final ctor = _recognitionCtor;
    if (ctor == null) {
      return Future.error(SpeechError('not-supported'));
    }
    stopSpeaking();
    // End any previous session before starting a new one.
    _finishCurrent?.call();
    final old = _recognition;
    if (old != null) {
      for (final h in ['onresult', 'onerror', 'onend', 'onspeechend']) {
        old.setProperty(h.toJS, null);
      }
      try {
        old.callMethod('abort'.toJS);
      } catch (_) {}
    }
    final rec = ctor.callAsConstructor<JSObject>();
    _recognition = rec;
    rec.setProperty('lang'.toJS, lang.toJS);
    rec.setProperty('interimResults'.toJS, true.toJS);
    rec.setProperty('continuous'.toJS, false.toJS);
    rec.setProperty('maxAlternatives'.toJS, 5.toJS);

    final completer = Completer<List<SpeechAlternative>>();
    var finals = <SpeechAlternative>[];
    var lastPartial = '';
    Timer? silence;
    Timer? hardStop;
    Timer? forceEnd;

    void finish({String? error}) {
      silence?.cancel();
      hardStop?.cancel();
      forceEnd?.cancel();
      if (identical(_recognition, rec)) {
        _recognition = null;
        _finishCurrent = null;
        _stopCurrent = null;
      }
      if (completer.isCompleted) return;
      if (finals.isEmpty && lastPartial.isNotEmpty) finals = [SpeechAlternative(lastPartial, 0.5)];
      if (finals.isNotEmpty) {
        completer.complete(finals);
      } else {
        completer.completeError(SpeechError(error ?? 'no-speech'));
      }
    }

    // Ask the recognizer to stop; if it doesn't end by itself, finish anyway.
    void stopSoon() {
      try {
        rec.callMethod('stop'.toJS);
      } catch (_) {}
      forceEnd ??= Timer(const Duration(milliseconds: 1500), () {
        try {
          rec.callMethod('abort'.toJS);
        } catch (_) {}
        finish();
      });
    }

    _finishCurrent = () => finish(error: 'aborted');
    _stopCurrent = stopSoon;

    void armSilence(Duration d) {
      silence?.cancel();
      silence = Timer(d, stopSoon);
    }

    rec.setProperty(
        'onresult'.toJS,
        ((JSObject event) {
          final results = event.getProperty<JSObject>('results'.toJS);
          final len = results.getProperty<JSNumber>('length'.toJS).toDartInt;
          final interim = StringBuffer();
          final alts = <SpeechAlternative>[];
          for (var i = 0; i < len; i++) {
            final result = results.callMethod<JSObject>('item'.toJS, i.toJS);
            final isFinal = result.getProperty<JSBoolean>('isFinal'.toJS).toDart;
            final n = result.getProperty<JSNumber>('length'.toJS).toDartInt;
            final first = result.callMethod<JSObject>('item'.toJS, 0.toJS);
            interim.write(first.getProperty<JSString>('transcript'.toJS).toDart);
            if (isFinal) {
              for (var a = 0; a < n; a++) {
                final alt = result.callMethod<JSObject>('item'.toJS, a.toJS);
                alts.add(SpeechAlternative(
                  alt.getProperty<JSString>('transcript'.toJS).toDart.trim(),
                  alt.getProperty<JSNumber?>('confidence'.toJS)?.toDartDouble ?? 0,
                ));
              }
            }
          }
          lastPartial = interim.toString().trim();
          onPartial?.call(lastPartial);
          if (alts.isNotEmpty) {
            finals = alts;
            stopSoon();
          } else {
            // Speech is coming in: stop after a pause of ~1.8 s.
            armSilence(const Duration(milliseconds: 1800));
          }
        }).toJS);

    rec.setProperty(
        'onerror'.toJS,
        ((JSObject event) {
          final code = event.getProperty<JSString?>('error'.toJS)?.toDart ?? 'unknown';
          if (code == 'no-speech' || code == 'aborted') {
            finish();
          } else if (!completer.isCompleted) {
            silence?.cancel();
            hardStop?.cancel();
            forceEnd?.cancel();
            if (identical(_recognition, rec)) _recognition = null;
            completer.completeError(SpeechError(code));
          }
        }).toJS);

    rec.setProperty('onend'.toJS, ((JSAny? _) => finish()).toJS);

    try {
      rec.callMethod('start'.toJS);
    } catch (e) {
      finish(error: 'busy');
      return completer.future;
    }
    armSilence(const Duration(seconds: 8)); // nothing heard at all
    hardStop = Timer(const Duration(seconds: 20), stopSoon);
    return completer.future;
  }

  void Function()? _stopCurrent;

  /// Stops listening and lets the recognizer deliver what it heard.
  void stopListening() {
    final stop = _stopCurrent;
    if (_recognition != null && stop != null) stop();
  }
}

/// A browser voice with a rough naturalness rating.
class VoiceInfo {
  VoiceInfo({required this.name, required this.lang, required this.uri, required this.local});
  final String name, lang, uri;

  /// False for cloud voices (Google, Microsoft Online) that need internet.
  final bool local;
  int score = 0;

  // macOS / iOS novelty voices and the Eloquence engine sound robotic.
  static const _robotic = {
    'albert', 'bad news', 'bahh', 'bells', 'boing', 'bubbles', 'cellos', 'good news', 'jester', 'organ',
    'pipe organ', 'superstar', 'trinoids', 'whisper', 'wobble', 'zarvox', 'fred', 'junior', 'ralph', 'kathy',
    'princess', 'deranged', 'hysterical', 'eddy', 'flo', 'grandma', 'grandpa', 'reed', 'rocko', 'sandy',
    'shelley', 'agnes', 'bruce', 'vicki', 'victoria',
  };

  // Voices that sound natural and pronounce English correctly.
  static const _good = {
    // UK
    'daniel', 'serena', 'kate', 'oliver', 'jamie', 'stephanie', 'arthur', 'martha', 'sonia', 'ryan', 'libby',
    'maisie', 'thomas', 'abbi', 'alfie', 'bella', 'elliot', 'ethan', 'hollie', 'noah', 'olivia',
    // US
    'samantha', 'ava', 'allison', 'evan', 'nathan', 'zoe', 'tom', 'susan', 'joelle', 'noelle', 'nicky', 'aaron',
    'jenny', 'aria', 'guy', 'michelle', 'ana', 'christopher', 'eric', 'roger', 'steffan', 'emma', 'brian',
    'andrew', 'davis', 'jane', 'jason', 'nancy', 'sara', 'tony',
    // AU
    'karen', 'lee', 'matilda', 'natasha', 'william',
  };

  String get _base => name.toLowerCase().split(RegExp(r'[ (]')).first;

  bool get robotic {
    final u = uri.toLowerCase();
    if (u.contains('eloquence') || u.contains('speech.synthesis.voice')) return true;
    final n = name.toLowerCase();
    return _robotic.contains(_base) || _robotic.contains(n.split(' (').first) || n.contains('novelty');
  }

  /// Higher is more natural.
  int get quality {
    final n = name.toLowerCase();
    final u = uri.toLowerCase();
    var q = 0;
    if (n.contains('premium') || u.contains('.premium.')) q += 60;
    if (n.contains('enhanced') || u.contains('.enhanced.')) q += 45;
    if (n.contains('natural') || n.contains('neural')) q += 55;
    if (n.contains('siri')) q += 40;
    if (n.startsWith('google')) q += 30;
    if (_good.contains(_base) || n.contains('microsoft $_base')) q += 20;
    if (n.startsWith('microsoft') && !n.contains('online')) q -= 10; // older desktop SAPI voices
    if (!local) q -= 2; // all else equal, prefer offline voices
    return q;
  }

  String get label {
    final q = quality;
    if (q >= 55) return 'Premium · natural';
    if (q >= 40) return 'Enhanced';
    if (q >= 20) return 'Good';
    return 'Standard';
  }

  String get shortName => name
      .replaceAll(RegExp(r'^(Microsoft|Google)\s+'), '')
      .replaceAll(RegExp(r'\s+Online \(Natural\)'), ' (Natural)')
      .replaceAll(RegExp(r'\s+-\s+English.*$'), '');
}

class SpeechError implements Exception {
  SpeechError(this.code);
  final String code;

  /// Human-readable explanation (Russian UI strings are kept short).
  String get message => switch (code) {
        'not-supported' =>
          'This browser has no speech recognition. Open the app in Chrome, Edge or Safari.',
        'not-allowed' || 'service-not-allowed' =>
          'Microphone access is blocked. Allow the microphone for this site and try again.',
        'no-speech' => "Didn't hear anything. Tap the mic and speak a bit louder.",
        'audio-capture' => 'No microphone found.',
        'network' => 'Speech service is unreachable. Check your connection.',
        'aborted' => 'Listening stopped.',
        'busy' => 'The microphone is busy. Wait a second and tap again.',
        _ => 'Speech recognition error: $code',
      };

  @override
  String toString() => message;
}
