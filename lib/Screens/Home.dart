import 'package:flutter/material.dart';
//import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../Helpers/DatabaseHelper.dart';
import '../Helpers/Funcs.dart';
import '../Models/Category.dart';
import '../Models/Expense.dart';
import 'Categories.dart';
import 'CategoryExpenses.dart';
import 'Charts.dart';
import 'Expense.dart';
import 'Expenses.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  //bool _overlayEnabled = false;

  DateTime _selectedDate = DateTime.now();
  List<Expense> _expenses = [];
  bool _isLoading = true;
  bool _showSaving = false;

  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    DatabaseHelper.dailyBackup();
    _fetchExpenses();
    //_checkOverlayPermission();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /*Future<void> _checkOverlayPermission() async {
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      await FlutterOverlayWindow.requestPermission();
    }
    //_toggleOverlay();
  }*/


  /*Future<void> _toggleOverlay() async {
    if (_overlayEnabled) {
      // Hide overlay
      await FlutterOverlayWindow.closeOverlay();
    } else {
      // Show overlay (the plugin might provide config for icon position, size, etc.)
      await FlutterOverlayWindow.showOverlay(
        overlayTitle: "My Overlay",
        overlayContent: "Tap to return to MyApp",
        height: 250,
        width: 250,
        enableDrag: true,
        flag: OverlayFlag.focusPointer
      );

      FlutterOverlayWindow.overlayListener.listen((event) async {

      });
    }
    setState(() {
      _overlayEnabled = !_overlayEnabled;
    });
  }*/


  Future<void> _fetchExpenses({bool indicator = false}) async {
    final expenses = await Expense.getAll();
    setState(() {
      _expenses = expenses;
      _isLoading = false;
      Func.updateWidgetData(_expenses);
    });
    if(indicator){
      Func.showToast('Refreshed successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final total = _expenses.fold(0.0, (sum, item) => sum + item.amount);
    var savingExpenses = _expenses.where((element) => element.category.name == 'Emergency Fund');
    final savings = savingExpenses.fold(0.0, (sum, item) => sum + item.amount)*-1;
    final income = _expenses.fold(0.0, (sum, item) => sum + (item.amount >= 0?item.amount:0));
    final outcome = _expenses.fold(0.0, (sum, item) => sum + (item.amount < 0?item.amount:0));

    var monthExpenses = _expenses.where((element) => element.date.year == _selectedDate.year && element.date.month == _selectedDate.month);
    final monthResult = monthExpenses.fold(0.0, (sum, item) => sum + item.amount);
    final monthIncome = monthExpenses.fold(0.0, (sum, item) => sum + (item.amount >= 0?item.amount:0));
    final monthOutcome = monthExpenses.fold(0.0, (sum, item) => sum + (item.amount < 0?item.amount:0));

    var dayExpenses = _expenses.where((element) => element.date.year == _selectedDate.year && element.date.month == _selectedDate.month && element.date.day == _selectedDate.day).toList();
    final dayResult = dayExpenses.fold(0.0, (sum, item) => sum + item.amount);
    final dayIncome = dayExpenses.fold(0.0, (sum, item) => sum + (item.amount >= 0?item.amount:0));
    final dayOutcome = dayExpenses.fold(0.0, (sum, item) => sum + (item.amount < 0?item.amount:0));

    var categories = List<Category>.empty(growable: true);
    for (var expense in dayExpenses) {
      if (categories.any((c) => c.id == expense.category.id)) {
        categories.singleWhere((c) => c.id ==expense.category.id).result += expense.amount;
      } else {
        expense.category.result = expense.amount;
        categories.add(expense.category);
      }
    }

    var sCat = categories.where((t) => t.selected).firstOrNull;
    var selectedExpenses = sCat != null ? dayExpenses.where((t) => t.category.id == sCat.id).toList() : [];

    final ratio = 5 / 2;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          spacing: 10,
          children: [
            Image.asset('assets/big_icon.png',height: 40),
            Text("FinTrack")
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String result) async {
              if (result == 'Backup') {
                if(await DatabaseHelper.backUp()){
                  Func.showToast('Downloaded successfully.');
                }
                else{
                  Func.showToast('Error on backup.',type: 'error');
                }
              } else if (result == 'Restore') {
                DatabaseHelper.restore(context);
              } else if (result == 'Categories') {
                var res = await Navigator.push(context, MaterialPageRoute(builder: (context) => CategoriesState()));
                if(res == true) _fetchExpenses();
              }
              else if (result == 'Charts') {
                Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryExpensePieChart(_selectedDate)));
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(value: 'Categories', child: Text('Categories')),
              //PopupMenuItem(value: 'Charts', child: Text('Charts')),
              PopupMenuItem(value: 'Backup', child: Text('Backup')),
              PopupMenuItem(value: 'Restore', child: Text('Restore'))
            ]
          )
        ]
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchExpenses(indicator: true),
        triggerMode: RefreshIndicatorTriggerMode.anywhere,
        child: _isLoading ? Center(child: Text("No data ...")) :
        ListView(
          children: [
            GridView.count(
              physics: const ScrollPhysics(),
              childAspectRatio: ratio,
              crossAxisCount: 2,
              shrinkWrap: true,
              children: [
                Card(
                    child: ListTile(
                        onTap: () async {
                          var res = await Navigator.push(context, MaterialPageRoute(builder:(context)=>ExpensesState(_expenses)));
                          if(res == true) setState(() { });
                        },
                        leading: Icon(Icons.all_inclusive),
                        title: const Text("Result"),
                        subtitle: Text(
                            NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(total),
                            style: TextStyle(fontSize: 20,color: total >= 0 ? Colors.green : Colors.red)
                        )
                    )
                ),
                Card(
                    child: ListTile(
                        onLongPress: () async {
                          if(_showSaving){
                            var res = await Navigator.push(context, MaterialPageRoute(builder:(context)=>ExpensesState(savingExpenses.toList())));
                            if(res == true) setState(() { });
                          }
                        },
                        onTap: () async {
                          if(!_showSaving){
                            try {
                              bool authenticated = await auth.authenticate(
                                localizedReason: 'Please authenticate to see Saving amount',
                                options: const AuthenticationOptions(
                                  biometricOnly: true,
                                  stickyAuth: true,
                                ),
                              );
                              setState(() {
                                _showSaving = authenticated;
                              });
                            } catch (e) {
                              //print('Authentication error: $e');
                            }
                          }
                          else {
                            setState(() {
                              _showSaving = !_showSaving;
                            });
                          }
                        },
                        leading: const Icon(Icons.savings, color: Colors.orange),
                        title: const Text("Saving"),
                        subtitle: Text(
                            _showSaving ? NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(savings) : '********',
                            style: TextStyle(fontSize: 20,color: savings >= 0 ? Colors.green : Colors.red)
                        )
                    )
                ),
                Card(
                    child: ListTile(
                        onTap: () async {
                          var res = await Navigator.push(context, MaterialPageRoute(builder:(context)=>ExpensesState(_expenses.where((exp) => exp.amount > 0).toList())));
                          if(res == true) setState(() { });
                        },
                        leading: const Icon(Icons.download, color: Colors.green),
                        title: const Text("Income"),
                        subtitle: Text(
                            NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(income),
                            style: TextStyle(fontSize: 20,color: income >= 0 ? Colors.green : Colors.red)
                        )
                    )
                ),
                Card(
                    child: ListTile(
                        leading: const Icon(Icons.upload, color: Colors.red),
                        title: const Text("Outcome"),
                        subtitle: Text(
                            NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(outcome),
                            style: TextStyle(fontSize: 20,color: outcome >= 0 ? Colors.green : Colors.red)
                        )
                    )
                )
              ],
            ),
            Divider(color: Colors.blue),
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
                        var res = await Navigator.push(context, MaterialPageRoute(builder:(context)=>ExpensesState(monthExpenses.toList())));
                        if(res == true) setState(() { });
                      } else if (direction == DismissDirection.endToStart) {
                        await Navigator.push(context, MaterialPageRoute(builder:(context)=>CategoryExpensesState(monthExpenses.toList())));
                      }
                      return false;
                    },
                    child: ListTile(
                        onTap: () async {
                          var res = await Navigator.push(context, MaterialPageRoute(builder:(context)=>ExpensesState(monthExpenses.toList())));
                          if(res == true) setState(() { });
                        },
                        leading: Icon(Icons.calendar_month),
                        title: Text(DateFormat('MMMM').format(_selectedDate)),
                        subtitle: Column(
                          children: [
                            Text(
                                NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(monthResult),
                                style: TextStyle(fontSize: 30,color: monthResult >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w900)
                            ),
                            LinearProgressIndicator(
                              value: -monthOutcome / (monthIncome == 0 ? 1 : monthIncome),
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                -monthOutcome > monthIncome ? Colors.red : Colors.green,
                              ),
                            ),
                            Text(
                              -monthOutcome > monthIncome
                                  ? 'Over budget by ${((-monthOutcome / (monthIncome == 0 ? 1 : monthIncome)*100)-100).toStringAsFixed(2)}%'
                                  : 'Remaining budget: ${(100-(-monthOutcome / (monthIncome == 0 ? 1 : monthIncome)*100)).toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontSize: 14,
                                color: -monthOutcome > monthIncome ? Colors.red : Colors.grey[700],
                              ),
                            )
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(monthOutcome)),
                            Text(NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(monthIncome))
                          ],
                        )
                    )
                )
            ),
            Divider(color: Colors.blue),
            Card(
                child: ListTile(
                    leading: Icon(Icons.calendar_today),
                    title: Text(DateFormat('EEEE').format(_selectedDate)),
                    subtitle: Text(
                        NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(dayResult),
                        style: TextStyle(fontSize: 20,color: dayResult >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w900)
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(dayOutcome)),
                        Text(NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(dayIncome))
                      ],
                    )
                )
            ),
            if(categories.isNotEmpty) Divider(color: Colors.blue),
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
                      onTap: (){
                        if(!cat.selected){
                          var t = categories.where((t) => t.selected).firstOrNull;
                          if(t != null) t.selected = false;
                        }
                        setState(() {
                          cat.selected = !cat.selected;
                        });
                      },
                      leading: Icon(cat.icon),
                      title: Text(
                          NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(cat.result),
                          style: TextStyle(fontSize: 18,color: cat.result >= 0 ? Colors.green : Colors.red)
                      ),
                      subtitle: Text(cat.name),
                      trailing: cat.selected ? Icon(Icons.check_circle) : Icon(Icons.radio_button_unchecked),
                    )
                );
              },
            ),
            if(dayExpenses.isNotEmpty) Divider(color: Colors.blue),
            GridView.builder(
              itemCount: selectedExpenses.isEmpty ? dayExpenses.length : selectedExpenses.length,
              physics: const ScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: ratio,
              ),
              itemBuilder: (context, index) {
                Expense exp = selectedExpenses.isEmpty ? dayExpenses[index] : selectedExpenses[index];
                return Card(
                    child: ListTile(
                        onTap: () async {
                          var res = await Navigator.push(context, MaterialPageRoute(builder: (context) => ExpenseState(_expenses, expense: exp,)));
                          if(res == true) setState(() { });
                        },
                        leading: Icon(exp.category.icon),
                        title: Text(
                            NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(exp.amount),
                            style: TextStyle(fontSize: 18,color: exp.amount >= 0 ? Colors.green : Colors.red)
                        ),
                        subtitle: Text(exp.comment)
                      //trailing: Text(exp.category.name)
                    )
                );
              },
            ),
            const SizedBox(height: 70)
          ]
        ),
      ),
      floatingActionButton: Stack(
        children: [
          Positioned(
              left: 16,
              bottom: 0,
              child: FloatingActionButton(
                heroTag: "btn2",
                onPressed: () {
                  //_toggleOverlay();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryExpensePieChart(_selectedDate)));
                },
                child: const Icon(Icons.show_chart),
              )
          ),
          Positioned(
            right: 16,
            bottom: 0,
            child: FloatingActionButton(
                heroTag: "btn1",
                onPressed: _isLoading ? null : () async {
                  var res = await Navigator.push(context, MaterialPageRoute(builder:(context)=>ExpenseState(_expenses)));
                  if(res == true) setState(() { });
                },
                child: const Icon(Icons.add)
            )
          )
        ]
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Card(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: _goBackOneDay,
                style: ButtonStyle(side: WidgetStateProperty.all(BorderSide(color: Colors.white))),
                child: Icon(Icons.exposure_minus_1)
              ),
              ElevatedButton(
                onPressed: () => _pickDate(context),
                style: ButtonStyle(side: WidgetStateProperty.all(BorderSide(color: Colors.white))),
                child: Row(
                  spacing: 5,
                  children: [
                    Icon(Icons.calendar_month),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _goForwardOneDay,
                style: ButtonStyle(side: WidgetStateProperty.all(BorderSide(color: Colors.white))),
                child: Icon(Icons.exposure_plus_1),
              ),
            ],
          )
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _goBackOneDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(Duration(days: 1));
    });
  }

  void _goForwardOneDay() {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: 1));
    });
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
    }
  }

}
