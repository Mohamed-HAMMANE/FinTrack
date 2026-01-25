import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';

import '../Helpers/Funcs.dart';
import '../Models/Category.dart';
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

  // Filter state
  List<Category> _categories = [];
  final Set<int> _selectedCategoryIds = {};
  DateTimeRange? _dateRange;
  String _amountFilter = 'all'; // 'all', 'income', 'expense'

  // Local state for expenses (starts with passed list, can be expanded)
  List<Expense> _allExpenses = [];
  bool _isLoadingAll = false;

  @override
  void initState() {
    super.initState();
    _allExpenses = widget.expenses;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await Category.getAll();
    setState(() {
      _categories = categories;
    });
  }
  
  Future<void> _loadAllData() async {
    setState(() => _isLoadingAll = true);
    // Fetch all expenses from database
    final all = await Expense.getAll();
    setState(() {
      _allExpenses = all;
      _isLoadingAll = false;
    });
    Func.showToast('Full history loaded: ${all.length} items');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Enhanced filter: search text, categories, date range, amount type
  List<Expense> get _filteredExpenses {
    var result = _allExpenses;

    // 1) Search text filter (comment OR category name OR amount)
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((exp) {
        final matchesComment = exp.comment.toLowerCase().contains(q);
        final matchesCategory = exp.category.name.toLowerCase().contains(q);
        final matchesAmount = exp.amount.toString().contains(q);
        return matchesComment || matchesCategory || matchesAmount;
      }).toList();
    }

    // 2) Category filter
    if (_selectedCategoryIds.isNotEmpty) {
      result = result
          .where((exp) => _selectedCategoryIds.contains(exp.category.id))
          .toList();
    }

    // 3) Date range filter
    if (_dateRange != null) {
      result = result.where((exp) {
        final expDate = DateTime(exp.date.year, exp.date.month, exp.date.day);
        final startDate = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final endDate = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
        );
        return (expDate.isAtSameMomentAs(startDate) ||
                expDate.isAfter(startDate)) &&
            (expDate.isAtSameMomentAs(endDate) || expDate.isBefore(endDate));
      }).toList();
    }

    // 4) Amount type filter
    if (_amountFilter == 'income') {
      result = result.where((exp) => exp.amount > 0).toList();
    } else if (_amountFilter == 'expense') {
      result = result.where((exp) => exp.amount < 0).toList();
    }

    return result;
  }

  // 2) Sum of filtered amounts
  double get _totalFilteredAmount =>
      _filteredExpenses.fold(0.0, (sum, item) => sum + item.amount);

  // Check if any filter is active
  bool get _hasActiveFilters =>
      _selectedCategoryIds.isNotEmpty ||
      _dateRange != null ||
      _amountFilter != 'all';

  // Clear all filters
  void _clearAllFilters() {
    setState(() {
      _selectedCategoryIds.clear();
      _dateRange = null;
      _amountFilter = 'all';
    });
  }

  // Build category filter chips
  Widget _buildCategoryFilterChips() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategoryIds.contains(category.id);

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(category.icon, size: 18),
                  const SizedBox(width: 4),
                  Text(category.name),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategoryIds.add(category.id);
                  } else {
                    _selectedCategoryIds.remove(category.id);
                  }
                });
              },
            ),
          );
        },
      ),
    );
  }

  // Build date range filter
  Widget _buildDateRangeFilter() {
    return FilterChip(
      selected: _dateRange != null,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today, size: 18),
          const SizedBox(width: 4),
          Text(
            _dateRange == null
                ? 'All Dates'
                : '${DateFormat('dd/MM').format(_dateRange!.start)} - ${DateFormat('dd/MM').format(_dateRange!.end)}',
          ),
          if (_dateRange != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                setState(() {
                  _dateRange = null;
                });
              },
              child: const Icon(Icons.close, size: 16),
            ),
          ],
        ],
      ),
      onSelected: (_) async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDateRange: _dateRange,
        );
        if (picked != null) {
          setState(() {
            _dateRange = picked;
          });
        }
      },
    );
  }

  // Build amount type filter
  Widget _buildAmountTypeFilter() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: _amountFilter == 'all',
          onSelected: (_) {
            setState(() {
              _amountFilter = 'all';
            });
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Income'),
          selected: _amountFilter == 'income',
          selectedColor: Colors.green.withValues(alpha: 0.3),
          onSelected: (_) {
            setState(() {
              _amountFilter = 'income';
            });
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Expenses'),
          selected: _amountFilter == 'expense',
          selectedColor: Colors.red.withValues(alpha: 0.3),
          onSelected: (_) {
            setState(() {
              _amountFilter = 'expense';
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // If loading all data, show simple loader
    if (_isLoadingAll) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
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
          title: Text('Expenses ${filteredExpenses.length}'), // Show count of filtered items
          actions: [
             // "Load All" button
             IconButton(
               icon: const Icon(Icons.sync_alt),
               tooltip: 'Load Full History',
               onPressed: _loadAllData,
             )
          ],
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
                  hintText: 'Search by comment, category, or amount',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // ───── Filter Section ─────
            // Category Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter by Category:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  _buildCategoryFilterChips(),
                ],
              ),
            ),

            // Date Range & Amount Type Filters
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildDateRangeFilter(),
                    const SizedBox(width: 8),
                    _buildAmountTypeFilter(),
                    if (_hasActiveFilters) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _clearAllFilters,
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: const Text('Clear'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // ───── Total Filtered Amount ─────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Count display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${filteredExpenses.length} of ${_allExpenses.length} expenses',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Total amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                    final sum = expensesForDay.fold(
                      0.0,
                      (sum, item) => sum + item.amount,
                    );

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
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              '(${NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2).format(sum)})',
                              style: TextStyle(
                                fontSize: 17,
                                color: sum >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final exp = expensesForDay[index];
                          return Card(
                            child: ListTile(
                              onTap: () => _editExpense(exp),
                              leading: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(exp.category.icon),
                                  Text(
                                    exp.category.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
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
                                      : Colors.red,
                                ),
                              ),
                              subtitle: Text(exp.comment),
                              trailing: IconButton(
                                onPressed: () => _deleteExpense(context, exp),
                                icon: const Icon(Icons.delete_forever),
                              ),
                            ),
                          );
                        }, childCount: expensesForDay.length),
                      ),
                    );
                  }),
                  const SliverToBoxAdapter(child: SizedBox(height: 100.0)),
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
                builder: (context) => ExpenseState(widget.expenses),
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
        builder: (context) => ExpenseState(widget.expenses, expense: exp),
      ),
    );
    if (_somethingAdded == true) setState(() {});
  }

  Future<bool> _deleteExpense(BuildContext context, Expense expense) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Are you sure you want to delete "${expense.comment}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
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
                Func.showToast('Cannot delete this expense !!!', type: 'error');
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
