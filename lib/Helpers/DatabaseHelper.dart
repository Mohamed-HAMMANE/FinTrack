import 'dart:io';

import 'dart:async';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  static final _databaseVersion = 1;

  static final _databaseName = 'fin_track';

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('$_databaseName.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: _createDB,
      onUpgrade: _onUpgrade
    );
  }

  FutureOr<void> _createDB(Database db, int version) async {

    await db.execute('''
      CREATE TABLE Category (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Name TEXT NOT NULL,
        Budget REAL NOT NULL,
        `Order` INTEGER NOT NULL,
        IconCode INTEGER NOT NULL DEFAULT 0,
        CreationDate TEXT NOT NULL DEFAULT (datetime('now','utc'))
      );
    ''');

    await db.execute('''
      CREATE TABLE Expense (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Amount REAL NOT NULL,
        Date TEXT NOT NULL,
        Comment TEXT,
        CreationDate TEXT NOT NULL DEFAULT (datetime('now','utc')),
        CategoryId INTEGER NOT NULL,
        FOREIGN KEY (CategoryId) REFERENCES Category (Id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('CREATE INDEX idx_expense_date ON Expense(Date);');
    await db.execute('CREATE INDEX idx_expense_category ON Expense(CategoryId);');

  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {

    }
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  static Future<List<Map<String, Object?>>> select(String query) async {
    final db = await instance.database;
    return await db.rawQuery(query);
  }


  static Future<bool> backUp() async{
    try {
      final dbPath = await getDatabasesPath();
      final dbFilePath = path.join(dbPath, '$_databaseName.db');
      final downloadsDir = Directory('/storage/emulated/0/Download');
      final dbFile = File(dbFilePath);
      var now = DateTime.now();
      final newFilePath = path.join(downloadsDir.path, '${_databaseName}_backup_${now.year}_${now.month}_${now.day}_${now.hour}_${now.minute}_${now.second}.db'); // New file name in Downloads
      await dbFile.copy(newFilePath);

      return true;
    } catch (er) {
      return false;
    }
  }

  static Future<bool> restore(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles();

    if (result != null) {
      final backupFilePath = result.files.single.path!;
      final dbPath = await getDatabasesPath();
      final appDbPath = path.join(dbPath, '$_databaseName.db');
      final backupFile = File(backupFilePath);
      if (!(await backupFile.exists())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup file not found in Downloads folder.'),
            backgroundColor: Colors.orange,
          ),
        );
        return false;
      }
      await backupFile.copy(appDbPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database restored successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      return true;
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No file selected.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return false;
  }


  static Future<void> dailyBackup() async {
    final now = DateTime.now();
    final eightPM = DateTime(now.year, now.month, now.day, 20, 0, 0);

    DateTime firstRun = eightPM.isBefore(now)
        ? eightPM.add(const Duration(days: 1))
        : eightPM;

    final initialDelay = firstRun.difference(now).inSeconds;

    await AndroidAlarmManager.periodic(
        const Duration(hours: 24),
        159,
        DatabaseHelper.backUp,
        startAt: DateTime.now().add(Duration(seconds: initialDelay)),
        wakeup: true,
        exact: true
    );
  }
}
