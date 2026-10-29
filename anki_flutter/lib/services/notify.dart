import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:shared_preferences/shared_preferences.dart';

import '../store.dart';

/// Browser notifications and the calendar reminder. The JavaScript side
/// (`window.afNotify`) lives in web/index.html.
class Notify {
  static JSObject? get _js => globalContext.getProperty<JSObject?>('afNotify'.toJS);

  /// 'granted', 'denied', 'default' or 'unsupported'.
  static String get permission =>
      _js?.callMethod<JSString>('permission'.toJS).toDart ?? 'unsupported';

  static Future<String> requestPermission() async {
    final js = _js;
    if (js == null) return 'unsupported';
    final p = js.callMethod<JSPromise<JSString>>('request'.toJS);
    return (await p.toDart).toDart;
  }

  static Future<void> show(String title, String body) async {
    final js = _js;
    if (js == null) return;
    await js.callMethod<JSPromise<JSAny?>>('show'.toJS, title.toJS, body.toJS).toDart;
  }

  /// Saves an .ics file with a daily event and alert at [minutes] after midnight.
  /// Calendar on iPhone and Mac then reminds you even when the app is closed.
  static void downloadCalendarReminder(int minutes, String appName, String url) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final day = '${now.year}${two(now.month)}${two(now.day)}';
    final start = '${day}T${two(minutes ~/ 60)}${two(minutes % 60)}00';
    final stamp = now.toUtc();
    final dtstamp =
        '${stamp.year}${two(stamp.month)}${two(stamp.day)}T${two(stamp.hour)}${two(stamp.minute)}${two(stamp.second)}Z';
    final ics = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//$appName//Study reminder//EN',
      'CALSCALE:GREGORIAN',
      'BEGIN:VEVENT',
      'UID:study-reminder-${now.millisecondsSinceEpoch}@anki-flow',
      'DTSTAMP:$dtstamp',
      'DTSTART:$start',
      'DURATION:PT15M',
      'RRULE:FREQ=DAILY',
      'SUMMARY:Study your cards · $appName',
      'DESCRIPTION:Time for today\'s review. $url',
      'URL:$url',
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:Study your cards',
      'TRIGGER:PT0M',
      'END:VALARM',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
    _js?.callMethod('download'.toJS, 'study-reminder.ics'.toJS, ics.toJS, 'text/calendar'.toJS);
  }
}

/// While the app is open (or in a background tab), shows a notification at the
/// reminder time if today's goal isn't done yet. Once per day.
class ReminderService {
  ReminderService(this.store);
  final AppStore store;
  static const _key = 'anki_flow_last_reminder';
  Timer? _timer;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    _check();
  }

  Future<void> _check() async {
    if (!store.notifications || Notify.permission != 'granted') return;
    final now = DateTime.now();
    if (now.hour * 60 + now.minute < store.reminderMinutes) return;
    final prefs = await SharedPreferences.getInstance();
    final today = '${now.year}-${now.month}-${now.day}';
    if (prefs.getString(_key) == today) return;
    final left = store.queue().length;
    await prefs.setString(_key, today);
    if (left == 0) return;
    await Notify.show('Time to study', '$left cards are waiting for you today.');
  }
}
