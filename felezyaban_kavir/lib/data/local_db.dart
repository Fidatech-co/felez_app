import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class LocalDatabase {
  LocalDatabase._(this._db);

  final Database _db;

  static const _dbName = 'felezyaban.db';
  static const _dbVersion = 2;

  static Future<LocalDatabase> open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    final db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (database, version) async {
        await database.execute('''
CREATE TABLE auth_tokens (
  id INTEGER PRIMARY KEY,
  access TEXT,
  refresh TEXT,
  updated_at TEXT
)
''');
        await database.execute('''
CREATE TABLE cache_items (
  type TEXT PRIMARY KEY,
  json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
        await database.execute('''
CREATE TABLE form_submissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  form_type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  status TEXT NOT NULL,
  remote_id INTEGER,
  last_error TEXT
)
''');
        await database.execute('''
CREATE TABLE profile_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  message TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('''
CREATE TABLE profile_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  message TEXT NOT NULL,
  created_at TEXT NOT NULL
)
''');
        }
      },
    );
    return LocalDatabase._(db);
  }

  Future<void> saveTokens(AuthTokens tokens) async {
    await _db.insert(
      'auth_tokens',
      {
        'id': 1,
        'access': tokens.access,
        'refresh': tokens.refresh,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AuthTokens?> loadTokens() async {
    final rows = await _db.query('auth_tokens', where: 'id = 1');
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    final access = row['access'] as String?;
    final refresh = row['refresh'] as String?;
    if (access == null || refresh == null) {
      return null;
    }
    return AuthTokens(access: access, refresh: refresh);
  }

  Future<void> saveCache(String type, dynamic jsonValue) async {
    await _db.insert(
      'cache_items',
      {
        'type': type,
        'json': jsonEncode(jsonValue),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<dynamic> loadCache(String type) async {
    final rows = await _db.query(
      'cache_items',
      where: 'type = ?',
      whereArgs: [type],
    );
    if (rows.isEmpty) {
      return null;
    }
    final jsonValue = rows.first['json'] as String?;
    if (jsonValue == null) {
      return null;
    }
    return jsonDecode(jsonValue);
  }

  Future<void> deleteCacheByPrefix(String prefix) async {
    await _db.delete(
      'cache_items',
      where: 'type LIKE ?',
      whereArgs: ['$prefix%'],
    );
  }

  Future<int> insertFormSubmission(FormSubmission submission) async {
    return _db.insert('form_submissions', {
      'form_type': submission.formType,
      'title': submission.title,
      'description': submission.description,
      'payload': jsonEncode(submission.payload),
      'created_at': submission.createdAt.toIso8601String(),
      'updated_at': submission.updatedAt.toIso8601String(),
      'status': submission.status,
      'remote_id': submission.remoteId,
      'last_error': submission.lastError,
    });
  }

  Future<void> updateFormSubmission(
    int id, {
    required String status,
    int? remoteId,
    String? lastError,
  }) async {
    await _db.update(
      'form_submissions',
      {
        'status': status,
        'remote_id': remoteId,
        'last_error': lastError,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertProfileLog(String message) async {
    return _db.insert('profile_logs', {
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<ProfileLogEntry>> loadProfileLogs() async {
    final rows = await _db.query(
      'profile_logs',
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (row) => ProfileLogEntry(
            id: row['id'] as int? ?? 0,
            message: row['message']?.toString() ?? '',
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList();
  }

  Future<List<FormSubmission>> loadFormSubmissions({
    DateTime? since,
    List<String>? statuses,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (since != null) {
      where.add('created_at >= ?');
      args.add(since.toIso8601String());
    }
    if (statuses != null && statuses.isNotEmpty) {
      final placeholders = List.filled(statuses.length, '?').join(',');
      where.add('status IN ($placeholders)');
      args.addAll(statuses);
    }
    final rows = await _db.query(
      'form_submissions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
    );
    return rows.map(_rowToSubmission).toList();
  }

  Future<FormSubmission?> loadFormSubmission(int id) async {
    final rows = await _db.query(
      'form_submissions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _rowToSubmission(rows.first);
  }

  Future<void> deleteOldSubmissions(DateTime olderThan) async {
    await _db.delete(
      'form_submissions',
      where: 'created_at < ?',
      whereArgs: [olderThan.toIso8601String()],
    );
  }

  Future<void> deleteFormSubmission(int id) async {
    await _db.delete(
      'form_submissions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  FormSubmission _rowToSubmission(Map<String, Object?> row) {
    return FormSubmission(
      id: row['id'] as int?,
      formType: row['form_type'] as String? ?? '',
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      payload: jsonDecode(row['payload'] as String? ?? '{}')
          as Map<String, dynamic>,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      status: row['status'] as String? ?? 'pending',
      remoteId: row['remote_id'] as int?,
      lastError: row['last_error'] as String?,
    );
  }
}
