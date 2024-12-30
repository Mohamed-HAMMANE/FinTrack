import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Helpers/Funcs.dart';
import '../Models/Expense.dart';
import 'Expense.dart';

class CategoryExpensesState extends StatefulWidget {
  final List<Expense> expenses;
  const CategoryExpensesState(this.expenses,{super.key});

  @override
  State<CategoryExpensesState> createState() => _CategoryExpensesState();
}

class _CategoryExpensesState extends State<CategoryExpensesState> {
  bool _somethingAdded = false;

  @override
  Widget build(BuildContext context) {

    final groupedExpenses = groupBy(widget.expenses, (Expense exp) => exp.category);
    final groupedEntries = groupedExpenses.entries.toList();

    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(title: Text('Expenses by category')),
        body: SingleChildScrollView(
          child: ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            /*gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.25,
            ),*/
            itemCount: groupedEntries.length,
            itemBuilder: (context, index) {
              final group = groupedEntries[index];
              var expenses = group.value;
              var sum = expenses.fold(0.0, (sum, item) => sum + item.amount);
              return ExpansionTile(
                initiallyExpanded: false,
                leading: Icon(group.key.icon),
                title: Text(group.key.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(sum),
                  style: TextStyle(color: sum >= 0 ? Colors.green : Colors.red),
                ),
                trailing: Text(
                  NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 0).format(expenses.length),
                  style: TextStyle(color: sum >= 0 ? Colors.green : Colors.red),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                  side: BorderSide(style: BorderStyle.solid,color: Theme.of(context).dividerColor)
                ),
                children: [
                  GridView.builder(
                    //padding: EdgeInsets.symmetric(vertical: 0),
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 5/1.9,
                    ),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) {
                      final exp = expenses[index];
                      return Card(
                          key: ValueKey(exp.id),
                          child: Dismissible(
                              key: ValueKey(exp.id),
                              background: Container(
                                color: Colors.green,
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Icon(Icons.edit, color: Colors.white),
                              ),
                              secondaryBackground: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: EdgeInsets.symmetric(horizontal: 20),
                                child: Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  _editExpense(exp);
                                } else if (direction == DismissDirection.endToStart) {
                                  _somethingAdded = await _deleteExpense(context, exp);
                                  return _somethingAdded;
                                }
                                return false;
                              },
                              child: ListTile(
                                onTap: () => _editExpense(exp),
                                leading: Text(DateFormat('dd/MM/yyyy').format(exp.date)),
                                title: Text(
                                    NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(exp.amount),
                                    style: TextStyle(fontSize: 18,color: exp.amount >= 0 ? Colors.green : Colors.red)
                                ),
                                subtitle: Text(exp.comment),
                                //trailing : Text(exp.category.name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17))
                              )
                          )
                      );
                    }
                  )
                ],
              );
            }
          )
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: "btn1",
          child: const Icon(Icons.add),
          onPressed: () async {
            _somethingAdded = await Navigator.push(context, MaterialPageRoute(builder:(context)=>ExpenseState(widget.expenses)));
            if(_somethingAdded == true) setState(() { });
          }
        ),
      ),
    );
  }

  Future<bool> onWillPop() {
    Navigator.of(context).pop(_somethingAdded);
    return Future.value(true);
  }

  Future<void> _editExpense(Expense exp) async {
    _somethingAdded = await Navigator.push(context, MaterialPageRoute(builder: (context) => ExpenseState(widget.expenses,expense: exp)));
    if(_somethingAdded == true) setState(() { });
  }

  Future<bool> _deleteExpense(BuildContext context, Expense expense) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.comment}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(
              onPressed: () async {
                var nbr = await expense.delete();
                if(nbr == 1){
                  _somethingAdded = true;
                  setState(() {
                    widget.expenses.remove(expense);
                  });
                  await Func.updateWidgetData(widget.expenses);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Expense deleted successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context,true);
                }
                else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cannot delete this expense !!!'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  Navigator.pop(context,false);
                }
              },
              child: Text('Delete')
          ),
        ],
      ),
    );
  }
}
