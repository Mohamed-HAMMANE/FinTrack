import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../Helpers/Funcs.dart';
import '../Models/Category.dart';
import '../Models/Expense.dart';
import 'CategoryExpenses.dart';
import 'Charts.dart';
import 'Expense.dart';
import 'Expenses.dart';
import 'QuickAddSheet.dart';
import 'Settings.dart';
import '../Helpers/SyncHelper.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  DateTime _selectedDate = DateTime.now();
  List<Expense> _expenses = [];
  bool _isLoading = true;
  bool _showSaving = false;
  bool _isSyncing = false;
  int _selectedIndex = 0;

  final LocalAuthentication auth = LocalAuthentication();

  Widget _buildGradientCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradient,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
        ),
        child: Stack(
          children: [
            // Subtle dark overlay to improve text contrast
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.08),
                      Colors.black.withOpacity(0.25),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Icon(
                        icon,
                        color: Colors.white.withOpacity(0.6),
                        size: 20,
                      ),
                    ],
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  @override
  void dispose() {
    super.dispose();
  }

  double _totalBalance = 0;
  double _totalIncome = 0;
  double _totalOutcome = 0;
  double _totalSavings = 0;

  Future<void> _fetchExpenses({bool indicator = false}) async {
    // 1. Calculate start/end of the selected month
    final start = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final end = DateTime(
      _selectedDate.year,
      _selectedDate.month + 1,
      0,
      23,
      59,
      59,
    );

    // 2. Fetch only this month's expenses
    final expenses = await Expense.getByDateRange(start, end);

    // 3. Fetch total balance separately
    final totalBalance = await Expense.getTotalBalance();

    // 4. Fetch lifetime totals
    final lifetimeTotals = await Expense.getLifetimeTotals();

    setState(() {
      _expenses = expenses;
      _totalBalance = totalBalance;
      _totalIncome = lifetimeTotals['income']!;
      _totalOutcome = lifetimeTotals['outcome']!;
      _totalSavings = lifetimeTotals['savings']!;
      _isLoading = false;
      Func.updateWidgetData(_expenses);
    });
    if (indicator) {
      Func.showToast('Refreshed successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final total = _totalBalance;
    final savings = _totalSavings;
    final income = _totalIncome;
    final outcome = _totalOutcome;

    // Keep savingExpenses for the list view navigation (shows only current month items)
    var savingExpenses = _expenses.where(
      (element) => element.category.name == 'Emergency Fund',
    );

    var monthExpenses = _expenses.where(
      (element) =>
          element.date.year == _selectedDate.year &&
          element.date.month == _selectedDate.month,
    );
    final monthResult = monthExpenses.fold(
      0.0,
      (sum, item) => sum + item.amount,
    );
    final monthIncome = monthExpenses.fold(
      0.0,
      (sum, item) => sum + (item.amount >= 0 ? item.amount : 0),
    );
    final monthOutcome = monthExpenses.fold(
      0.0,
      (sum, item) => sum + (item.amount < 0 ? item.amount : 0),
    );

    var dayExpenses = _expenses
        .where(
          (element) =>
              element.date.year == _selectedDate.year &&
              element.date.month == _selectedDate.month &&
              element.date.day == _selectedDate.day,
        )
        .toList();
    final dayResult = dayExpenses.fold(0.0, (sum, item) => sum + item.amount);
    final dayIncome = dayExpenses.fold(
      0.0,
      (sum, item) => sum + (item.amount >= 0 ? item.amount : 0),
    );
    final dayOutcome = dayExpenses.fold(
      0.0,
      (sum, item) => sum + (item.amount < 0 ? item.amount : 0),
    );

    var categories = List<Category>.empty(growable: true);
    for (var expense in dayExpenses) {
      if (categories.any((c) => c.id == expense.category.id)) {
        categories.singleWhere((c) => c.id == expense.category.id).result +=
            expense.amount;
      } else {
        expense.category.result = expense.amount;
        categories.add(expense.category);
      }
    }

    var sCat = categories.where((t) => t.selected).firstOrNull;
    var selectedExpenses = sCat != null
        ? dayExpenses.where((t) => t.category.id == sCat.id).toList()
        : [];

    final ratio = 5 / 2;

    return Scaffold(
      appBar: AppBar(
        title: _selectedIndex == 0
            ? Row(
                spacing: 10,
                children: [
                  Image.asset('assets/big_icon.png', height: 40),
                  Text("FinTrack"),
                ],
              )
            : Text(_selectedIndex == 1 ? "Analytics" : "Settings"),
        actions: [
          IconButton(
            onPressed: _isSyncing ? null : _handleQuickSync,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
            tooltip: 'Quick Sync to Web App',
          ),
          PopupMenuButton<String>(
            onSelected: (String result) async {
              if (result == 'Sync') {
                setState(() => _selectedIndex = 2);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'Sync',
                child: Text('Settings & Sync'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedIndex == 1
          ? CategoryExpensePieChart(_selectedDate, isSubView: true)
          : _selectedIndex == 2
          ? const Settings(isSubView: true)
          : RefreshIndicator(
              onRefresh: () => _fetchExpenses(indicator: true),
              triggerMode: RefreshIndicatorTriggerMode.anywhere,
              child: ListView(
                children: [
                  GridView.count(
                    physics: const ScrollPhysics(),
                    childAspectRatio: ratio,
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    children: [
                      _buildGradientCard(
                        title: "Result",
                        value: NumberFormat.decimalPatternDigits(
                          locale: 'fr_fr',
                          decimalDigits: 2,
                        ).format(total),
                        icon: Icons.account_balance_wallet,
                        gradient: [
                          const Color(0xFF6A11CB),
                          const Color(0xFF2575FC),
                        ],
                        onTap: () async {
                          var res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExpensesState(_expenses),
                            ),
                          );
                          if (res == true) setState(() {});
                        },
                      ),
                      _buildGradientCard(
                        title: "Saving",
                        value: _showSaving
                            ? NumberFormat.decimalPatternDigits(
                                locale: 'fr_fr',
                                decimalDigits: 2,
                              ).format(savings)
                            : '********',
                        icon: Icons.savings,
                        gradient: [
                          const Color(0xFFE94057),
                          const Color(0xFFF27121),
                        ],
                        onTap: () async {
                          if (!_showSaving) {
                            try {
                              bool authenticated = await auth.authenticate(
                                localizedReason:
                                    'Please authenticate to see Saving amount',
                                biometricOnly: true,
                              );
                              setState(() {
                                _showSaving = authenticated;
                              });
                            } catch (e) {}
                          } else {
                            setState(() {
                              _showSaving = !_showSaving;
                            });
                          }
                        },
                        onLongPress: () async {
                          if (_showSaving) {
                            var res = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ExpensesState(savingExpenses.toList()),
                              ),
                            );
                            if (res == true) setState(() {});
                          }
                        },
                      ),
                      _buildGradientCard(
                        title: "Income",
                        value: NumberFormat.decimalPatternDigits(
                          locale: 'fr_fr',
                          decimalDigits: 2,
                        ).format(income),
                        icon: Icons.trending_up,
                        gradient: [
                          const Color(0xFF0BA360),
                          const Color(0xFF3CBA92),
                        ],
                        onTap: () async {
                          var res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExpensesState(
                                _expenses
                                    .where((exp) => exp.amount > 0)
                                    .toList(),
                              ),
                            ),
                          );
                          if (res == true) setState(() {});
                        },
                      ),
                      _buildGradientCard(
                        title: "Outcome",
                        value: NumberFormat.decimalPatternDigits(
                          locale: 'fr_fr',
                          decimalDigits: 2,
                        ).format(outcome),
                        icon: Icons.trending_down,
                        gradient: [
                          const Color(0xFFED213A),
                          const Color(0xFF93291E),
                        ],
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    child: Divider(),
                  ),
                  // Date Switcher Header
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: _goBackOneDay,
                          icon: const Icon(Icons.chevron_left, size: 20),
                        ),
                        InkWell(
                          onTap: () => _pickDate(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, size: 14),
                                const SizedBox(width: 8),
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          onPressed: _goForwardOneDay,
                          icon: const Icon(Icons.chevron_right, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    child: Divider(),
                  ),
                  Card(
                    key: ValueKey(1),
                    child: Dismissible(
                      key: ValueKey(1),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Icon(Icons.details, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.green,
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Icon(Icons.category, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          var res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ExpensesState(monthExpenses.toList()),
                            ),
                          );
                          if (res == true) setState(() {});
                        } else if (direction == DismissDirection.endToStart) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CategoryExpensesState(monthExpenses.toList()),
                            ),
                          );
                        }
                        return false;
                      },
                      child: ListTile(
                        onTap: () async {
                          var res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ExpensesState(monthExpenses.toList()),
                            ),
                          );
                          if (res == true) setState(() {});
                        },
                        leading: Icon(Icons.calendar_month),
                        title: Text(DateFormat('MMMM').format(_selectedDate)),
                        subtitle: Column(
                          children: [
                            Text(
                              NumberFormat.decimalPatternDigits(
                                locale: 'fr_fr',
                                decimalDigits: 2,
                              ).format(monthResult),
                              style: TextStyle(
                                fontSize: 30,
                                color: monthResult >= 0
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            LinearProgressIndicator(
                              value:
                                  -monthOutcome /
                                  (monthIncome == 0 ? 1 : monthIncome),
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                -monthOutcome > monthIncome
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                            Text(
                              -monthOutcome > monthIncome
                                  ? 'Over budget by ${((-monthOutcome / (monthIncome == 0 ? 1 : monthIncome) * 100) - 100).toStringAsFixed(2)}%'
                                  : 'Remaining budget: ${(100 - (-monthOutcome / (monthIncome == 0 ? 1 : monthIncome) * 100)).toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 14,
                                color: -monthOutcome > monthIncome
                                    ? Colors.red
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              NumberFormat.decimalPatternDigits(
                                locale: 'fr_fr',
                                decimalDigits: 2,
                              ).format(monthOutcome),
                            ),
                            Text(
                              NumberFormat.decimalPatternDigits(
                                locale: 'fr_fr',
                                decimalDigits: 2,
                              ).format(monthIncome),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Divider(color: Colors.blue),
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.calendar_today),
                      title: Text(DateFormat('EEEE').format(_selectedDate)),
                      subtitle: Text(
                        NumberFormat.decimalPatternDigits(
                          locale: 'fr_fr',
                          decimalDigits: 2,
                        ).format(dayResult),
                        style: TextStyle(
                          fontSize: 20,
                          color: dayResult >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            NumberFormat.decimalPatternDigits(
                              locale: 'fr_fr',
                              decimalDigits: 2,
                            ).format(dayOutcome),
                          ),
                          Text(
                            NumberFormat.decimalPatternDigits(
                              locale: 'fr_fr',
                              decimalDigits: 2,
                            ).format(dayIncome),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (categories.isNotEmpty) Divider(color: Colors.blue),
                  GridView.builder(
                    itemCount: categories.length,
                    physics: const ScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: ratio,
                    ),
                    itemBuilder: (context, index) {
                      var cat = categories[index];
                      return Card(
                        child: ListTile(
                          selected: cat.selected,
                          onTap: () {
                            if (!cat.selected) {
                              var t = categories
                                  .where((t) => t.selected)
                                  .firstOrNull;
                              if (t != null) t.selected = false;
                            }
                            setState(() {
                              cat.selected = !cat.selected;
                            });
                          },
                          leading: Icon(cat.icon),
                          title: Text(
                            NumberFormat.decimalPatternDigits(
                              locale: 'fr_fr',
                              decimalDigits: 2,
                            ).format(cat.result),
                            style: TextStyle(
                              fontSize: 18,
                              color: cat.result >= 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          subtitle: Text(cat.name),
                          trailing: cat.selected
                              ? Icon(Icons.check_circle)
                              : Icon(Icons.radio_button_unchecked),
                        ),
                      );
                    },
                  ),
                  if (dayExpenses.isNotEmpty) Divider(color: Colors.blue),
                  GridView.builder(
                    itemCount: selectedExpenses.isEmpty
                        ? dayExpenses.length
                        : selectedExpenses.length,
                    physics: const ScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: ratio,
                    ),
                    itemBuilder: (context, index) {
                      Expense exp = selectedExpenses.isEmpty
                          ? dayExpenses[index]
                          : selectedExpenses[index];
                      return Card(
                        child: ListTile(
                          onTap: () async {
                            var res = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ExpenseState(_expenses, expense: exp),
                              ),
                            );
                            if (res == true) setState(() {});
                          },
                          leading: Icon(exp.category.icon),
                          title: Text(
                            NumberFormat.decimalPatternDigits(
                              locale: 'fr_fr',
                              decimalDigits: 2,
                            ).format(exp.amount),
                            style: TextStyle(
                              fontSize: 18,
                              color: exp.amount >= 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          subtitle: Text(exp.comment),
                          //trailing: Text(exp.category.name)
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 70),
                ],
              ),
            ),
      floatingActionButton: _selectedIndex != 0
          ? null
          : Stack(
              children: [
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    heroTag: "btn1",
                    onPressed: _isLoading
                        ? null
                        : () async {
                            var res = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ExpenseState(_expenses),
                              ),
                            );
                            if (res == true) setState(() {});
                          },
                    child: const Icon(Icons.add),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 86,
                  child: FloatingActionButton(
                    heroTag: "btn_quick",
                    mini: true,
                    backgroundColor: Colors.amber,
                    onPressed: _isLoading
                        ? null
                        : () async {
                            var res = await showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) => const QuickAddSheet(),
                            );
                            if (res == true) _fetchExpenses(indicator: true);
                          },
                    child: const Icon(Icons.flash_on, color: Colors.black),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart_outline),
            activeIcon: Icon(Icons.pie_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _goBackOneDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(Duration(days: 1));
    });
    _fetchExpenses();
  }

  void _goForwardOneDay() {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: 1));
    });
    _fetchExpenses();
  }

  Future<void> _pickDate(BuildContext context) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
      _fetchExpenses();
    }
  }

  Future<void> _handleQuickSync() async {
    setState(() {
      _isSyncing = true;
    });

    final success = await SyncHelper.syncWithSavedIp();

    setState(() {
      _isSyncing = false;
    });

    if (success) {
      Func.showToast('Cloud Sync Successful!');
    }
  }
}
