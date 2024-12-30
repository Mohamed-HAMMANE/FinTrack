import 'package:sqflite/sqflite.dart';

import '../Helpers/DatabaseHelper.dart';
import 'Category.dart';

class Expense{
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
    required this.category
  });

  Map<String,Object?> toMap() {
    return {'Amount': amount, 'Date': date.toIso8601String(), 'Comment': comment, 'CategoryId':category.id};
  }

  factory Expense.fromMap(Map<String, dynamic> json) {
    return Expense(
      id: json['Id'],
      amount: json['Amount'],
      date: DateTime.parse(json['Date']),
      comment: json['Comment'],
      category: Category.fromOtherMap(json)
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

  /*static Future<double> getTotal() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery("SELECT SUM(amount) as total FROM Expense");
    return result.first["total"] == null ? 0.0 : double.parse(result.first["total"].toString());
  }

  static Future<double> getMonthly(DateTime date) async {
    final db = await DatabaseHelper.instance.database;
    final firstDay = DateTime(date.year, date.month, 1).toIso8601String();
    final lastDay = DateTime(date.year, date.month + 1, 0).toIso8601String();

    final result = await db.rawQuery("""
      SELECT SUM(amount) as total 
      FROM Expense 
      WHERE date BETWEEN ? AND ?
    """, [firstDay, lastDay]);

    return result.first["total"] == null ? 0.0 : double.parse(result.first["total"].toString());
  }

  static Future<double> getDaySum(DateTime date) async {
    final db = await DatabaseHelper.instance.database;
    final day = DateTime(date.year, date.month, date.day).toIso8601String();

    final result = await db.rawQuery("""
      SELECT SUM(amount) as total 
      FROM Expense 
      WHERE date = ?
    """, [day]);

    return result.first["total"] == null ? 0.0 : double.parse(result.first["total"].toString());
  }

  static Future<List<Map<String, dynamic>>> getDayExpenses(DateTime date) async {
    final db = await DatabaseHelper.instance.database;
    final day = DateTime(date.year, date.month, date.day).toIso8601String();

    return await db.rawQuery("""
      SELECT * FROM Expense 
      WHERE date = ?
      ORDER BY date DESC
    """, [day]);
  }*/

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
    await db.update(
        'Expense',
        toMap(),
        where: 'Id = ?', whereArgs: [id]
    );
  }

  Future<void> save() async => await (id <= 0 ? insert() : update());

  Future<int> delete() async {
    try{
      final db = await (DatabaseHelper.instance.database);
      return await db.delete('Expense', where: 'Id = $id');
    }
    catch (e) {
      return 0;
    }
  }


}