import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/envelope.dart';
import '../models/transaction.dart' as model;
import '../models/payday.dart';
import '../models/allocation.dart';
import '../models/recurring_payday.dart';

class DatabaseHelper {
  static DatabaseFactory factory = databaseFactoryFfi;

  Database? _db;
  String? _currentKey;
  String? _cachedDbPath;
  bool _isEncrypted = true;

  /// Opens (or creates) the encrypted SQLCipher database with [hexKey].
  ///
  /// SECURITY: The key is applied via [onConfigure], which runs BEFORE
  /// [onCreate], [onUpgrade], or any schema query.  This is required because
  /// some SQLCipher builds will reject PRAGMA key applied after the first
  /// schema interaction.
  ///
  /// DATABASE LOCATION: We deliberately use [getApplicationDocumentsDirectory]
  /// (not `getDatabasesPath` from sqflite) because:
  ///
  ///   1. SQLCipher needs FFI, not the platform-specific sqflite SQLite.
  ///      The sqflite default path is managed by a different SQLite library
  ///      that does NOT support encryption.
  ///   2. If the path is changed to the standard "databases" folder, a future
  ///      developer might accidentally open the file with plain sqflite,
  ///      bypassing the SQLCipher encryption layer entirely.
  ///   3. Using app-documents keeps the DB alongside other app data,
  ///      which makes backup/restore logic simpler and more auditable.
  ///
  /// CONSEQUENCES OF CHANGING THIS PATH:
  ///   - Plaintext sqflite access would read raw ciphertext -> corrupted data
  ///   - Backup scripts that assume unencrypted DBs would fail silently
  ///   - Users who expect "clear app data" to remove all traces would be
  ///     surprised if a second copy exists elsewhere
  Future<Database> open(String hexKey) async {
    if (_db != null && _currentKey == hexKey) {
      try {
        await _db!.rawQuery('SELECT 1');
        return _db!;
      } catch (_) {
        await close();
      }
    }
    await close();

    if (_cachedDbPath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _cachedDbPath = p.join(dir.path, 'coindrop.db');
    }
    final path = _cachedDbPath!;

    _db = await DatabaseHelper.factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onConfigure: (db) async {
          // SECURITY: PRAGMA key MUST execute in onConfigure, which runs
          // BEFORE onCreate/onUpgrade.  Some SQLCipher builds reject the
          // key if it comes after any schema interaction.
          await db.execute("PRAGMA key = '$hexKey'");
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );

    try {
      await _db!.rawQuery('SELECT count(*) FROM sqlite_master');
    } catch (_) {
      await _db!.close();
      _db = null;
      _currentKey = null;
      rethrow;
    }

    _currentKey = hexKey;
    _isEncrypted = true;
    return _db!;
  }

  /// Opens the database in plaintext (unencrypted) mode.
  /// Uses PRAGMA cipher_compatibility = 4 to tell SQLCipher to use
  /// standard SQLite page format — effectively disabling encryption.
  Future<Database> openPlain() async {
    if (_db != null && !_isEncrypted) {
      try {
        await _db!.rawQuery('SELECT 1');
        return _db!;
      } catch (_) {
        await close();
      }
    }
    await close();

    if (_cachedDbPath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _cachedDbPath = p.join(dir.path, 'coindrop.db');
    }
    final path = _cachedDbPath!;

    _db = await DatabaseHelper.factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onConfigure: (db) async {
          // cipher_compatibility = 4 tells SQLCipher to use standard
          // SQLite format (no encryption). Must run BEFORE any schema
          // interaction, just like PRAGMA key.
          await db.execute("PRAGMA cipher_compatibility = 4");
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );

    _currentKey = null;
    _isEncrypted = false;
    return _db!;
  }

  /// Exports all rows from every table into an in-memory map.
  Future<Map<String, List<Map<String, dynamic>>>> exportAllData() async {
    final db = _requireDb();
    final data = <String, List<Map<String, dynamic>>>{};
    for (final table in ['envelopes', 'transactions', 'paydays', 'allocations', 'recurring_paydays']) {
      data[table] = await db.query(table);
    }
    return data;
  }

