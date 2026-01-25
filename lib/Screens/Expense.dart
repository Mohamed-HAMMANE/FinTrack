import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Helpers/Funcs.dart';
import '../Models/Category.dart';
import '../Models/Expense.dart';
import '../Models/Shortcut.dart';

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
  final List<DropdownMenuItem<Category>> _categoriesDropDown = List.empty(
    growable: true,
  );
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

  // Budget alert state
  double _projectedActual = 0; // What actual will be after saving this expense
  String _budgetWarningLevel = 'safe'; // 'safe', 'warning', 'alert', 'critical'

  @override
  void initState() {
    super.initState();
    // Initialize animation controller for the progress indicator.
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _progressAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_animationController);

    // Add listener to amount field for real-time budget warnings
    _amountController.addListener(_calculateProjectedBudget);

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
      _currentCategory = categories.firstWhere(
        (c) => c.id == widget.expense!.category.id,
      );
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
    final items = widget.expenses.where(
      (exp) =>
          exp.category.id == _currentCategory.id &&
          exp.date.year == _selectedDate.year &&
          exp.date.month == _selectedDate.month,
    );

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

  /// Calculates projected budget impact when user enters amount
  void _calculateProjectedBudget() {
    // Get current amount input (ignore if invalid)
    final amountText = _amountController.text;
    if (amountText.isEmpty || !Func.isNumeric(amountText)) {
      setState(() {
        _projectedActual = _actual;
        _budgetWarningLevel = 'safe';
      });
      return;
    }

    final enteredAmount = double.parse(amountText);

    // If this is income, it reduces actual spending
    if (_isIncome) {
      _projectedActual = (_actual - enteredAmount).clamp(0.0, double.infinity);
    } else {
      // If expense, add to actual spending
      _projectedActual = _actual + enteredAmount;
    }

    // Determine warning level based on projected percentage
    final percentage = (_budget == 0)
        ? 100
        : (_projectedActual / _budget) * 100;

    setState(() {
      if (percentage >= 100) {
        _budgetWarningLevel = 'critical';
      } else if (percentage >= 90) {
        _budgetWarningLevel = 'alert';
      } else if (percentage >= 75) {
        _budgetWarningLevel = 'warning';
      } else {
        _budgetWarningLevel = 'safe';
      }
    });
  }

  /// Get color based on warning level
  Color _getBudgetWarningColor() {
    switch (_budgetWarningLevel) {
      case 'warning':
        return Colors.orange.shade300;
      case 'alert':
        return Colors.orange.shade700;
      case 'critical':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  /// Get icon based on warning level
  IconData _getBudgetWarningIcon() {
    switch (_budgetWarningLevel) {
      case 'warning':
        return Icons.warning_amber;
      case 'alert':
        return Icons.warning;
      case 'critical':
        return Icons.error;
      default:
        return Icons.check_circle;
    }
  }

  /// Build warning banner for alert and critical states
  Widget _buildBudgetWarningBanner() {
    // Only show for alert and critical levels
    if (_budgetWarningLevel != 'alert' && _budgetWarningLevel != 'critical') {
      return const SizedBox.shrink();
    }

    final percentage = (_budget == 0)
        ? 100
        : (_projectedActual / _budget) * 100;
    final overage = _projectedActual - _budget;
    final color = _getBudgetWarningColor();

    return Card(
      color: color.withValues(alpha: 0.1),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(_getBudgetWarningIcon(), color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _budgetWarningLevel == 'critical'
                        ? 'Budget Exceeded!'
                        : 'Near Budget Limit!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _budgetWarningLevel == 'critical'
                        ? 'This will exceed budget by ${overage.toStringAsFixed(2)} DH (${percentage.toStringAsFixed(0)}%)'
                        : 'This will use ${percentage.toStringAsFixed(0)}% of your monthly budget',
                    style: TextStyle(
                      fontSize: 13,
                      color: color.withValues(alpha: 0.8),
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
                      initialValue: _currentCategory,
                      items: _categoriesDropDown,
                      onChanged: (Category? sel) {
                        if (sel == null) return;
                        setState(() {
                          _currentCategory = sel;
                          _updateProgressBar(); // Recompute on category change.
                          _calculateProjectedBudget(); // Recalculate warnings for new category
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
                        // Use projected actual for display if amount is entered
                        final displayActual = _projectedActual > 0
                            ? _projectedActual
                            : _actual;
                        final projectedRatio = (_budget == 0)
                            ? 1.0
                            : (displayActual / _budget)
                                  .clamp(0.0, 1.5)
                                  .toDouble();
                        final warningColor = _getBudgetWarningColor();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Display numeric budget vs actual with warning icon
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Budget: ${_budget.toStringAsFixed(2)}DH',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (_budgetWarningLevel != 'safe')
                                      Icon(
                                        _getBudgetWarningIcon(),
                                        color: warningColor,
                                        size: 18,
                                      ),
                                    if (_budgetWarningLevel != 'safe')
                                      const SizedBox(width: 4),
                                    Text(
                                      'Actual: ${_actual.toStringAsFixed(2)}DH',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: _actual > _budget
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Show projected if different from actual
                            if (_projectedActual > 0 &&
                                _projectedActual != _actual) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'After this: ${_projectedActual.toStringAsFixed(2)}DH (${((_projectedActual / _budget) * 100).toStringAsFixed(0)}%)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: warningColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            const SizedBox(height: 5),
                            // Visual progress bar with warning colors
                            LinearProgressIndicator(
                              value: projectedRatio > 1 ? 1 : projectedRatio,
                              minHeight: 8,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                warningColor,
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Contextual message
                            Text(
                              displayActual > _budget
                                  ? 'Over budget by ${(displayActual - _budget).toStringAsFixed(2)}DH'
                                  : 'Remaining budget: ${(_budget - displayActual).toStringAsFixed(2)}DH',
                              style: TextStyle(
                                fontSize: 14,
                                color: warningColor,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 15),

                    // ===================== Budget Warning Banner =====================
                    _buildBudgetWarningBanner(),

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
                                  setState(() {
                                    _isIncome = val ?? false;
                                    _calculateProjectedBudget(); // Recalculate when income status changes
                                  });
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ===================== Contextual Shortcuts =====================
                    Builder(
                      builder: (context) {
                        final shortcuts = Shortcut.defaults
                            .where((s) => s.categoryName.toLowerCase() == _currentCategory.name.toLowerCase())
                            .toList();

                        if (shortcuts.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Shortcuts for ${_currentCategory.name}:',
                              style: TextStyle(
                                fontSize: 14, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.grey.shade600
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: shortcuts.map((s) {
                                return ActionChip(
                                  label: Text('${s.comment} (${NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2).format(s.amount.abs())})'),
                                  avatar: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    radius: 10,
                                    child: Text(s.categoryName[0], style: const TextStyle(fontSize: 10, color: Colors.black)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _amountController.text = s.amount.abs().toString();
                                      _commentController.text = s.comment;
                                      // Auto-set income checkbox based on sign
                                      _isIncome = s.amount > 0;
                                      
                                      // Trigger budget calculations
                                      _calculateProjectedBudget();
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        );
                      }
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

                  // Check if budget would be exceeded and confirm with user
                  if (_budgetWarningLevel == 'critical' && !_isIncome) {
                    final confirmed = await _confirmBudgetExceedance();
                    if (!confirmed) return; // User cancelled
                  }

                  setState(() => _isLoading = true);

                  // Construct new or updated expense object.
                  final amt =
                      double.parse(_amountController.text) *
                      (_isIncome ? 1 : -1);
                  final newExp = Expense(
                    id: widget.expense?.id ?? 0,
                    amount: amt,
                    date: _selectedDate,
                    comment: _commentController.text.trim(),
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
                    widget.expense == null
                        ? 'Added successfully'
                        : 'Updated successfully',
                  );

                  // Refresh progress bar and form state.
                  _updateProgressBar();
                  setState(() => _isLoading = false);
                },
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      ),
    );
  }

  /// Handle back navigation, passing whether an update occurred.
  Future<bool> onWillPop() {
    Navigator.of(context).pop(_somethingAdded);
    return Future.value(true);
  }

  /// Confirm with user before saving when budget would be exceeded
  Future<bool> _confirmBudgetExceedance() async {
    final overage = _projectedActual - _budget;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                const Text('Budget Exceeded'),
              ],
            ),
            content: Text(
              'This expense will exceed your monthly budget by ${overage.toStringAsFixed(2)} DH.\n\nDo you want to save it anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Go Back'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Anyway'),
              ),
            ],
          ),
        ) ??
        false;
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
