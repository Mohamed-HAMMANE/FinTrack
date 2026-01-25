import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../Helpers/Funcs.dart';
import '../Models/Category.dart';
import '../Models/Expense.dart';
import '../Models/Shortcut.dart';

class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await Category.getAll();
    if (mounted) {
      setState(() {
        _categories = cats;
        _isLoading = false;
      });
    }
  }

  Future<void> _addExpense(Shortcut shortcut) async {
    // Find the category in the database that matches the shortcut name
    final category = _categories
        .where(
          (c) => c.name.toLowerCase() == shortcut.categoryName.toLowerCase(),
        )
        .firstOrNull;

    if (category == null) {
      Func.showToast(
        'Category "${shortcut.categoryName}" not found!',
        type: 'error',
      );
      return;
    }

    final expense = Expense(
      id: 0,
      amount: shortcut.amount, // Amount is already signed
      date: DateTime.now(),
      comment: shortcut.comment,
      category: category,
    );

    await expense.save();

    if (mounted) {
      Navigator.pop(context, true); // Return true to trigger refresh
      Func.showToast('Added: ${shortcut.comment}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Group shortcuts by category
    final Map<String, List<Shortcut>> grouped = {};
    for (var s in Shortcut.defaults) {
      if (!grouped.containsKey(s.categoryName)) {
        grouped[s.categoryName] = [];
      }
      grouped[s.categoryName]!.add(s);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⚡ Quick Add',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: entry.value.map((shortcut) {
                        return ActionChip(
                          elevation: 2,
                          padding: const EdgeInsets.all(8),
                          avatar: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              shortcut.categoryName[0],
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          label: Text(
                            '${shortcut.comment} (${NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2).format(shortcut.amount)})',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                          backgroundColor: Theme.of(context).cardColor,
                          onPressed: () => _addExpense(shortcut),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
