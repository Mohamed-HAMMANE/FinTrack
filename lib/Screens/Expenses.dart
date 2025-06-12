import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';

import '../Helpers/Funcs.dart';
import '../Models/Expense.dart';
import 'Expense.dart';

class ExpensesState extends StatefulWidget {
  final List<Expense> expenses;
  const ExpensesState(this.expenses, {super.key});

  @override
  State<ExpensesState> createState() => _ExpensesState();
}

class _ExpensesState extends State<ExpensesState> {
  bool _somethingAdded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 1) Filter by search query (on comment)
  List<Expense> get _filteredExpenses {
    if (_searchQuery.isEmpty) return widget.expenses;
    final q = _searchQuery.toLowerCase();
    return widget.expenses
        .where((exp) => exp.comment.toLowerCase().contains(q))
        .toList();
  }

  // 2) Sum of filtered amounts
  double get _totalFilteredAmount =>
      _filteredExpenses.fold(0.0, (sum, item) => sum + item.amount);

  @override
  Widget build(BuildContext context) {
    final filteredExpenses = _filteredExpenses;
    final groupedExpenses = groupBy<Expense, String>(
      filteredExpenses,
          (exp) => DateFormat('EEEE dd/MM/yyyy').format(exp.date),
    );
    final groupedEntries = groupedExpenses.entries.toList();

    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Expenses ${widget.expenses.length}'),
        ),
        body: Column(
          children: [
            // ───── Search Bar ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search expenses',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // ───── Total Filtered Amount ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    NumberFormat.decimalPatternDigits(
                      locale: 'fr_fr',
                      decimalDigits: 2,
                    ).format(_totalFilteredAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _totalFilteredAmount >= 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            ),

            // ───── Filtered & Grouped List ─────
            Expanded(
              child: CustomScrollView(
                slivers: [
                  ...groupedEntries.map((group) {
                    final date = group.key;
                    final expensesForDay = group.value;
                    final sum = expensesForDay
                        .fold(0.0, (sum, item) => sum + item.amount);

                    return SliverStickyHeader(
                      header: Container(
                        padding: const EdgeInsets.all(15.0),
                        color: Theme.of(context).primaryColor,
                        child: Row(
                          children: [
                            Text(
                              '$date ',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18),
                            ),
                            Text(
                              '(${NumberFormat.decimalPatternDigits(
                                locale: 'fr_fr',
                                decimalDigits: 2,
                              ).format(sum)})',
                              style: TextStyle(
                                  fontSize: 17,
                                  color:
                                  sum >= 0 ? Colors.green : Colors.red),
                            ),
                          ],
                        ),
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final exp = expensesForDay[index];
                            return Card(
                              child: ListTile(
                                onTap: () => _editExpense(exp),
                                leading: Column(
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Icon(exp.category.icon),
                                    Text(
                                      exp.category.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  NumberFormat.decimalPatternDigits(
                                    locale: 'fr_fr',
                                    decimalDigits: 2,
                                  ).format(exp.amount),
                                  style: TextStyle(
                                      fontSize: 18,
                                      color: exp.amount >= 0
                                          ? Colors.green
                                          : Colors.red),
                                ),
                                subtitle: Text(exp.comment),
                                trailing: IconButton(
                                  onPressed: () =>
                                      _deleteExpense(context, exp),
                                  icon:
                                  const Icon(Icons.delete_forever),
                                ),
                              ),
                            );
                          },
                          childCount: expensesForDay.length,
                        ),
                      ),
                    );
                  }),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: 100.0)),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: "btn1",
          child: const Icon(Icons.add),
          onPressed: () async {
            _somethingAdded = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ExpenseState(widget.expenses),
              ),
            );
            if (_somethingAdded == true) setState(() {});
          },
        ),
      ),
    );
  }

  Future<bool> onWillPop() {
    Navigator.of(context).pop(_somethingAdded);
    return Future.value(true);
  }

  Future<void> _editExpense(Expense exp) async {
    _somethingAdded = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ExpenseState(widget.expenses, expense: exp),
      ),
    );
    if (_somethingAdded == true) setState(() {});
  }

  Future<bool> _deleteExpense(
      BuildContext context, Expense expense) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content:
        Text('Are you sure you want to delete "${expense.comment}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              var nbr = await expense.delete();
              if (nbr == 1) {
                _somethingAdded = true;
                setState(() {
                  widget.expenses.remove(expense);
                });
                await Func.updateWidgetData(widget.expenses);
                Func.showToast('Expense deleted successfully.');
              } else {
                Func.showToast('Cannot delete this expense !!!',
                    type: 'error');
              }
              if (mounted) Navigator.pop(context, nbr == 1);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
