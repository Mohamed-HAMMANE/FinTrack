import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Helpers/Funcs.dart';
import '../Models/Category.dart';
import '../Models/Expense.dart';

class ExpenseState extends StatefulWidget {
  /// Optional expense being edited; null when adding a new one.
  final Expense? expense;
  /// Current list of all expenses for computing budget/actual.
  final List<Expense> expenses;

  const ExpenseState(this.expenses, {super.key, this.expense});

  @override
  State<ExpenseState> createState() => _ExpenseState();
}

class _ExpenseState extends State<ExpenseState>
    with SingleTickerProviderStateMixin {
  // Currently selected date for the entry.
  DateTime _selectedDate = DateTime.now();
  // Tracks loading state while fetching categories.
  bool _isLoading = true;

  // Controller for entering the amount.
  final TextEditingController _amountController = TextEditingController();
  // Controller for entering comments.
  final TextEditingController _commentController = TextEditingController();
  // Dropdown items for categories.
  final List<DropdownMenuItem<Category>> _categoriesDropDown =
  List.empty(growable: true);
  // The category currently selected in the dropdown.
  late Category _currentCategory;
  // True if this entry is income (positive) rather than expense (negative).
  bool _isIncome = false;
  // Indicates if an addition or update occurred (used to signal parent rebuild).
  bool _somethingAdded = false;

  // Keys for showing dialogs or snackbars.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controller & animation for progress bar (budget vs. actual).
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  // Actual spending (expenses minus incomes) for the selected period.
  double _actual = 0;
  // Budgeted amount from category.
  double _budget = 1; // Prevent division by zero error.

  @override
  void initState() {
    super.initState();
    // Initialize animation controller for the progress indicator.
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressAnimation =
        Tween<double>(begin: 0, end: 1).animate(_animationController);

    // Load categories, then initialize form fields if editing.
    _fetchCategories();
  }

  @override
  void dispose() {
    // Clean up animation and controllers.
    _animationController.dispose();
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  /// Fetches category list from storage and populates dropdown.
  Future<void> _fetchCategories() async {
    final categories = await Category.getAll();
    if (categories.isNotEmpty) {
      _currentCategory = categories.first;
    }

    // Build dropdown items with icon and name.
    _categoriesDropDown.clear();
    for (var cat in categories) {
      _categoriesDropDown.add(
        DropdownMenuItem<Category>(
          value: cat,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Display category icon or fallback to question mark.
              Icon(
                cat.iconCode == 0
                    ? Icons.question_mark
                    : IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
              ),
              const SizedBox(width: 5),
              Text(cat.name),
            ],
          ),
        ),
      );
    }

    // If editing existing expense, pre-fill fields.
    if (widget.expense != null) {
      _currentCategory = categories
          .firstWhere((c) => c.id == widget.expense!.category.id);
      final amt = widget.expense!.amount;
      if (amt < 0) {
        // For expenses, show positive value in input.
        _amountController.text = (-amt).toString();
      } else {
        _amountController.text = amt.toString();
        _isIncome = true;
      }
      _commentController.text = widget.expense!.comment;
      _selectedDate = widget.expense!.date;
    }

    // Compute and animate the progress bar.
    _updateProgressBar();

    // Done loading, show form.
    setState(() {
      _isLoading = false;
    });
  }

  /// Calculates actual spending vs budget, subtracting incomes.
  void _updateProgressBar() {
    // Use absolute value of budget to avoid negative budgets.
    _budget = _currentCategory.budget.abs();
    // Filter expenses to this category & month.
    final items = widget.expenses.where((exp) =>
    exp.category.id == _currentCategory.id &&
        exp.date.year == _selectedDate.year &&
        exp.date.month == _selectedDate.month);

    // Sum only negative amounts (expenses) as positive spent.
    final spent = items
        .where((e) => e.amount < 0)
        .fold<double>(0, (sum, e) => sum + (-e.amount));
    // Sum only positive amounts (incomes).
    final income = items
        .where((e) => e.amount > 0)
        .fold<double>(0, (sum, e) => sum + e.amount);

    // Actual spending = expenses minus income.
    _actual = spent - income;
    // Do not allow actual to go below zero.
    if (_actual < 0) _actual = 0;

    // Compute ratio clamped between 0 and 1.
    final ratio = (_budget == 0) ? 1 : (_actual / _budget).clamp(0.0, 1.0);
    // Animate progress bar to new ratio.
    _animationController.animateTo(ratio.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    // Format selected date for display.
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(
            'FinTrack : ${widget.expense == null ? 'Add expense' : 'Edit expense'}',
          ),
        ),
        // Show loader while categories load.
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ===================== Category Selector =====================
              DropdownButtonFormField<Category>(
                value: _currentCategory,
                items: _categoriesDropDown,
                onChanged: (Category? sel) {
                  if (sel == null) return;
                  setState(() {
                    _currentCategory = sel;
                    _updateProgressBar(); // Recompute on category change.
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Category',
                ),
              ),
              const SizedBox(height: 15),

              // ===================== Budget vs Actual Bar =====================
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Display numeric budget vs actual.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Budget: ${_budget.toStringAsFixed(2)}DH',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.blueAccent),
                          ),
                          Text(
                            'Actual: ${_actual.toStringAsFixed(2)}DH',
                            style: TextStyle(
                              fontSize: 16,
                              color:
                              _actual > _budget ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Visual progress bar.
                      LinearProgressIndicator(
                        value: _progressAnimation.value,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _actual > _budget ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Contextual message.
                      Text(
                        _actual > _budget
                            ? 'Over budget by ${( _actual - _budget ).toStringAsFixed(2)}DH'
                            : 'Remaining budget: ${( _budget - _actual ).toStringAsFixed(2)}DH',
                        style: TextStyle(
                          fontSize: 14,
                          color: _actual > _budget
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 15),

              // ===================== Amount Input =====================
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Amount',
                  suffixIcon: Icon(Icons.numbers),
                  hintText: 'Enter amount',
                ),
                validator: (value) {
                  if (!Func.isNumeric(value)) {
                    return 'Required field';
                  } else if (double.parse(value!) <= 0) {
                    return 'Must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // ===================== Comment Input =====================
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Comment',
                  suffixIcon: Icon(Icons.message),
                  hintText: 'Enter comment',
                ),
                validator: (value) =>
                Func.isNull(value) ? 'Required field' : null,
                minLines: 2,
                maxLines: 5,
              ),
              const SizedBox(height: 15),

              // ===================== Income Checkbox & Date Picker =====================
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _isIncome,
                          onChanged: (bool? val) {
                            setState(() => _isIncome = val ?? false);
                          },
                        ),
                        const Text('Income?'),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => _pickDate(context),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month),
                          const SizedBox(width: 5),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // ===================== Validate / Save Button =====================
        floatingActionButton: _isLoading
            ? const SizedBox()
            : FloatingActionButton.extended(
          heroTag: 'btn1',
          icon: const Icon(Icons.check),
          label: Text(widget.expense == null ? 'Add' : 'Update'),
          onPressed: () async {
            // Validate inputs before saving.
            if (!_formKey.currentState!.validate()) return;
            setState(() => _isLoading = true);

            // Construct new or updated expense object.
            final amt = double.parse(_amountController.text) *
                (_isIncome ? 1 : -1);
            final newExp = Expense(
              id: widget.expense?.id ?? 0,
              amount: amt,
              date: _selectedDate,
              comment: _commentController.text,
              category: _currentCategory,
            );

            await newExp.save(); // Persist to database.
            if (widget.expense == null) {
              widget.expenses.insert(0, newExp); // Add new.
            } else {
              // Update existing in list for real-time UI.
              widget.expense!
                ..amount = newExp.amount
                ..date = newExp.date
                ..comment = newExp.comment
                ..category = newExp.category;
            }

            // Clear inputs and signal parent to refresh.
            _amountController.clear();
            _commentController.clear();
            _somethingAdded = true;

            await Func.updateWidgetData(widget.expenses);
            Func.showToast(
                widget.expense == null ? 'Added successfully' : 'Updated successfully');

            // Refresh progress bar and form state.
            _updateProgressBar();
            setState(() => _isLoading = false);
          },
        ),
        floatingActionButtonLocation:
        FloatingActionButtonLocation.miniEndFloat,
      ),
    );
  }

  /// Handle back navigation, passing whether an update occurred.
  Future<bool> onWillPop() {
    Navigator.of(context).pop(_somethingAdded);
    return Future.value(true);
  }

  /// Shows date picker and updates selected date.
  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || picked == _selectedDate) return;
    setState(() {
      _selectedDate = picked;
      _updateProgressBar(); // Recompute after date change.
    });
  }
}