  /// Imports data into ALL tables, preserving row IDs.
  /// Imports in FK dependency order (envelopes/paydays first, then transactions,
  /// then allocations). Updates sqlite_sequence so AUTOINCREMENT works correctly.
  Future<void> importAllData(Map<String, List<Map<String, dynamic>>> data) async {
    final db = _requireDb();
    await db.transaction((txn) async {
      const tables = ['envelopes', 'paydays', 'recurring_paydays', 'transactions', 'allocations'];
      for (final table in tables) {
        final rows = data[table] ?? [];
        for (final row in rows) {
          await txn.insert(table, row);
        }
        if (rows.isNotEmpty) {
          final maxId = rows.map((r) => r['id'] as int).reduce((a, b) => a > b ? a : b);
          await txn.execute('INSERT OR REPLACE INTO sqlite_sequence (name, seq) VALUES (?, ?)', [table, maxId]);
        }
      }
    });
  }

  /// Deletes the database file (and WAL/SHM journals) from disk.
  Future<void> deleteDatabaseFile() async {
    await close();
    if (_cachedDbPath == null) {
      final dir = await getApplicationDocumentsDirectory();
      _cachedDbPath = p.join(dir.path, 'coindrop.db');
    }
    for (final suffix in ['', '-wal', '-shm']) {
      final f = File('$_cachedDbPath$suffix');
      if (await f.exists()) await f.delete();
    }
  }

  Database? get db => _db;
  bool get isOpen => _db != null && _db!.isOpen;
  bool get isEncrypted => _isEncrypted;

