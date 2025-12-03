import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/reminder.dart';
import '../models/reminder_type.dart';
import '../models/medication_log.dart';
import '../models/app_settings.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('timer_reminder.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<bool> _columnExists(Database db, String tableName, String columnName) async {
    final result = await db.rawQuery('PRAGMA table_info($tableName)');
    return result.any((column) => column['name'] == columnName);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          id INTEGER PRIMARY KEY CHECK (id = 1),
          globalQuietHoursStart TEXT,
          globalQuietHoursEnd TEXT,
          useGlobalQuietHours INTEGER DEFAULT 0
        )
      ''');
    }
    if (oldVersion < 3) {
      if (!await _columnExists(db, 'reminders', 'notificationSound')) {
        await db.execute('''
          ALTER TABLE reminders ADD COLUMN notificationSound TEXT
        ''');
      }
    }
    if (oldVersion < 4) {
      if (!await _columnExists(db, 'reminders', 'medicationOptions')) {
        await db.execute('''
          ALTER TABLE reminders ADD COLUMN medicationOptions TEXT
        ''');
      }
    }
    if (oldVersion < 5) {
      // Migrate from intervalMinutes to intervalSeconds
      if (!await _columnExists(db, 'reminders', 'intervalSeconds')) {
        // Add new column
        await db.execute('''
          ALTER TABLE reminders ADD COLUMN intervalSeconds INTEGER
        ''');
        // Copy data, converting minutes to seconds
        await db.execute('''
          UPDATE reminders SET intervalSeconds = intervalMinutes * 60
        ''');
        // Note: SQLite doesn't support dropping columns easily, so we'll just stop using intervalMinutes
        // The old column will remain but be ignored
      }
    }
    if (oldVersion < 6) {
      // Add awaitingAcknowledgment column for tracking pending alarms
      if (!await _columnExists(db, 'reminders', 'awaitingAcknowledgment')) {
        await db.execute('''
          ALTER TABLE reminders ADD COLUMN awaitingAcknowledgment INTEGER DEFAULT 0
        ''');
      }
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reminder_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        color TEXT,
        iconName TEXT,
        notificationSound TEXT,
        priority INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reminderTypeId INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        intervalSeconds INTEGER NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        startDate TEXT,
        endDate TEXT,
        quietHoursStart TEXT,
        quietHoursEnd TEXT,
        lastTriggered TEXT,
        waterBehavior TEXT,
        trackHistory INTEGER NOT NULL DEFAULT 1,
        notificationSound TEXT,
        medicationOptions TEXT,
        awaitingAcknowledgment INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (reminderTypeId) REFERENCES reminder_types (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE medication_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        reminderId INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        action TEXT NOT NULL,
        notes TEXT,
        dosageAmount TEXT,
        FOREIGN KEY (reminderId) REFERENCES reminders (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_logs_reminder ON medication_logs(reminderId)
    ''');

    await db.execute('''
      CREATE INDEX idx_logs_timestamp ON medication_logs(timestamp)
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        globalQuietHoursStart TEXT,
        globalQuietHoursEnd TEXT,
        useGlobalQuietHours INTEGER DEFAULT 0
      )
    ''');

    await db.insert('app_settings', {
      'id': 1,
      'useGlobalQuietHours': 0,
    });
  }

  // ReminderType CRUD operations
  Future<ReminderType> createReminderType(ReminderType type) async {
    final db = await database;
    final id = await db.insert('reminder_types', type.toMap());
    return type.copyWith(id: id);
  }

  Future<List<ReminderType>> getAllReminderTypes() async {
    final db = await database;
    final result = await db.query('reminder_types', orderBy: 'priority DESC, name ASC');
    return result.map((map) => ReminderType.fromMap(map)).toList();
  }

  Future<ReminderType?> getReminderType(int id) async {
    final db = await database;
    final result = await db.query(
      'reminder_types',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return ReminderType.fromMap(result.first);
  }

  Future<int> updateReminderType(ReminderType type) async {
    final db = await database;
    return db.update(
      'reminder_types',
      type.toMap(),
      where: 'id = ?',
      whereArgs: [type.id],
    );
  }

  Future<int> deleteReminderType(int id) async {
    final db = await database;
    return db.delete(
      'reminder_types',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Reminder CRUD operations
  Future<Reminder> createReminder(Reminder reminder) async {
    final db = await database;
    final id = await db.insert('reminders', reminder.toMap());
    return reminder.copyWith(id: id);
  }

  Future<List<Reminder>> getAllReminders() async {
    final db = await database;
    final result = await db.query('reminders', orderBy: 'title ASC');
    return result.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<List<Reminder>> getActiveReminders() async {
    final db = await database;
    final result = await db.query(
      'reminders',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'title ASC',
    );
    return result.map((map) => Reminder.fromMap(map)).toList();
  }

  Future<Reminder?> getReminder(int id) async {
    final db = await database;
    final result = await db.query(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Reminder.fromMap(result.first);
  }

  Future<int> updateReminder(Reminder reminder) async {
    final db = await database;
    return db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<int> deleteReminder(int id) async {
    final db = await database;
    return db.delete(
      'reminders',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // MedicationLog CRUD operations
  Future<MedicationLog> createLog(MedicationLog log) async {
    final db = await database;
    final id = await db.insert('medication_logs', log.toMap());
    return log.copyWith(id: id);
  }

  Future<List<MedicationLog>> getAllLogs() async {
    final db = await database;
    final result = await db.query('medication_logs', orderBy: 'timestamp DESC');
    return result.map((map) => MedicationLog.fromMap(map)).toList();
  }

  Future<List<MedicationLog>> getLogsByReminder(int reminderId) async {
    final db = await database;
    final result = await db.query(
      'medication_logs',
      where: 'reminderId = ?',
      whereArgs: [reminderId],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => MedicationLog.fromMap(map)).toList();
  }

  Future<List<MedicationLog>> getTodayLogs() async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();
    final result = await db.query(
      'medication_logs',
      where: 'timestamp >= ?',
      whereArgs: [startOfDay],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => MedicationLog.fromMap(map)).toList();
  }

  Future<MedicationLog?> getLastLogForReminder(int reminderId) async {
    final db = await database;
    final result = await db.query(
      'medication_logs',
      where: 'reminderId = ? AND action = ?',
      whereArgs: [reminderId, LogAction.taken.name],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (result.isEmpty) return null;
    return MedicationLog.fromMap(result.first);
  }

  Future<int> updateLog(MedicationLog log) async {
    final db = await database;
    return db.update(
      'medication_logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<int> deleteLog(int id) async {
    final db = await database;
    return db.delete(
      'medication_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // AppSettings operations
  Future<AppSettings> getSettings() async {
    final db = await database;
    final result = await db.query('app_settings', where: 'id = ?', whereArgs: [1]);
    if (result.isEmpty) {
      final defaultSettings = AppSettings();
      await db.insert('app_settings', {'id': 1, ...defaultSettings.toMap()});
      return defaultSettings;
    }
    return AppSettings.fromMap(result.first);
  }

  Future<int> updateSettings(AppSettings settings) async {
    final db = await database;
    return db.update(
      'app_settings',
      settings.toMap(),
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
