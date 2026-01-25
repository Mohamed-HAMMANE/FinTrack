import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:home_widget/home_widget.dart';

import '../Models/Expense.dart';

class Func{

  static bool isNumeric(String? s) {
    if(s == null) return false;
    if(isNull(s)) return false;
    return double.tryParse(s) != null;
  }
  static bool isNull(String? val) => val == null || val.trim() == "" || val.trim() == "null";


  static Future<void> updateWidgetData(List<Expense> expenses) async {
    try {
      final total = expenses.fold(0.0, (sum, item) => sum + item.amount);
      await HomeWidget.saveWidgetData<String>('value1', "$total");
      var date = DateTime.now();
      var monthExpenses = expenses.where((element) => element.date.year == date.year && element.date.month == date.month);
      double monthResult = monthExpenses.fold(0.0, (sum, item) => sum + item.amount);
      await HomeWidget.saveWidgetData<String>('value2', "$monthResult");

      await HomeWidget.updateWidget(name: 'MyAppWidgetProvider');
      //print('Widget updated successfully.');
    } catch (e) {
      //print('Error updating widget: $e');
    }
  }

  static final List<Color> colorsList = [
    Colors.orange,
    Colors.limeAccent,
    Colors.orangeAccent,
    Colors.lightBlueAccent,
    Colors.lightGreen,
    Colors.deepOrangeAccent,
    Colors.yellow,
    Colors.lightGreenAccent,
    Colors.deepOrange,
    Colors.lime,
    Colors.yellowAccent,
    Colors.lightBlue,
    Colors.amber,
    Colors.amberAccent,
    Colors.tealAccent,
    Colors.cyan,
    Colors.cyanAccent,
    Colors.pinkAccent,
    Colors.redAccent,
    Colors.purpleAccent,
    Colors.indigoAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.indigo,
    Colors.purple,
    Colors.blueGrey,
    Colors.brown,
    Colors.lightBlueAccent.shade100,
    Colors.lightGreenAccent.shade100,
    Colors.orangeAccent.shade100,
    Colors.amber.shade100,
  ];

  static Future<bool?> showToast(String message, {String type = 'success'}){
    return Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      fontSize: 16.0,
      backgroundColor: type == 'success' ? Colors.green : type == 'error' ? Colors.red : null
    );
  }


}