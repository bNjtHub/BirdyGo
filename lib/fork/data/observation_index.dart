/// Observation index: a derived SQLite view of every detection in every
/// saved session.
///
/// Session JSON files stay the source of truth. This index only exists so
/// that the palmarès, the map, the sound library and the review queue can
/// count and filter detections without re-reading every JSON file. It can be
/// dropped and rebuilt from the sessions at any time; only [favorites] live
/// here alone, keyed by a stable detection key so they survive a rebuild.
library;

import 'package:sqflite/sqflite.dart';

import '../../features/live/live_session.dart';

/// One detection row, flattened from a session for indexing.
class IndexedDetection {
  const IndexedDetection({
    required this.key,
    required this.sessionId,
    required this.position,
    required this.scientificName,
    required this.commonName,
    required this.start,
    required this.end,
    required this.confidence,
    required this.reviewStatus,
    required this.latitude,
    required this.longitude,
    required this.clipPath,
  });

  /// Stable detection key, see [detectionKey].
  final String key;
  final String sessionId;

  /// Index of the detection inside its session's detection list.
  final int position;
  final String scientificName;
  final String commonName;
  final DateTime start;
  final DateTime? end;
  final double confidence;
  final ReviewStatus reviewStatus;
  final double? latitude;
  final double? longitude;
  final String? clipPath;

  Map<String, Object?> toRow() => {
    'key': key,
    'session_id': sessionId,
    'position': position,
    'scientific_name': scientificName,
    'common_name': commonName,
    'start_ms': start.toUtc().millisecondsSinceEpoch,
    'end_ms': end?.toUtc().millisecondsSinceEpoch,
    'local_hour': start.toLocal().hour,
    'local_month': start.toLocal().month,
    'local_day': _dayKey(start),
    'confidence': confidence,
    'review_status': reviewStatus.name,
    'latitude': latitude,
    'longitude': longitude,
    'clip_path': clipPath,
  };

  static IndexedDetection fromRow(Map<String, Object?> row) => IndexedDetection(
    key: row['key']! as String,
    sessionId: row['session_id']! as String,
    position: row['position']! as int,
    scientificName: row['scientific_name']! as String,
    commonName: row['common_name']! as String,
    start: DateTime.fromMillisecondsSinceEpoch(
      row['start_ms']! as int,
      isUtc: true,
    ),
    end:
        row['end_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
              row['end_ms']! as int,
              isUtc: true,
            ),
    confidence: (row['confidence']! as num).toDouble(),
    reviewStatus: ReviewStatus.fromName(row['review_status'] as String?),
    latitude: (row['latitude'] as num?)?.toDouble(),
    longitude: (row['longitude'] as num?)?.toDouble(),
    clipPath: row['clip_path'] as String?,
  );
}

/// Stable key of a detection: survives re-saving a session and rebuilding
/// the index, as long as the detection's species and start time do not change.
String detectionKey(String sessionId, DetectionRecord detection) =>
    '$sessionId|${detection.scientificName}|'
    '${detection.timestamp.toUtc().toIso8601String()}';

/// Local calendar day as an int `yyyymmdd`, used to count distinct days.
int _dayKey(DateTime time) {
  final local = time.toLocal();
  return local.year * 10000 + local.month * 100 + local.day;
}

/// Flattens a session into index rows. A detection without its own GPS
/// position takes the session's position.
List<IndexedDetection> indexRowsForSession(LiveSession session) => [
  for (var i = 0; i < session.detections.length; i++)
    IndexedDetection(
      key: detectionKey(session.id, session.detections[i]),
      sessionId: session.id,
      position: i,
      scientificName: session.detections[i].scientificName,
      commonName: session.detections[i].commonName,
      start: session.detections[i].timestamp,
      end: session.detections[i].endTimestamp,
      confidence: session.detections[i].confidence,
      reviewStatus: session.detections[i].reviewStatus,
      latitude: session.detections[i].latitude ?? session.latitude,
      longitude: session.detections[i].longitude ?? session.longitude,
      clipPath: session.detections[i].audioClipPath,
    ),
];

