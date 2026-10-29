/// Merges two sync payloads (see `AppStore.syncJson`) so that no device loses work.
///
/// * Decks and cards: union by id; when both sides have one, the later
///   `modified` wins. Anything with a newer tombstone is dropped.
/// * Tombstones: union, latest time wins.
/// * Review logs: union (de-duplicated by card id + time).
/// * Settings: the side with the later `settingsModified` wins.
Map<String, dynamic> mergeSyncPayloads(Map<String, dynamic> a, Map<String, dynamic> b) {
  DateTime t(Object? v) => v == null ? DateTime(2000) : DateTime.parse(v as String);

  final deleted = <String, DateTime>{};
  for (final side in [a, b]) {
    ((side['deleted'] as Map?) ?? {}).forEach((k, v) {
      final time = t(v);
      final cur = deleted[k as String];
      if (cur == null || time.isAfter(cur)) deleted[k] = time;
    });
  }

  List<Map<String, dynamic>> mergeById(String key) {
    final byId = <String, Map<String, dynamic>>{};
    for (final side in [a, b]) {
      for (final raw in (side[key] as List?) ?? const []) {
        final item = Map<String, dynamic>.from(raw as Map);
        final id = item['id'] as String;
        final cur = byId[id];
        if (cur == null || t(item['modified']).isAfter(t(cur['modified']))) byId[id] = item;
      }
    }
    byId.removeWhere((id, item) {
      final gone = deleted[id];
      return gone != null && !t(item['modified']).isAfter(gone);
    });
    return byId.values.toList();
  }

  final decks = mergeById('decks');
  final deckIds = decks.map((d) => d['id']).toSet();
  final cards = mergeById('cards').where((c) => deckIds.contains(c['deckId'])).toList();

  final logs = <String, Map<String, dynamic>>{};
  for (final side in [a, b]) {
    for (final raw in (side['logs'] as List?) ?? const []) {
      final l = Map<String, dynamic>.from(raw as Map);
      logs['${l['c']}|${l['t']}'] = l;
    }
  }
  final mergedLogs = logs.values.toList()..sort((x, y) => (x['t'] as String).compareTo(y['t'] as String));

  final aNewer = t(a['settingsModified']).isAfter(t(b['settingsModified']));
  final settingsSide = aNewer ? a : b;

  return {
    'decks': decks,
    'cards': cards,
    'logs': mergedLogs,
    'deleted': deleted.map((k, v) => MapEntry(k, v.toIso8601String())),
    'settings': settingsSide['settings'] ?? const {},
    'settingsModified': settingsSide['settingsModified'],
  };
}
