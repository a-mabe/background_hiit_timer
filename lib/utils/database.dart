import 'dart:async';
import 'package:background_hiit_timer/models/interval_type.dart';
import 'package:background_hiit_timer/utils/log.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseManager {
  static const String _databaseName = "openhiit_temp_timer.db";
  static const String _intervalTableName = "CurrentTimerIntervals";

  // Singleton instance
  static final DatabaseManager _instance = DatabaseManager._internal();

  // Private constructor
  DatabaseManager._internal();

  // Factory constructor to return the singleton instance
  factory DatabaseManager() {
    return _instance;
  }

  Database? _database;

  // Lazy initialization of the database, open it only once
  Future<Database> _getDatabase() async {
    if (_database != null) {
      return _database!;
    }
    _database = await openIntervalDatabase();
    return _database!;
  }

  // Open the workout database
  Future<Database> openIntervalDatabase() async {
    logger.d("Opening database");

    const createIntervalTableQuery = '''
      CREATE TABLE IF NOT EXISTS $_intervalTableName(
        id TEXT PRIMARY KEY,
        workoutId TEXT,
        time INTEGER,
        name TEXT,
        color INTEGER,
        intervalIndex INTEGER,
        startSound TEXT,
        halfwaySound TEXT,
        countdownSound TEXT,
        endSound TEXT
      )
    ''';

    String dbPath = join(await getDatabasesPath(), _databaseName);
    int dbVersion = 1;

    return openDatabase(
      dbPath,
      version: dbVersion,
      onCreate: (db, version) async {
        logger.d("Creating interval table");
        await db.execute(createIntervalTableQuery);
      },
    );
  }

  // Check if the database already has data and delete it if so
  Future<void> clearDatabaseIfNotEmpty() async {
    logger.d("Checking if database has data");

    final db = await _getDatabase();
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_intervalTableName'));

    if (count != null && count > 0) {
      logger.d("Database has data, clearing it");
      await db.delete(_intervalTableName);
    } else {
      logger.d("Database is already empty");
    }
  }

  // Insert interval
  Future<void> insertInterval(IntervalType interval) async {
    logger.d("Inserting interval: ${interval.name}");

    final db = await _getDatabase();
    await db.insert(
      _intervalTableName,
      interval.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  // Insert intervals
  Future<void> insertIntervals(List<IntervalType> intervals) async {
    logger.d("Inserting ${intervals.length} intervals");

    final db = await _getDatabase();
    Batch batch = db.batch();

    for (var interval in intervals) {
      batch.insert(
        _intervalTableName,
        interval.toMap(),
        conflictAlgorithm: ConflictAlgorithm.fail,
      );
    }

    await batch.commit(noResult: true);
  }

  // Update interval
  Future<void> updateInterval(IntervalType interval) async {
    logger.d("Updating interval: ${interval.name}");

    final db = await _getDatabase();
    await db.update(
      _intervalTableName,
      interval.toMap(),
      where: 'id = ?',
      whereArgs: [interval.id],
    );
  }

  // Batch update intervals
  Future<void> updateIntervals(List<IntervalType> intervals) async {
    logger.d("Updating ${intervals.length} intervals");

    final db = await _getDatabase();
    Batch batch = db.batch();

    for (var interval in intervals) {
      batch.update(
        _intervalTableName,
        interval.toMap(),
        where: 'id = ?',
        whereArgs: [interval.id],
      );
    }

    await batch.commit(noResult: true);
  }

  // Delete interval
  Future<void> deleteInterval(String id) async {
    logger.d("Deleting interval with ID: $id");

    final db = await _getDatabase();
    await db.delete(
      _intervalTableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete intervals
  Future<void> deleteIntervalsByWorkoutId(String workoutId) async {
    logger.d("Deleting intervals for workout ID: $workoutId");

    final db = await _getDatabase();
    await db.delete(
      _intervalTableName,
      where: 'workoutId = ?',
      whereArgs: [workoutId],
    );
  }

  // Get all intervals
  Future<List<IntervalType>> getIntervals() async {
    logger.d("Getting all intervals");

    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(_intervalTableName);
    return maps.map((map) => IntervalType.fromMap(map)).toList();
  }
}
