import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Helpers/Funcs.dart';
import '../Models/Category.dart';
import '../Models/Expense.dart';

class ExpenseState extends StatefulWidget {
  final Expense? expense;
  final List<Expense> expenses;
  const ExpenseState(this.expenses, {super.key, this.expense});

  @override
  State<ExpenseState> createState() => _ExpenseState();
}

class _ExpenseState extends State<ExpenseState> with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final List<DropdownMenuItem<Category>> _categoriesDropDown = List.empty(growable: true);
  late Category _currentCategory;
  bool _isIncome = false;
  bool _somethingAdded = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  double _actual = 0;
  double _budget = 1; // Avoid division by zero.

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(_animationController);

    _fetchCategories();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    final categories = await Category.getAll();
    if (categories.isNotEmpty) _currentCategory = categories[0];

    _categoriesDropDown.clear();
    for (var pt in categories) {
      _categoriesDropDown.add(
          DropdownMenuItem(
              value: pt,
              child: Row(
                spacing: 5,
                children: [
                  Icon(pt.iconCode == 0
                    ? Icons.question_mark
                    : IconData(pt.iconCode, fontFamily: 'MaterialIcons')),
                Text(pt.name)],)));
    }

    if (widget.expense != null) {
      _currentCategory = categories.where((c) => c.id == widget.expense!.category.id).single;
      var amount = widget.expense!.amount;
      if (amount < 0) {
        _amountController.text = (amount * -1).toString();
      } else {
        _amountController.text = amount.toString();
        _isIncome = true;
      }
      _commentController.text = widget.expense!.comment;
      _selectedDate = widget.expense!.date;
    }

    _updateProgressBar();

    setState(() {
      _isLoading = false;
    });
  }

  void _updateProgressBar() {
    _budget = _currentCategory.budget.abs();
    _actual = widget.expenses
        .where((expense) => expense.category.id == _currentCategory.id && expense.date.year == _selectedDate.year && expense.date.month == _selectedDate.month)
        .fold(0.0, (sum, expense) => sum + expense.amount.abs());
    _animationController.animateTo(_actual / (_budget == 0 ? 1 : _budget));
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text("FinTrack : ${widget.expense == null ? 'Add expense' : 'Edit expense'}"),
        ),
        body: _isLoading
            ? const Center(child: Text("No data ..."))
            : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DropdownButtonFormField<Category>(
                value: _currentCategory,
                items: _categoriesDropDown,
                onChanged: (selectedCategory) {
                  setState(() {
                    _currentCategory = selectedCategory!;
                    _updateProgressBar();
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Category',
                ),
              ),
              const SizedBox(height: 15.0),
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Column(
                    spacing: 5,
                    children: [
                      /*Row(
                        spacing: 12,
                        children: [
                          Icon(_currentCategory.iconCode == 0 ? Icons.question_mark : IconData(_currentCategory.iconCode, fontFamily: 'MaterialIcons')),
                          Text(
                            _currentCategory.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),*/
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Budget: ${_budget.toStringAsFixed(2)}DH',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.blueAccent,
                            ),
                          ),
                          Text(
                            'Actual: ${_actual.toStringAsFixed(2)}DH',
                            style: TextStyle(
                              fontSize: 16,
                              color: _actual > _budget ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      LinearProgressIndicator(
                        value: _progressAnimation.value,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _actual > _budget ? Colors.red : Colors.green,
                        ),
                      ),
                      Text(
                        _actual > _budget
                            ? 'Over budget by ${(_actual - _budget).toStringAsFixed(2)}DH'
                            : 'Remaining budget: ${(_budget - _actual).toStringAsFixed(2)}DH',
                        style: TextStyle(
                          fontSize: 14,
                          color: _actual > _budget ? Colors.red : null,
                        ),
                      )
                    ],
                  );
                },
              ),
              const SizedBox(height: 15.0),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Amount',
                  suffixIcon: Icon(Icons.numbers),
                  hintText: 'Amount',
                ),
                validator: (value) {
                  if (!Func.isNumeric(value)) {
                    return "Required field";
                  } else if (double.parse(value!) <= 0) {
                    return "Greater than 0";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15.0),
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Comment',
                  suffixIcon: Icon(Icons.message),
                  hintText: 'Comment',
                ),
                validator: (value) => Func.isNull(value) ? "Required field" : null,
                minLines: 4,
                keyboardType: TextInputType.multiline,
                maxLines: null,
              ),
              const SizedBox(height: 15.0),
              ListTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _isIncome,
                          onChanged: (bool? value) {
                            setState(() => _isIncome = value == true);
                          },
                        ),
                        const Text("Income ?"),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => _pickDate(context),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month),
                          Text(
                            formattedDate,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
        floatingActionButton: _isLoading
            ? const Icon(Icons.downloading)
            : FloatingActionButton.extended(
          heroTag: "btn1",
          icon: const Icon(Icons.check),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              setState(() {
                _isLoading = true;
              });
              var obj = Expense(
                id: widget.expense == null ? 0 : widget.expense!.id,
                amount: (_isIncome ? 1 : -1) * double.parse(_amountController.value.text),
                date: _selectedDate,
                comment: _commentController.text,
                category: _currentCategory,
              );
              await obj.save();
              if (widget.expense == null) {
                widget.expenses.insert(0, obj);
              } else {
                widget.expense!.amount = obj.amount;
                widget.expense!.date = obj.date;
                widget.expense!.comment = obj.comment;
                widget.expense!.category = obj.category;
              }
              _amountController.clear();
              _commentController.clear();
              _somethingAdded = true;

              await Func.updateWidgetData(widget.expenses);

              Func.showToast('${(widget.expense == null ? 'Added' : 'Updated')} successfully.');

              setState(() {
                _updateProgressBar();
                _isLoading = false;
              });
            }
          },
          label: const Text('Validate'),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      ),
    );
  }

  Future<bool> onWillPop() {
    Navigator.of(context).pop(_somethingAdded);
    return Future.value(true);
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
        _updateProgressBar();
      });
    }
  }
}