/// Aggregated counts for one species over a period.
class SpeciesTally {
  const SpeciesTally({
    required this.scientificName,
    required this.commonName,
    required this.contacts,
    required this.days,
    required this.first,
    required this.last,
  });

  final String scientificName;
  final String commonName;

  /// Number of detections (merged song episodes).
  final int contacts;

  /// Number of distinct local days with at least one detection.
  final int days;
  final DateTime first;
  final DateTime last;
}

/// Sort orders for [ObservationIndex.speciesRanking].
enum RankingOrder { contacts, days, lastHeard }

/// SQLite-backed observation index.
class ObservationIndex {
  ObservationIndex._(this._db);

  /// Current schema version. Bump it to force a rebuild after a change.
  static const int schemaVersion = 2;

  final Database _db;

  /// Opens (and creates or migrates) the index at [path] with [factory].
  ///
  /// Use [inMemoryDatabasePath] for tests. A schema change drops the derived
  /// tables; the caller must then rebuild them from the sessions
  /// ([needsRebuild] reports it). Favorites are kept.
  static Future<ObservationIndex> open(
    DatabaseFactory factory,
    String path,
  ) async {
    var migrated = false;
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, _) => _createSchema(db),
        onUpgrade: (db, _, _) async {
          await db.execute('DROP TABLE IF EXISTS detections');
          await db.execute('DROP TABLE IF EXISTS sessions');
          await _createSchema(db);
          migrated = true;
        },
      ),
    );
    final index = ObservationIndex._(db);
    index._needsRebuild = migrated;
    return index;
  }

  bool _needsRebuild = false;

  /// True when a schema upgrade emptied the derived tables.
  bool get needsRebuild => _needsRebuild;

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER,
        latitude REAL,
        longitude REAL,
        detection_count INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS detections (
        key TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        position INTEGER NOT NULL,
        scientific_name TEXT NOT NULL,
        common_name TEXT NOT NULL,
        start_ms INTEGER NOT NULL,
        end_ms INTEGER,
        local_hour INTEGER NOT NULL,
        local_month INTEGER NOT NULL,
        local_day INTEGER NOT NULL,
        confidence REAL NOT NULL,
        review_status TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        clip_path TEXT
      )''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS det_species ON detections(scientific_name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS det_start ON detections(start_ms)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS det_session ON detections(session_id)',
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS favorites (key TEXT PRIMARY KEY)',
    );
    // "Je ne sais pas" answers of the quick review (J3). Kept on rebuild.
    await db.execute(
      'CREATE TABLE IF NOT EXISTS review_skipped (key TEXT PRIMARY KEY)',
    );
  }

  Future<void> close() => _db.close();

  // ---------------------------------------------------------------- writes

  /// Adds or replaces a session and all its detections.
  Future<void> upsertSession(LiveSession session) =>
      _db.transaction((txn) => _upsert(txn, session));

  Future<void> _upsert(Transaction txn, LiveSession session) async {
    await txn.delete(
      'detections',
      where: 'session_id = ?',
      whereArgs: [session.id],
    );
    await txn.insert('sessions', {
      'id': session.id,
      'type': session.type.name,
      'start_ms': session.startTime.toUtc().millisecondsSinceEpoch,
      'end_ms': session.endTime?.toUtc().millisecondsSinceEpoch,
      'latitude': session.latitude,
      'longitude': session.longitude,
      'detection_count': session.detections.length,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final batch = txn.batch();
    for (final row in indexRowsForSession(session)) {
      batch.insert(
        'detections',
        row.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Removes a session and its detections. Favorites are kept.
  Future<void> removeSession(String sessionId) => _db.transaction((txn) async {
    await txn.delete(
      'detections',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    await txn.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  });

  /// Empties the derived tables. Favorites are kept.
  Future<void> clear() => _db.transaction((txn) async {
    await txn.delete('detections');
    await txn.delete('sessions');
  });

  /// Replaces the whole index with [sessions], in one transaction.
  Future<void> rebuild(Iterable<LiveSession> sessions) async {
    await _db.transaction((txn) async {
      await txn.delete('detections');
      await txn.delete('sessions');
      for (final session in sessions) {
        await _upsert(txn, session);
      }
    });
    _needsRebuild = false;
  }

  /// Marks or unmarks a detection as a favorite recording.
  Future<void> setFavorite(String key, {required bool favorite}) async {
    if (favorite) {
      await _db.insert('favorites', {
        'key': key,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await _db.delete('favorites', where: 'key = ?', whereArgs: [key]);
    }
  }

  // --------------------------------------------------------------- queries

  /// Number of indexed sessions and detections.
  Future<({int sessions, int detections})> counts() async {
    final s = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM sessions'),
    );
    final d = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM detections'),
    );
    return (sessions: s ?? 0, detections: d ?? 0);
  }

  /// Builds the WHERE clause shared by the filtered queries.
  static (String, List<Object?>) _filter({
    DateTime? from,
    DateTime? to,
    bool confirmedOnly = false,
    String? scientificName,
  }) {
    final clauses = <String>["review_status != 'rejected'"];
    final args = <Object?>[];
    if (from != null) {
      clauses.add('start_ms >= ?');
      args.add(from.toUtc().millisecondsSinceEpoch);
    }
    if (to != null) {
      clauses.add('start_ms < ?');
      args.add(to.toUtc().millisecondsSinceEpoch);
    }
    if (confirmedOnly) {
      clauses.add("review_status = 'confirmed'");
    }
    if (scientificName != null) {
      clauses.add('scientific_name = ?');
      args.add(scientificName);
    }
    return (clauses.join(' AND '), args);
  }

  /// Species ranked over a period. Rejected detections never count.
  Future<List<SpeciesTally>> speciesRanking({
    DateTime? from,
    DateTime? to,
    bool confirmedOnly = false,
    RankingOrder order = RankingOrder.contacts,
    int? limit,
  }) async {
    final (where, args) = _filter(
      from: from,
      to: to,
      confirmedOnly: confirmedOnly,
    );
    final orderBy = switch (order) {
      RankingOrder.contacts => 'contacts DESC, last_ms DESC',
      RankingOrder.days => 'days DESC, contacts DESC',
      RankingOrder.lastHeard => 'last_ms DESC',
    };
    final rows = await _db.rawQuery('''
      SELECT scientific_name, MAX(common_name) AS common_name,
             COUNT(*) AS contacts, COUNT(DISTINCT local_day) AS days,
             MIN(start_ms) AS first_ms, MAX(start_ms) AS last_ms
      FROM detections WHERE $where
      GROUP BY scientific_name
      ORDER BY $orderBy, scientific_name
      ${limit == null ? '' : 'LIMIT $limit'}''', args);
    return [
      for (final row in rows)
        SpeciesTally(
          scientificName: row['scientific_name']! as String,
          commonName: row['common_name']! as String,
          contacts: row['contacts']! as int,
          days: row['days']! as int,
          first: DateTime.fromMillisecondsSinceEpoch(
            row['first_ms']! as int,
            isUtc: true,
          ),
          last: DateTime.fromMillisecondsSinceEpoch(
            row['last_ms']! as int,
            isUtc: true,
          ),
        ),
    ];
  }

  /// Tally of one species over a period, or null if never heard in it.
  Future<SpeciesTally?> speciesTally(
    String scientificName, {
    DateTime? from,
    DateTime? to,
    bool confirmedOnly = false,
  }) async {
    final all = await speciesRanking(
      from: from,
      to: to,
      confirmedOnly: confirmedOnly,
    );
    for (final tally in all) {
      if (tally.scientificName == scientificName) return tally;
    }
    return null;
  }

  /// Species whose first-ever detection (rejected ones aside) is at or
  /// after [since]: the "nouvelles de l'année".
  Future<Set<String>> speciesFirstHeardSince(DateTime since) async {
    final rows = await _db.rawQuery(
      "SELECT scientific_name FROM detections WHERE review_status != 'rejected' "
      'GROUP BY scientific_name HAVING MIN(start_ms) >= ?',
      [since.toUtc().millisecondsSinceEpoch],
    );
    return {for (final row in rows) row['scientific_name']! as String};
  }

  /// All-time contact count per species (for "×3 · 142 au total").
  Future<Map<String, int>> totalContactsBySpecies() async {
    final rows = await _db.rawQuery(
      "SELECT scientific_name, COUNT(*) AS n FROM detections "
      "WHERE review_status != 'rejected' GROUP BY scientific_name",
    );
    return {
      for (final row in rows)
        row['scientific_name']! as String: row['n']! as int,
    };
  }

  /// Positioned detections for the map, newest first.
  Future<List<IndexedDetection>> mapPoints({
    DateTime? from,
    DateTime? to,
    bool confirmedOnly = false,
    String? scientificName,
  }) async {
    final (where, args) = _filter(
      from: from,
      to: to,
      confirmedOnly: confirmedOnly,
      scientificName: scientificName,
    );
    final rows = await _db.rawQuery(
      'SELECT * FROM detections WHERE $where '
      'AND latitude IS NOT NULL AND longitude IS NOT NULL '
      'ORDER BY start_ms DESC',
      args,
    );
    return rows.map(IndexedDetection.fromRow).toList();
  }

  /// Detections of one species that have an audio clip, best score first
  /// (or newest first), optionally favorites only.
  Future<List<IndexedDetection>> clipsForSpecies(
    String scientificName, {
    bool byDate = false,
    bool favoritesOnly = false,
  }) async {
    final (where, args) = _filter(scientificName: scientificName);
    final rows = await _db.rawQuery(
      'SELECT d.* FROM detections d '
      '${favoritesOnly ? 'JOIN favorites f ON f.key = d.key ' : ''}'
      'WHERE $where AND d.clip_path IS NOT NULL '
      'ORDER BY ${byDate ? 'd.start_ms DESC' : 'd.confidence DESC, d.start_ms DESC'}',
      args,
    );
    return rows.map(IndexedDetection.fromRow).toList();
  }

  /// Species that have at least one clip, with their clip and favorite
  /// counts, most clips first.
  Future<
    List<({String scientificName, String commonName, int clips, int favorites})>
  >
  speciesWithClips() async {
    final rows = await _db.rawQuery('''
      SELECT d.scientific_name, MAX(d.common_name) AS common_name,
             COUNT(*) AS clips, COUNT(f.key) AS favorites
      FROM detections d LEFT JOIN favorites f ON f.key = d.key
      WHERE d.clip_path IS NOT NULL AND d.review_status != 'rejected'
      GROUP BY d.scientific_name
      ORDER BY clips DESC, d.scientific_name''');
    return [
      for (final row in rows)
        (
          scientificName: row['scientific_name']! as String,
          commonName: row['common_name']! as String,
          clips: row['clips']! as int,
          favorites: row['favorites']! as int,
        ),
    ];
  }

  /// Keys of favorite detections.
  Future<Set<String>> favoriteKeys() async {
    final rows = await _db.query('favorites');
    return {for (final row in rows) row['key']! as String};
  }

  /// Contacts per local hour (index 0 to 23), optionally for one species.
  Future<List<int>> activityByHour({String? scientificName}) =>
      _histogram('local_hour', 24, 0, scientificName);

  /// Contacts per local month (index 0 = January), optionally for one species.
  Future<List<int>> activityByMonth({String? scientificName}) =>
      _histogram('local_month', 12, 1, scientificName);

  Future<List<int>> _histogram(
    String column,
    int size,
    int offset,
    String? scientificName,
  ) async {
    final (where, args) = _filter(scientificName: scientificName);
    final rows = await _db.rawQuery(
      'SELECT $column AS bucket, COUNT(*) AS n FROM detections '
      'WHERE $where GROUP BY $column',
      args,
    );
    final result = List<int>.filled(size, 0);
    for (final row in rows) {
      final bucket = (row['bucket']! as int) - offset;
      if (bucket >= 0 && bucket < size) result[bucket] = row['n']! as int;
    }
    return result;
  }

  /// Unreviewed detections waiting for the quick review, lowest score first
  /// (the most doubtful come first), capped at [limit]. Detections answered
  /// "Je ne sais pas" leave the queue.
  Future<List<IndexedDetection>> reviewQueue({int limit = 50}) async {
    final rows = await _db.rawQuery(
      "SELECT * FROM detections WHERE review_status = 'unreviewed' "
      'AND key NOT IN (SELECT key FROM review_skipped) '
      'ORDER BY confidence ASC, start_ms DESC LIMIT ?',
      [limit],
    );
    return rows.map(IndexedDetection.fromRow).toList();
  }

  /// Number of detections waiting in the quick review.
  Future<int> reviewQueueLength() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery(
          "SELECT COUNT(*) FROM detections WHERE review_status = 'unreviewed' "
          'AND key NOT IN (SELECT key FROM review_skipped)',
        ),
      ) ??
      0;

  /// Records a "Je ne sais pas" answer: the detection stays unreviewed but
  /// leaves the review queue.
  Future<void> markSkipped(String key) => _db.insert('review_skipped', {
    'key': key,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);

  /// Confirmed and reviewed (confirmed + rejected) counts per score band,
  /// with [sureMin] and [probableMin] as band limits.
  Future<Map<String, ({int confirmed, int reviewed})>> precisionByScoreBand({
    required double sureMin,
    required double probableMin,
  }) async {
    final rows = await _db.rawQuery(
      '''
      SELECT CASE WHEN confidence >= ? THEN 'sure'
                  WHEN confidence >= ? THEN 'probable'
                  ELSE 'toCheck' END AS band,
             SUM(review_status = 'confirmed') AS confirmed,
             COUNT(*) AS reviewed
      FROM detections WHERE review_status IN ('confirmed', 'rejected')
      GROUP BY band''',
      [sureMin, probableMin],
    );
    return {
      for (final row in rows)
        row['band']! as String: (
          confirmed: (row['confirmed'] as int?) ?? 0,
          reviewed: row['reviewed']! as int,
        ),
    };
  }

  /// Per-species precision for species reviewed at least [minReviews]
  /// times, best reviewed first.
  Future<
    List<
      ({String scientificName, String commonName, int confirmed, int reviewed})
    >
  >
  precisionBySpecies({required int minReviews}) async {
    final rows = await _db.rawQuery(
      '''
      SELECT scientific_name, MAX(common_name) AS common_name,
             SUM(review_status = 'confirmed') AS confirmed, COUNT(*) AS reviewed
      FROM detections WHERE review_status IN ('confirmed', 'rejected')
      GROUP BY scientific_name HAVING COUNT(*) >= ?
      ORDER BY reviewed DESC, scientific_name''',
      [minReviews],
    );
    return [
      for (final row in rows)
        (
          scientificName: row['scientific_name']! as String,
          commonName: row['common_name']! as String,
          confirmed: (row['confirmed'] as int?) ?? 0,
          reviewed: row['reviewed']! as int,
        ),
    ];
  }

  /// Confirmed and reviewed counts for one species.
  Future<({int confirmed, int reviewed})> speciesPrecision(
    String scientificName,
  ) async {
    final rows = await _db.rawQuery(
      "SELECT SUM(review_status = 'confirmed') AS confirmed, COUNT(*) AS n "
      "FROM detections WHERE scientific_name = ? "
      "AND review_status IN ('confirmed', 'rejected')",
      [scientificName],
    );
    final row = rows.single;
    return (
      confirmed: (row['confirmed'] as int?) ?? 0,
      reviewed: (row['n'] as int?) ?? 0,
    );
  }
}
