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

  /// Picks the best installed voice for [lang], preferring natural/enhanced ones.
  JSObject? _voiceFor(String lang) {
    final synth = _synth;
    if (synth == null) return null;
    final list = synth.callMethod<JSArray<JSObject>>('getVoices'.toJS).toDart;
    JSObject? best;
    var bestScore = -1;
    final want = lang.toLowerCase().replaceAll('_', '-');
    for (final v in list) {
      final vl = (v.getProperty<JSString>('lang'.toJS)).toDart.toLowerCase().replaceAll('_', '-');
      final name = (v.getProperty<JSString>('name'.toJS)).toDart.toLowerCase();
      var score = 0;
      if (vl == want) {
        score = 10;
      } else if (vl.split('-').first == want.split('-').first) {
        score = 4;
      } else {
        continue;
      }
      if (name.contains('natural') || name.contains('enhanced') || name.contains('premium')) score += 3;
      if (name.contains('google')) score += 2;
      if (name.contains('daniel') || name.contains('samantha') || name.contains('serena')) score += 1;
      if (score > bestScore) {
        bestScore = score;
        best = v;
      }
    }
    return best;
  }

  /// Speaks [text]; completes when playback ends (or fails).
  Future<void> speak(String text, {String lang = 'en-GB', double rate = 0.9}) {
    final synth = _synth;
    if (synth == null || text.trim().isEmpty) return Future.value();
    synth.callMethod('cancel'.toJS);
    final ctor = globalContext.getProperty<JSFunction>('SpeechSynthesisUtterance'.toJS);
    final u = ctor.callAsConstructor<JSObject>(text.toJS);
    u.setProperty('lang'.toJS, lang.toJS);
    u.setProperty('rate'.toJS, rate.toJS);
    final voice = _voiceFor(lang);
    if (voice != null) u.setProperty('voice'.toJS, voice);
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

  void stopSpeaking() => _synth?.callMethod('cancel'.toJS);

  /// Chrome loads voices lazily; call once early so the first speak() has them.
  void warmUp() => _synth?.callMethod('getVoices'.toJS);

  // ---------------------------------------------------------- recognition

  /// Listens once. Emits partial transcripts through [onPartial] and resolves
  /// with all final alternatives (best first). Throws [SpeechError].
  Future<List<SpeechAlternative>> listen({
    String lang = 'en-GB',
    void Function(String partial)? onPartial,
  }) {
    final ctor = _recognitionCtor;
    if (ctor == null) {
      return Future.error(SpeechError('not-supported'));
    }
    stopSpeaking();
    final rec = ctor.callAsConstructor<JSObject>();
    _recognition = rec;
    rec.setProperty('lang'.toJS, lang.toJS);
    rec.setProperty('interimResults'.toJS, true.toJS);
    rec.setProperty('continuous'.toJS, false.toJS);
    rec.setProperty('maxAlternatives'.toJS, 5.toJS);

    final completer = Completer<List<SpeechAlternative>>();
    var finals = <SpeechAlternative>[];

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
          onPartial?.call(interim.toString().trim());
          if (alts.isNotEmpty) finals = alts;
        }).toJS);

    rec.setProperty(
        'onerror'.toJS,
        ((JSObject event) {
          final code = event.getProperty<JSString?>('error'.toJS)?.toDart ?? 'unknown';
          if (!completer.isCompleted) completer.completeError(SpeechError(code));
        }).toJS);

    rec.setProperty(
        'onend'.toJS,
        ((JSAny? _) {
          _recognition = null;
          if (completer.isCompleted) return;
          if (finals.isEmpty) {
            completer.completeError(SpeechError('no-speech'));
          } else {
            completer.complete(finals);
          }
        }).toJS);

    rec.callMethod('start'.toJS);
    return completer.future;
  }

  /// Stops listening and lets the recognizer deliver what it heard.
  void stopListening() => _recognition?.callMethod('stop'.toJS);
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
        _ => 'Speech recognition error: $code',
      };

  @override
  String toString() => message;
}
