import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Helpers/AppIcons.dart';
import '../Models/Category.dart';
import 'IconSelectorScreen.dart';

class CategoryState extends StatefulWidget {
  final Category? category;
  const CategoryState({super.key, this.category});

  @override
  State<CategoryState> createState() => _CategoryState();
}

class _CategoryState extends State<CategoryState> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  double _budget = 0;
  IconData _icon = Icons.question_mark;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _name = widget.category!.name;
      _budget = widget.category!.budget;
      _icon = widget.category!.icon;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category == null ? 'Add Category' : 'Edit Category')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            spacing: 20,
            children: [
              ListTile(
                //leading: Icon(_icon, size: 40),
                title: Text('Selected Icon'),
                leading: IconButton(
                  icon: Icon(_icon, size: 40),
                  onPressed: _selectIcon,
                ),
              ),
              TextFormField(
                initialValue: _name,
                decoration: InputDecoration(labelText: 'Name',border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? 'Enter a category name' : null,
                onSaved: (value) => _name = value!,
              ),
              TextFormField(
                initialValue: '$_budget',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: 'Budget',border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a number';
                  }
                  final number = double.tryParse(value);
                  if (number == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onSaved: (value) => _budget = double.parse(value!)
              ),
              ElevatedButton(
                onPressed: _saveCategory,
                child: Row(
                  spacing: 8,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save),
                    Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                  ]
                )
              )
            ]
          )
        )
      )
    );
  }

  Future<void> _saveCategory() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final newCategory = Category(id: 0,name: _name,budget: _budget,order: 0,iconCode: _icon.codePoint);
      if (widget.category != null) {
        newCategory.id = widget.category!.id;
        newCategory.order = widget.category!.order;
        await newCategory.update();
      } else {
        await newCategory.insert();
      }
      if(mounted) Navigator.pop(context,true);
    }
  }

  Future<void> _selectIcon() async {
    final selectedIconName = await Navigator.push(context, MaterialPageRoute(builder: (context) => IconSelectorScreen()));
    if (selectedIconName != null && AppIcons.allIcons.containsKey(selectedIconName)) {
      setState(() {
        _icon = AppIcons.allIcons[selectedIconName]!;
      });
    }
  }
}
