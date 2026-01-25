import 'package:sqflite/sqflite.dart';

import '../Helpers/DatabaseHelper.dart';
import 'Category.dart';

class Expense {
  int id;
  double amount;
  DateTime date;
  String comment;
  Category category;

  Expense({
    required this.id,
    required this.amount,
    required this.date,
    required this.comment,
    required this.category,
  });

  Map<String, Object?> toMap() {
    return {
      'Amount': amount,
      'Date': date.toIso8601String(),
      'Comment': comment,
      'CategoryId': category.id,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> json) {
    return Expense(
      id: json['Id'],
      amount: json['Amount'],
      date: DateTime.parse(json['Date']),
      comment: json['Comment'],
      category: Category.fromOtherMap(json),
    );
  }

  static Future<List<Expense>> getAll() async {
    /*var day = date.day;
    var month = date.month;
    var year = date.year;*/
    final result = await DatabaseHelper.select('''
      SELECT ex.Id, ex.Amount, ex.Date, ex.Comment, ex.CategoryId, cat.Name CategoryName, cat.Budget CategoryBudget, cat.[Order] CategoryOrder, cat.IconCode CategoryIconCode
      FROM Expense ex INNER JOIN Category cat ON ex.CategoryId = cat.Id 
      ORDER BY ex.[Date] DESC;
    ''');
    return result.map((row) => Expense.fromMap(row)).toList();
  }

  // New optimized fetch method
  static Future<List<Expense>> getByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final result = await DatabaseHelper.selectByDateRange(start, end);
    return result.map((row) => Expense.fromMap(row)).toList();
  }

  static Future<double> getTotalBalance() async {
    return await DatabaseHelper.getTotalBalance();
  }

  static Future<Map<String, double>> getLifetimeTotals() async {
    return await DatabaseHelper.getLifetimeTotals();
  }

  Future<int> insert() async {
    final db = await (DatabaseHelper.instance.database);
    id = await db.insert(
      'Expense',
      toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<void> update() async {
    final db = await (DatabaseHelper.instance.database);
    await db.update('Expense', toMap(), where: 'Id = ?', whereArgs: [id]);
  }

  Future<void> save() async => await (id <= 0 ? insert() : update());

  Future<int> delete() async {
    try {
      final db = await (DatabaseHelper.instance.database);
      return await db.delete('Expense', where: 'Id = $id');
    } catch (e) {
      return 0;
    }
  }
}