  Future<void> close() async {
    if (_db != null) {
      if (_db!.isOpen) {
        await _db!.close();
      }
      _db = null;
    }
    _currentKey = null;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE envelopes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        initial_amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        color INTEGER NOT NULL DEFAULT 0,
        icon TEXT NOT NULL DEFAULT 'savings'
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        envelope_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        note TEXT NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'spending',
        FOREIGN KEY (envelope_id) REFERENCES envelopes (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE paydays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        note TEXT NOT NULL,
        date TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payday_id INTEGER NOT NULL,
        envelope_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (payday_id) REFERENCES paydays (id) ON DELETE CASCADE,
        FOREIGN KEY (envelope_id) REFERENCES envelopes (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE recurring_paydays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        frequency TEXT NOT NULL,
        weekday INTEGER,
        month_day INTEGER,
        note TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        last_processed_date TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_envelope_id ON transactions(envelope_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_allocations_payday_id ON allocations(payday_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_allocations_envelope_id ON allocations(envelope_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_paydays_date ON paydays(date)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE envelopes ADD COLUMN color INTEGER NOT NULL DEFAULT 0');
      await db.execute("ALTER TABLE envelopes ADD COLUMN icon TEXT NOT NULL DEFAULT 'savings'");
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE transactions ADD COLUMN type TEXT NOT NULL DEFAULT 'spending'");
      await db.execute('''
        CREATE TABLE paydays (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          note TEXT NOT NULL,
          date TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE allocations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          payday_id INTEGER NOT NULL,
          envelope_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          FOREIGN KEY (payday_id) REFERENCES paydays (id) ON DELETE CASCADE,
          FOREIGN KEY (envelope_id) REFERENCES envelopes (id) ON DELETE CASCADE
        )
      ''');
      final envelopes = await db.query('envelopes');
      for (final env in envelopes) {
        final id = env['id'] as int;
        final amount = env['initial_amount'] as num;
        final createdAt = env['created_at'] as String;
        if (amount > 0) {
          await db.insert('transactions', {
            'envelope_id': id,
            'amount': amount.toDouble(),
            'note': 'Initial allocation',
            'date': createdAt,
            'type': 'funding',
          });
        }
      }
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS recurring_paydays (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          frequency TEXT NOT NULL,
          weekday INTEGER,
          month_day INTEGER,
          note TEXT NOT NULL,
          enabled INTEGER NOT NULL DEFAULT 1,
          last_processed_date TEXT
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_envelope_id ON transactions(envelope_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_allocations_payday_id ON allocations(payday_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_allocations_envelope_id ON allocations(envelope_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_paydays_date ON paydays(date)');
    }
  }

  Database _requireDb() {
    if (_db == null || !_db!.isOpen) {
      throw StateError('Database not open. Call open(hexKey) first.');
    }
    return _db!;
  }

  Future<int> insertEnvelope(Envelope envelope) async {
    final db = _requireDb();
    final map = envelope.toMap()..remove('id');
    // initial_amount is legacy -- always write 0
    map['initial_amount'] = 0;
    return await db.insert('envelopes', map);
  }

  Future<List<Envelope>> getEnvelopes() async {
    final db = _requireDb();
    final maps = await db.query('envelopes', orderBy: 'created_at DESC');
    return maps.map((map) => Envelope.fromMap(map)).toList();
  }

  Future<int> updateEnvelope(Envelope envelope) async {
    final db = _requireDb();
    return await db.update(
      'envelopes',
      envelope.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [envelope.id],
    );
  }

  Future<void> deleteAllEnvelopes() async {
    final db = _requireDb();
    await db.transaction((txn) async {
      await txn.delete('allocations');
      await txn.delete('transactions');
      await txn.delete('envelopes');
    });
  }

  Future<void> deleteAllPaydays() async {
    final db = _requireDb();
    await db.transaction((txn) async {
      await txn.delete('allocations');
      await txn.delete('paydays');
    });
  }

  Future<int> deleteEnvelope(int id) async {
    final db = _requireDb();
    return await db.transaction((txn) async {
      await txn.delete('transactions', where: 'envelope_id = ?', whereArgs: [id]);
      await txn.delete('allocations', where: 'envelope_id = ?', whereArgs: [id]);
      return await txn.delete('envelopes', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> insertTransaction(model.Transaction transaction) async {
    final db = _requireDb();
    return await db.insert('transactions', transaction.toMap()..remove('id'));
  }

  Future<List<model.Transaction>> getTransactions(int envelopeId) async {
    final db = _requireDb();
    final maps = await db.query('transactions',
        where: 'envelope_id = ?', whereArgs: [envelopeId], orderBy: 'date DESC');
    return maps.map((map) => model.Transaction.fromMap(map)).toList();
  }

  Future<List<model.Transaction>> getAllTransactions() async {
    final db = _requireDb();
    final maps = await db.query('transactions', orderBy: 'date DESC');
    return maps.map((map) => model.Transaction.fromMap(map)).toList();
  }

  Future<List<model.Transaction>> searchTransactions(String query) async {
    final db = _requireDb();
    final maps = await db.query('transactions',
        where: 'note LIKE ?', whereArgs: ['%$query%'], orderBy: 'date DESC');
    return maps.map((map) => model.Transaction.fromMap(map)).toList();
  }

  Future<List<model.Transaction>> getFilteredTransactions(
    int envelopeId, DateTime? startDate, DateTime? endDate,
  ) async {
    final db = _requireDb();
    String where = 'envelope_id = ?';
    List<dynamic> args = [envelopeId];
    if (startDate != null && endDate != null) {
      where += ' AND date >= ? AND date <= ?';
      args.add(startDate.toIso8601String());
      args.add(endDate.toIso8601String());
    }
    final maps = await db.query('transactions',
        where: where, whereArgs: args, orderBy: 'date DESC');
    return maps.map((map) => model.Transaction.fromMap(map)).toList();
  }

  Future<int> deleteTransaction(int id) async {
    final db = _requireDb();
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<double> getTotalFunding(int envelopeId) async {
    final db = _requireDb();
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE envelope_id = ? AND type = \'funding\'',
      [envelopeId],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getTotalSpending(int envelopeId) async {
    final db = _requireDb();
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE envelope_id = ? AND type = \'spending\'',
      [envelopeId],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getTotalSpentInRange(DateTime start, DateTime end) async {
    final db = _requireDb();
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM transactions WHERE type = \'spending\' AND date >= ? AND date <= ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<double> getLastPaycheckAmount() async {
    final db = _requireDb();
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM paydays ORDER BY date DESC LIMIT 1',
    );
    if (result.isEmpty) return 0;
    return (result.first['total'] as num).toDouble();
  }

  Future<int> insertPayday(Payday payday) async {
    final db = _requireDb();
    return await db.insert('paydays', payday.toJson()..remove('id'));
  }

  Future<List<Payday>> getPaydays() async {
    final db = _requireDb();
    final maps = await db.query('paydays', orderBy: 'date DESC');
    return maps.map((map) => Payday.fromMap(map)).toList();
  }

  Future<Payday?> getPayday(int paydayId) async {
    final db = _requireDb();
    final maps = await db.query('paydays', where: 'id = ?', whereArgs: [paydayId]);
    if (maps.isEmpty) return null;
    return Payday.fromMap(maps.first);
  }

  Future<int> deletePayday(int paydayId) async {
    final db = _requireDb();
    return await db.transaction((txn) async {
      await txn.delete('allocations', where: 'payday_id = ?', whereArgs: [paydayId]);
      return await txn.delete('paydays', where: 'id = ?', whereArgs: [paydayId]);
    });
  }

  Future<int> insertAllocation(Allocation allocation) async {
    final db = _requireDb();
    return await db.insert('allocations', allocation.toMap()..remove('id'));
  }

  Future<List<Map<String, dynamic>>> getAllocationsWithEnvelope(int paydayId) async {
    final db = _requireDb();
    return await db.rawQuery(
      'SELECT a.*, e.name as envelope_name FROM allocations a JOIN envelopes e ON a.envelope_id = e.id WHERE a.payday_id = ?',
      [paydayId],
    );
  }

  Future<List<RecurringPayday>> getRecurringPaydays({bool enabledOnly = false}) async {
    final db = _requireDb();
    String? where;
    List<dynamic>? whereArgs;
    if (enabledOnly) {
      where = 'enabled = 1';
      whereArgs = [];
    }
    final maps = await db.query('recurring_paydays',
        where: where, whereArgs: whereArgs, orderBy: 'amount DESC');
    return maps.map((map) => RecurringPayday.fromMap(map)).toList();
  }

  Future<int> insertRecurringPayday(RecurringPayday rule) async {
    final db = _requireDb();
    return await db.insert('recurring_paydays', rule.toMap()..remove('id'));
  }

  Future<void> updateRecurringPayday(RecurringPayday rule) async {
    final db = _requireDb();
    await db.update('recurring_paydays', rule.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [rule.id]);
  }

  Future<void> deleteRecurringPayday(int id) async {
    final db = _requireDb();
    await db.delete('recurring_paydays', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getTransactionCount(int? envelopeId) async {
    final db = _requireDb();
    if (envelopeId != null) {
      final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM transactions WHERE envelope_id = ?', [envelopeId]);
      return (result.first['count'] as int);
    }
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM transactions');
    return (result.first['count'] as int);
  }

  Future<double> getAverageSpend() async {
    final db = _requireDb();
    final result = await db.rawQuery(
      'SELECT COALESCE(AVG(amount), 0) as avg FROM transactions WHERE type = \'spending\'',
    );
    return (result.first['avg'] as num).toDouble();
  }

  Future<List<Map<String, dynamic>>> getSpendingByEnvelope(DateTime start, DateTime end) async {
    final db = _requireDb();
    return await db.rawQuery(
      'SELECT e.name, COALESCE(SUM(t.amount), 0) as total FROM transactions t JOIN envelopes e ON t.envelope_id = e.id WHERE t.type = \'spending\' AND t.date >= ? AND t.date <= ? GROUP BY e.name ORDER BY total DESC',
      [start.toIso8601String(), end.toIso8601String()],
    );
  }

  Future<List<Map<String, dynamic>>> getWeeklySpending(int weeks) async {
    final results = <Map<String, dynamic>>[];
    final now = DateTime.now();
    for (int i = weeks - 1; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: (i + 1) * 7));
      final weekEnd = now.subtract(Duration(days: i * 7));
      final total = await getTotalSpentInRange(weekStart, weekEnd);
      results.add({
        'week': 'W${weeks - i}',
        'total': total,
        'day': weekStart.toIso8601String(),
      });
    }
    return results;
  }
}
