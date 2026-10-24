import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../store.dart';
import 'sync_crypto.dart';
import 'sync_merge.dart';

enum SyncStatus { off, idle, syncing, error }

/// End-to-end encrypted sync between devices through a secret GitHub Gist.
///
/// * Your decks, cards and history are encrypted on the device with
///   AES-256-GCM. The key is derived from your sync password with
///   PBKDF2-SHA256 (210 000 rounds) and never leaves the device.
/// * GitHub only stores ciphertext in a secret gist of your own account.
/// * The access token only needs the `gist` scope.
/// * Changes from both devices are merged (see [mergeSyncPayloads]).
class SyncService extends ChangeNotifier {
  SyncService(this.store);

  /// Created in main().
  static late SyncService instance;

  final AppStore store;

  static const _prefsKey = 'anki_flow_sync_v1';
  static const fileName = 'anki-flow-sync.json';

  String? _token;
  String? _gistId;
  List<int>? _key;
  String? _salt;
  String? login;

  SyncStatus status = SyncStatus.off;
  DateTime? lastSync;
  String? error;

  Timer? _debounce;
  Timer? _periodic;
  bool _pending = false;

  bool get enabled => _token != null && _gistId != null && _key != null;

  // ------------------------------------------------------------ lifecycle

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        final j = jsonDecode(raw);
        _token = j['token'];
        _gistId = j['gistId'];
        _key = base64Decode(j['key']);
        _salt = j['salt'];
        login = j['login'];
        lastSync = j['lastSync'] == null ? null : DateTime.parse(j['lastSync']);
        status = SyncStatus.idle;
      } catch (_) {}
    }
    store.onLocalChange = _scheduleSync;
    if (enabled) {
      _startPeriodic();
      unawaited(syncNow());
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (!enabled) {
      await prefs.remove(_prefsKey);
      return;
    }
    await prefs.setString(
        _prefsKey,
        jsonEncode({
          'token': _token,
          'gistId': _gistId,
          'key': base64Encode(_key!),
          'salt': _salt,
          'login': login,
          'lastSync': lastSync?.toIso8601String(),
        }));
  }

  void _startPeriodic() {
    _periodic?.cancel();
    _periodic = Timer.periodic(const Duration(minutes: 2), (_) => syncNow());
  }

  void _scheduleSync() {
    if (!enabled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), syncNow);
  }

  /// Call when the app comes back to the foreground or the network returns.
  void nudge() {
    if (enabled) unawaited(syncNow());
  }

  // ------------------------------------------------------------- crypto

  static Future<List<int>> deriveKey(String password, List<int> salt) => SyncCrypto.deriveKey(password, salt);
  static Future<Map<String, dynamic>> encrypt(List<int> key, String salt, String plain) =>
      SyncCrypto.encrypt(key, salt, plain);
  static Future<String> decrypt(List<int> key, Map<String, dynamic> env) => SyncCrypto.decrypt(key, env);
  static List<int> _randomBytes(int n) => SyncCrypto.randomBytes(n);

  // ------------------------------------------------------------- github

  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  Future<http.Response> _gh(String method, String path, String token, {Object? body}) async {
    final uri = Uri.parse('https://api.github.com$path');
    final headers = {..._headers(token), if (body != null) 'Content-Type': 'application/json'};
    final res = switch (method) {
      'GET' => await http.get(uri, headers: headers),
      'POST' => await http.post(uri, headers: headers, body: jsonEncode(body)),
      _ => await http.patch(uri, headers: headers, body: jsonEncode(body)),
    };
    if (res.statusCode == 401) throw SyncException('GitHub rejected the token. Create a new one with the "gist" scope.');
    if (res.statusCode == 403 || res.statusCode == 404) {
      throw SyncException('No access to gists. Make sure the token has the "gist" scope.');
    }
    if (res.statusCode >= 400) throw SyncException('GitHub error ${res.statusCode}');
    return res;
  }

  /// Reads the encrypted envelope from the gist (null when the file is missing).
  Future<Map<String, dynamic>?> _readEnvelope(String token, String gistId) async {
    final res = await _gh('GET', '/gists/$gistId', token);
    final file = (jsonDecode(res.body)['files'] as Map)[fileName];
    if (file == null) return null;
    var content = file['content'] as String?;
    if (file['truncated'] == true || content == null) {
      content = (await http.get(Uri.parse(file['raw_url']))).body;
    }
    return jsonDecode(content);
  }

  Future<String?> _findGist(String token) async {
    for (var page = 1; page <= 5; page++) {
      final res = await _gh('GET', '/gists?per_page=100&page=$page', token);
      final list = jsonDecode(res.body) as List;
      for (final g in list) {
        if ((g['files'] as Map).containsKey(fileName)) return g['id'];
      }
      if (list.length < 100) break;
    }
    return null;
  }

  // -------------------------------------------------------------- setup

  /// Connects this device. Finds the existing sync gist of the account or
  /// creates a new one. Throws [SyncException] on a wrong password or token.
  Future<void> connect({required String token, required String password}) async {
    token = token.trim();
    if (password.length < 8) throw SyncException('Use a sync password of at least 8 characters.');
    final user = jsonDecode((await _gh('GET', '/user', token)).body);
    final gistId = await _findGist(token);
    if (gistId != null) {
      final env = await _readEnvelope(token, gistId);
      if (env == null) throw SyncException('The sync gist is damaged. Delete it on GitHub and try again.');
      final key = await deriveKey(password, base64Decode(env['salt']));
      final String remote;
      try {
        remote = await decrypt(key, env);
      } catch (_) {
        throw SyncException('Wrong sync password for the existing sync data.');
      }
      // A fresh device only has the demo decks: take the synced data as is
      // instead of adding a second copy of the demo decks.
      if (store.onlyDemoData) store.replaceFromSync(jsonDecode(remote));
      _set(token, gistId, key, env['salt'], user['login']);
    } else {
      final salt = base64Encode(_randomBytes(16));
      final key = await deriveKey(password, base64Decode(salt));
      final env = await encrypt(key, salt, jsonEncode(store.syncJson()));
      final res = await _gh('POST', '/gists', token, body: {
        'description': 'Anki Flow sync (end-to-end encrypted)',
        'public': false,
        'files': {
          fileName: {'content': jsonEncode(env)}
        },
      });
      _set(token, jsonDecode(res.body)['id'], key, salt, user['login']);
    }
    await _persist();
    _startPeriodic();
    await syncNow();
  }

  void _set(String token, String gistId, List<int> key, String salt, String? user) {
    _token = token;
    _gistId = gistId;
    _key = key;
    _salt = salt;
    login = user;
    status = SyncStatus.idle;
    error = null;
  }

  /// A code to paste on the other device instead of the token. The token
  /// inside is encrypted with the sync key, so the code is useless without
  /// the sync password.
  Future<String> exportSetupCode() async {
    final env = await encrypt(_key!, _salt!, jsonEncode({'t': _token, 'g': _gistId}));
    return 'AFSYNC1.${base64Url.encode(utf8.encode(jsonEncode(env)))}';
  }

  Future<void> connectWithCode({required String code, required String password}) async {
    code = code.trim();
    if (!code.startsWith('AFSYNC1.')) throw SyncException('This is not an Anki Flow setup code.');
    final Map<String, dynamic> env;
    try {
      env = jsonDecode(utf8.decode(base64Url.decode(code.substring(8))));
    } catch (_) {
      throw SyncException('The setup code is incomplete. Copy it again.');
    }
    final key = await deriveKey(password, base64Decode(env['salt']));
    final Map<String, dynamic> inner;
    try {
      inner = jsonDecode(await decrypt(key, env));
    } catch (_) {
      throw SyncException('Wrong sync password.');
    }
    await connect(token: inner['t'], password: password);
  }

  Future<void> disconnect() async {
    _periodic?.cancel();
    _debounce?.cancel();
    _token = _gistId = _key = _salt = login = null;
    status = SyncStatus.off;
    lastSync = null;
    error = null;
    await _persist();
    notifyListeners();
  }

  // --------------------------------------------------------------- sync

  Future<void> syncNow() async {
    if (!enabled) return;
    if (status == SyncStatus.syncing) {
      _pending = true;
      return;
    }
    status = SyncStatus.syncing;
    notifyListeners();
    try {
      final env = await _readEnvelope(_token!, _gistId!);
      final local = store.syncJson();
      Map<String, dynamic> merged = local;
      String? remotePlain;
      if (env != null) {
        remotePlain = await decrypt(_key!, env);
        merged = mergeSyncPayloads(local, jsonDecode(remotePlain));
      }
      final mergedText = jsonEncode(merged);
      if (mergedText != jsonEncode(local)) store.replaceFromSync(merged);
      if (remotePlain == null || mergedText != remotePlain) {
        final out = await encrypt(_key!, _salt!, mergedText);
        await _gh('PATCH', '/gists/$_gistId', _token!, body: {
          'files': {
            fileName: {'content': jsonEncode(out)}
          }
        });
      }
      lastSync = DateTime.now();
      status = SyncStatus.idle;
      error = null;
      await _persist();
    } on SyncException catch (e) {
      status = SyncStatus.error;
      error = e.message;
    } on SecretBoxAuthenticationError {
      status = SyncStatus.error;
      error = 'Could not decrypt the sync data. The sync password was changed on another device: reconnect.';
    } catch (e) {
      status = SyncStatus.error;
      error = 'Offline — will sync when the connection is back.';
      if (kDebugMode) debugPrint('sync failed: $e');
    }
    notifyListeners();
    if (_pending) {
      _pending = false;
      unawaited(syncNow());
    }
  }
}

class SyncException implements Exception {
  SyncException(this.message);
  final String message;
  @override
  String toString() => message;
}
