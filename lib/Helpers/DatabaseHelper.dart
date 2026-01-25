import 'dart:io';

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'Funcs.dart';

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
      onUpgrade: _onUpgrade,
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
        CreationDate TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
      );
    ''');

    await db.execute('''
      CREATE TABLE Expense (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Amount REAL NOT NULL,
        Date TEXT NOT NULL,
        Comment TEXT,
        CreationDate TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
        CategoryId INTEGER NOT NULL,
        FOREIGN KEY (CategoryId) REFERENCES Category (Id) ON DELETE RESTRICT
      );
    ''');

    await db.execute('CREATE INDEX idx_expense_date ON Expense(Date);');
    await db.execute(
      'CREATE INDEX idx_expense_category ON Expense(CategoryId);',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {}
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  static Future<List<Map<String, Object?>>> select(String query) async {
    final db = await instance.database;
    return await db.rawQuery(query);
  }

  // New optimized method for range queries
  static Future<List<Map<String, Object?>>> selectByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await instance.database;
    final startStr = DateFormat('yyyy-MM-dd').format(start);
    final endStr = DateFormat('yyyy-MM-dd').format(end);

    return await db.rawQuery(
      '''
      SELECT ex.Id, ex.Amount, ex.Date, ex.Comment, ex.CategoryId, 
             cat.Name CategoryName, cat.Budget CategoryBudget, 
             cat.[Order] CategoryOrder, cat.IconCode CategoryIconCode
      FROM Expense ex 
      INNER JOIN Category cat ON ex.CategoryId = cat.Id 
      WHERE ex.Date BETWEEN ? AND ?
      ORDER BY ex.[Date] DESC, ex.CreationDate DESC
    ''',
      [startStr, endStr],
    );
  }

  // Optimized method for total balance (all time)
  static Future<double> getTotalBalance() async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(Amount) as Total FROM Expense',
    );
    if (result.isNotEmpty && result.first['Total'] != null) {
      return (result.first['Total'] as num).toDouble();
    }
    return 0.0;
  }

  static Future<Map<String, double>> getLifetimeTotals() async {
    final db = await instance.database;

    // 1. Total Income & Outcome
    final incOutResult = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN Amount >= 0 THEN Amount ELSE 0 END) as Income,
        SUM(CASE WHEN Amount < 0 THEN Amount ELSE 0 END) as Outcome
      FROM Expense
    ''');

    double income = 0;
    double outcome = 0;
    if (incOutResult.isNotEmpty) {
      income = (incOutResult.first['Income'] as num?)?.toDouble() ?? 0.0;
      outcome = (incOutResult.first['Outcome'] as num?)?.toDouble() ?? 0.0;
    }

    // 2. Emergency Fund Savings
    final savingsResult = await db.rawQuery('''
      SELECT SUM(ex.Amount) as Total
      FROM Expense ex
      JOIN Category cat ON ex.CategoryId = cat.Id
      WHERE cat.Name = 'Emergency Fund'
    ''');

    double savings = 0;
    if (savingsResult.isNotEmpty) {
      // Savings are stored as negative expenses, so flip the sign
      savings =
          ((savingsResult.first['Total'] as num?)?.toDouble() ?? 0.0) * -1;
    }

    return {'income': income, 'outcome': outcome, 'savings': savings};
  }

  static Future<bool> backUp() async {
    try {
      final dbPath = await getDatabasesPath();
      final dbFilePath = path.join(dbPath, '$_databaseName.db');
      final downloadsDir = Directory('/storage/emulated/0/Download');
      final dbFile = File(dbFilePath);
      var now = DateTime.now();
      final newFilePath = path.join(
        downloadsDir.path,
        '${_databaseName}_backup_${now.year}_${now.month}_${now.day}_${now.hour}_${now.minute}_${now.second}.db',
      ); // New file name in Downloads
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
        Func.showToast('Backup file not found in Downloads folder.');
        return false;
      }
      await backupFile.copy(appDbPath);

      Func.showToast('Database restored successfully!');
      return true;
    } else {
      Func.showToast('No file selected.', type: 'error');
    }
    return false;
  }
}
