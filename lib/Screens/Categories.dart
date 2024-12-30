import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../Models/Category.dart';
import 'Category.dart';

class CategoriesState extends StatefulWidget {
  const CategoriesState({super.key});

  @override
  State<CategoriesState> createState() => _CategoriesState();
}

class _CategoriesState extends State<CategoriesState> {
  List<Category> _categories= [];
  bool _somethingAdded = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final categories = await Category.getAll();
    setState(() => _categories = categories);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: onWillPop,
        child: Scaffold(
            appBar: AppBar(
              title: Text('My Categories'),
              actions: [
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () async {
                    bool? res = await Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryState()));
                    if(res == true) {
                      await _fetchCategories();
                      _somethingAdded = true;
                    }
                  }
                )
              ]
            ),
            body: ReorderableGridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 5 / 2,
                ),
                onReorder: (int oldIndex, int newIndex) async {
                  setState(() {
                    final category = _categories.removeAt(oldIndex);
                    _categories.insert(newIndex, category);
                  });
                  await Category.updateOrder(_categories);
                },
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return Card(
                      key: ValueKey(category.id),
                      elevation: 10,
                      child: Dismissible(
                        key: ValueKey(category.id),
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
                            bool? res = await Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryState(category: category)));
                            if(res == true) {
                              await _fetchCategories();
                              _somethingAdded = true;
                            }
                          } else if (direction == DismissDirection.endToStart) {
                            return await _deleteCategory(context, category);
                          }
                          return false;
                        },
                        child: ListTile(
                          title: Text(category.name),
                          subtitle: Text(NumberFormat.decimalPatternDigits(locale: 'fr_fr', decimalDigits: 2,).format(category.budget)),
                          leading: Icon(category.icon),
                          onTap: () async {
                            bool? res = await Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryState(category: category)));
                            if(res == true) {
                              await _fetchCategories();
                              _somethingAdded = true;
                            }
                          },
                        ),
                      )
                  );
                }
            )
        )
    );
  }

  Future<bool> onWillPop() {
    Navigator.of(context).pop(_somethingAdded);
    return Future.value(true);
  }

  Future<bool> _deleteCategory(BuildContext context, Category category) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(
              onPressed: () async {
                var nbr = await category.delete();
                if(nbr == 1){
                  await _fetchCategories();
                  _somethingAdded = true;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Category deleted successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context,true);
                }
                else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cannot delete this category !!!'),
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
