import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../Helpers/DatabaseHelper.dart';

class Category{
  int id;
  String name;
  double budget;
  int order;
  int iconCode;

  double result = 0;
  bool selected = false;

  Category({
    required this.id,
    required this.name,
    required this.budget,
    required this.order,
    required this.iconCode
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Category && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;


  Map<String,Object?> toMap() {
    return {'Name': name, 'Budget': budget, 'IconCode': iconCode, 'Order': order};
  }

  factory Category.fromMap(Map<String, dynamic> json) {
    return Category(
      id: json['Id'],
      name: json['Name'],
      budget: json['Budget'],
      order: json['Order'],
      iconCode: json['IconCode']
    );
  }

  factory Category.fromOtherMap(Map<String, dynamic> json) {
    return Category(
        id: json['CategoryId'],
        name: json['CategoryName'],
        budget: json['CategoryBudget'],
        order: json['CategoryOrder'],
        iconCode: json['CategoryIconCode']
    );
  }

  IconData get icon => iconCode == 0 ? Icons.question_mark : IconData(iconCode, fontFamily: 'MaterialIcons');

  static Future<List<Category>> getAll() async {
    final result = await DatabaseHelper.select('''SELECT * FROM Category ORDER BY [Order];''');
    return result.map((row) => Category.fromMap(row)).toList();
  }

  Future<int> insert() async {
    final db = await (DatabaseHelper.instance.database);
    id = await db.insert(
      'Category',
      toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  Future<void> update() async {
    final db = await (DatabaseHelper.instance.database);
    await db.update(
      'Category',
      toMap(),
      where: 'id = ?', whereArgs: [id]
    );
  }

  Future<int> delete() async {
    try{
      final db = await (DatabaseHelper.instance.database);
      return await db.delete('Category', where: 'Id = $id');
    }
    catch (e) {
      return 0;
    }
  }

  static Future<void> updateOrder(List<Category> categories) async {
    final db = await (DatabaseHelper.instance.database);
    final batch = db.batch();
    for (int i = 0; i < categories.length; i++) {
      batch.update('Category',{'Order': i}, where: 'id = ?', whereArgs: [categories[i].id]);
    }
    await batch.commit(noResult: true);
  }

}